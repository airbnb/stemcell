require 'aws-sdk-ec2'
require 'base64'
require 'logger'
require 'erb'
require 'set'

module Stemcell
  class Launcher
    REQUIRED_OPTIONS = [
      'region',
    ]

    REQUIRED_LAUNCH_PARAMETERS = [
      'chef_role',
      'chef_environment',
      'chef_data_bag_secret',
      'git_branch',
      'git_key',
      'git_origin',
      'key_name',
      'instance_type',
      'image_id',
      'availability_zone',
      'count'
    ]

    LAUNCH_PARAMETERS = [
      'chef_package_source',
      'chef_version',
      'chef_role',
      'chef_environment',
      'chef_data_bag_secret',
      'chef_data_bag_secret_path',
      'git_branch',
      'git_key',
      'git_origin',
      'key_name',
      'instance_type',
      'instance_hostname',
      'instance_domain_name',
      'image_id',
      'availability_zone',
      'vpc_id',
      'subnet',
      'private_ip_address',
      'dedicated_tenancy',
      'associate_public_ip_address',
      'count',
      'security_groups',
      'security_group_ids',
      'tags',
      'iam_role',
      'ebs_optimized',
      'termination_protection',
      'block_device_mappings',
      'ephemeral_devices',
      'placement_group'
    ]

    TEMPLATE_PATH = '../templates/bootstrap.sh.erb'
    LAST_BOOTSTRAP_LINE = "Stemcell bootstrap finished successfully!"

    MAX_RUNNING_STATE_WAIT_TIME = 300 # seconds
    RUNNING_STATE_WAIT_SLEEP_TIME = 5 # seconds

    def initialize(opts={})
      @log = Logger.new(STDOUT)
      @log.level = Logger::INFO unless ENV['DEBUG']
      @log.debug "creating new stemcell object"
      @log.debug "opts are #{opts.inspect}"

      REQUIRED_OPTIONS.each do |opt|
        raise ArgumentError, "missing required option 'region'" unless opts[opt]
      end

      @region = opts['region']
      @vpc_id = opts['vpc_id']
      @ec2_endpoint = opts['ec2_endpoint']
      @aws_access_key = opts['aws_access_key']
      @aws_secret_key = opts['aws_secret_key']
      @aws_session_token = opts['aws_session_token']
      @max_attempts = opts['max_attempts'] || 3
      @stub_responses = opts['stub_responses'] || false
      configure_aws_creds_and_region
    end

    def launch(opts={})
      verify_required_options(opts, REQUIRED_LAUNCH_PARAMETERS)

      # attempt to accept keys as file paths
      opts['git_key'] = try_file(opts['git_key'])
      opts['chef_data_bag_secret'] = try_file(opts['chef_data_bag_secret'])

      # generate tags and merge in any that were specified as inputs
      tags = {
        'Name' => "#{opts['chef_role']}-#{opts['chef_environment']}",
        'Group' => "#{opts['chef_role']}-#{opts['chef_environment']}",
        'created_by' => opts.fetch('user', ENV['USER']),
        'stemcell' => VERSION,
      }
      # Short name if we're in production
      tags['Name'] = opts['chef_role'] if opts['chef_environment'] == 'production'
      tags.merge!(opts['tags']) if opts['tags']

      # generate launch options
      launch_options = {
        :image_id => opts['image_id'],
        :instance_type => opts['instance_type'],
        :key_name => opts['key_name'],
        :min_count => opts['count'],
        :max_count => opts['count'],
      }


      # Associate Public IP can only bet set on network_interfaces, and if present
      # security groups and subnet should be set on the interface. VPC-only.
      # Primary network interface
      network_interface = {
        device_index: 0,
      }
      launch_options[:network_interfaces] = [network_interface]

      if opts['security_group_ids'] && !opts['security_group_ids'].empty?
        network_interface[:groups] = opts['security_group_ids']
      end

      if opts['security_groups'] && !opts['security_groups'].empty?
        # convert sg names to sg ids as VPC only accepts ids
        security_group_ids = get_vpc_security_group_ids(@vpc_id, opts['security_groups'])
        network_interface[:groups] ||= []
        network_interface[:groups].concat(security_group_ids)
      end

      launch_options[:placement] = placement = {}
      # specify availability zone (optional)
      if opts['availability_zone']
        placement[:availability_zone] = opts['availability_zone']
      end

      if opts['subnet']
        network_interface[:subnet_id] = opts['subnet']
      end

      if opts['private_ip_address']
        launch_options[:private_ip_address] = opts['private_ip_address']
      end

      if opts['dedicated_tenancy']
        placement[:tenancy] = 'dedicated'
      end

      if opts['associate_public_ip_address']
        network_interface[:associate_public_ip_address] = opts['associate_public_ip_address']
      end

      # specify IAM role (optional)
      if opts['iam_role']
        launch_options[:iam_instance_profile] = {
          name: opts['iam_role']
        }
      end

      # specify placement group (optional)
      if opts['placement_group']
        placement[:group_name] = opts['placement_group']
      end

      # specify an EBS-optimized instance (optional)
      launch_options[:ebs_optimized] = true if opts['ebs_optimized']

      # specify placement group (optional)
      if opts['instance_initiated_shutdown_behavior']
        launch_options[:instance_initiated_shutdown_behavior] =
          opts['instance_initiated_shutdown_behavior']
      end

      # specify raw block device mappings (optional)
      if opts['block_device_mappings']
        launch_options[:block_device_mappings] = opts['block_device_mappings']
      end

      # specify ephemeral block device mappings (optional)
      if opts['ephemeral_devices']
        launch_options[:block_device_mappings] ||= []
        opts['ephemeral_devices'].each_with_index do |device,i|
          launch_options[:block_device_mappings].push ({
            :device_name => device,
            :virtual_name => "ephemeral#{i}"
          })
        end
      end

      if opts['termination_protection']
        launch_options[:disable_api_termination] = true
      end

      # generate user data script to bootstrap instance, include in launch
      # options UNLESS we have manually set the user-data (ie. for ec2admin)
      launch_options[:user_data] = Base64.encode64(opts.fetch('user_data', render_template(opts)))

      # add tags to launch options so we don't need to make a separate CreateTags call
      launch_options[:tag_specifications] = [{
        resource_type: 'instance',
        tags: tags.map { |k, v| { key: k, value: v } }
      }]

      # launch instances
      instances = do_launch(launch_options)

      # everything from here on out must succeed, or we kill the instances we just launched
      begin
        # wait for aws to report instance stats
        if opts.fetch('wait', true)
          wait(instances)
          print_run_info(instances)
          @log.info "launched instances successfully"
        end
      rescue => e
        @log.info "launch failed, killing all launched instances"
        begin
          kill(instances, :ignore_not_found => true)
        rescue => kill_error
          @log.warn "encountered an error during cleanup: #{kill_error.message}"
        end
        raise e
      end

      return instances
    end

    def kill(instances, opts={})
      return if !instances || instances.empty?

      errors = run_batch_operation(instances) do |instance|
        begin
          @log.warn "Terminating instance #{instance.instance_id}"
          ec2.terminate_instances(instance_ids: [instance.instance_id])
          nil # nil == success
        rescue Aws::EC2::Errors::InvalidInstanceIDNotFound => e
          opts[:ignore_not_found] ? nil : e
        end
      end
      check_errors(:kill, instances.map(&:instance_id), errors)
    end

    # this is made public for ec2admin usage
    def render_template(opts={})
      template_file_path = File.expand_path(TEMPLATE_PATH, __FILE__)
      template_file = File.read(template_file_path)
      erb_template = ERB.new(template_file)
      last_bootstrap_line = LAST_BOOTSTRAP_LINE
      generated_template = erb_template.result(binding)
      @log.debug "generated template is #{generated_template}"
      return generated_template
    end

    private

    def print_run_info(instances)
      puts "\nhere is the info for what's launched:"
      instances.each do |instance|
        puts "\tinstance_id: #{instance.instance_id}"
        puts "\tpublic ip:   #{instance.public_ip_address || 'none'}"
        puts "\tprivate ip:  #{instance.private_ip_address || 'none'}"
        puts
      end
      puts "install logs will be in /var/log/init and /var/log/init.err"
    end

    def wait(instances)
      @log.info "Waiting up to #{MAX_RUNNING_STATE_WAIT_TIME} seconds for #{instances.count} " \
                "instance(s): (#{instances.inspect})"

      times_out_at = Time.now + MAX_RUNNING_STATE_WAIT_TIME
      instance_ids = instances.map(&:instance_id)
      ec2.describe_instance_status(instance_ids: instance_ids).each do |resp|
        statuses = resp.instance_statuses.map { |s| s.instance_state.name }
        until statuses.all? { |s| s == 'running' }
          wait_time_expire_or_sleep(times_out_at)
        end
      end

      @log.info "all instances in running state"
    end

    def verify_required_options(params, required_options)
      @log.debug "params is #{params}"
      @log.debug "required_options are #{required_options}"
      required_options.each do |required|
        unless params.include?(required)
          raise ArgumentError, "you need to provide option #{required}"
        end
      end
    end

    def do_launch(opts={})
      @log.debug "about to launch instance(s) with options #{opts}"
      @log.info "launching instances"
      instances = ec2.run_instances(opts).instances
      instances.each do |instance|
        @log.info "launched instance #{instance.instance_id}"
      end
      return instances
    end

    # Resolve security group names to their ids in the given VPC
    def get_vpc_security_group_ids(vpc_id, group_names)
      group_map = {}
      @log.info "resolving security groups #{group_names} in #{vpc_id}"
      ec2.describe_security_groups(filters: [{ name: 'vpc-id', values: [vpc_id] }]).
        each do |response|
        response.security_groups.each do |sg|
          group_map[sg.group_name] = sg.group_id
        end
      end
      group_ids = []
      group_names.each do |sg_name|
        raise "Couldn't find security group #{sg_name} in #{vpc_id}" unless group_map.has_key?(sg_name)
        group_ids << group_map[sg_name]
      end
      group_ids
    end

    # attempt to accept keys as file paths
    def try_file(opt="")
        File.read(File.expand_path(opt)) rescue opt
    end

    INITIAL_RETRY_SEC = 1

    # Return a Hash of instance => error. Empty hash indicates "no error"
    # for code block:
    #   - if block returns nil, success
    #   - if block returns non-nil value (e.g., exception), retry 3 times w/ backoff
    #   - if block raises exception, fail
    def run_batch_operation(instances)
      instances.map do |instance|
        begin
          attempt = 0
          result = nil
          while attempt < @max_attempts
            # sleep idempotently except for the first attempt
            sleep(INITIAL_RETRY_SEC * 2 ** attempt) if attempt != 0
            result = yield(instance)
            break if result.nil? # nil indicates success
            attempt += 1
          end
          result # result for this instance is nil or returned exception
        rescue => e
          e # result for this instance is caught exception
        end
      end
    end

    def check_errors(operation, instance_ids, errors)
      return if errors.all?(&:nil?)
      raise IncompleteOperation.new(
        operation,
        instance_ids,
        instance_ids.zip(errors).reject { |i, e| e.nil? }
      )
    end

    def ec2
      @ec2 ||= Aws::EC2::Client.new(@ec2_opts)
    end

    def wait_time_expire_or_sleep(times_out_at)
      now = Time.now
      if now >= times_out_at
        raise TimeoutError, "exceeded timeout of #{MAX_RUNNING_STATE_WAIT_TIME} seconds"
      else
        sleep [RUNNING_STATE_WAIT_SLEEP_TIME, times_out_at - now].min
      end
    end

    def configure_aws_creds_and_region
      # configure client local opts
      @ec2_opts = { stub_responses: @stub_responses }
      @ec2_opts.merge!({ endpoint: @ec2_endpoint }) if @ec2_endpoint
      # configure AWS with creds/region
      aws_configs = {:region => @region}
      aws_configs.merge!({
        :access_key_id     => @aws_access_key,
        :secret_access_key => @aws_secret_key
      }) if @aws_access_key && @aws_secret_key
      aws_configs.merge!({
        :session_token     => @aws_session_token,
      }) if @aws_session_token
      Aws.config.update(aws_configs)
    end
  end
end
