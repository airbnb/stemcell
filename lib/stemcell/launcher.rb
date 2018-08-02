require 'aws-sdk-v1'
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
      'classic_link',
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
      @aws_access_key = opts['aws_access_key']
      @aws_secret_key = opts['aws_secret_key']
      @aws_session_token = opts['aws_session_token']
      @max_attempts = opts['max_attempts'] || 3
      configure_aws_creds_and_region
    end

    def launch(opts={})
      verify_required_options(opts, REQUIRED_LAUNCH_PARAMETERS)

      # attempt to accept keys as file paths
      opts['git_key'] = try_file(opts['git_key'])
      opts['chef_data_bag_secret'] = try_file(opts['chef_data_bag_secret'])

      # generate tags and merge in any that were specefied as inputs
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
        :count => opts['count'],
      }

      if opts['security_group_ids'] && !opts['security_group_ids'].empty?
        launch_options[:security_group_ids] = opts['security_group_ids']
      end

      if opts['security_groups'] && !opts['security_groups'].empty?
        if @vpc_id
          # convert sg names to sg ids as VPC only accepts ids
          security_group_ids = get_vpc_security_group_ids(@vpc_id, opts['security_groups'])
          launch_options[:security_group_ids] ||= []
          launch_options[:security_group_ids].concat(security_group_ids)
        else
          launch_options[:security_groups] = opts['security_groups']
        end
      end

      # specify availability zone (optional)
      if opts['availability_zone']
        launch_options[:availability_zone] = opts['availability_zone']
      end

      if opts['subnet']
        launch_options[:subnet] = opts['subnet']
      end

      if opts['private_ip_address']
        launch_options[:private_ip_address] = opts['private_ip_address']
      end

      if opts['dedicated_tenancy']
        launch_options[:dedicated_tenancy] = opts['dedicated_tenancy']
      end

      if opts['associate_public_ip_address']
        launch_options[:associate_public_ip_address] = opts['associate_public_ip_address']
      end

      # specify IAM role (optional)
      if opts['iam_role']
        launch_options[:iam_instance_profile] = opts['iam_role']
      end

      # specify placement group (optional)
      if opts['placement_group']
        launch_options[:placement] = {
          :group_name => opts['placement_group'],
        }
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

      # generate user data script to bootstrap instance, include in launch
      # options UNLESS we have manually set the user-data (ie. for ec2admin)
      launch_options[:user_data] = opts.fetch('user_data', render_template(opts))

      # launch instances
      instances = do_launch(launch_options)

      # everything from here on out must succeed, or we kill the instances we just launched
      begin
        # set tags on all instances launched
        set_tags(instances, tags)
        @log.info "sent ec2 api tag requests successfully"

        # link to classiclink
        unless @vpc_id
          set_classic_link(instances, opts['classic_link'])
          @log.info "successfully applied classic link settings (if any)"
        end

        # turn on termination protection
        # we do this now to make sure all other settings worked
        if opts['termination_protection']
          enable_termination_protection(instances)
          @log.info "successfully enabled termination protection"
        end

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
          @log.warn "Terminating instance #{instance.id}"
          instance.terminate
          nil # nil == success
        rescue AWS::EC2::Errors::InvalidInstanceID::NotFound => e
          opts[:ignore_not_found] ? nil : e
        end
      end
      check_errors(:kill, instances.map(&:id), errors)
    end

    # this is made public for ec2admin usage
    def render_template(opts={})
      template_file_path = File.expand_path(TEMPLATE_PATH, __FILE__)
      template_file = File.read(template_file_path)
      erb_template = ERB.new(template_file)
      last_bootstrap_line = LAST_BOOTSTRAP_LINE
      generated_template = erb_template.result(binding)
      @log.debug "genereated template is #{generated_template}"
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
      until instances.all?{ |i| i.status == :running }
        wait_time_expire_or_sleep(times_out_at)
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
      instances = ec2.instances.create(opts)
      instances = [instances] unless Array === instances
      instances.each do |instance|
        @log.info "launched instance #{instance.instance_id}"
      end
      return instances
    end

    def set_tags(instances=[], tags)
      @log.info "setting tags on instance(s)"
      errors = run_batch_operation(instances) do |instance|
        begin
          instance.tags.set(tags)
          nil # nil == success
        rescue AWS::EC2::Errors::InvalidInstanceID::NotFound => e
          e
        end
      end
      check_errors(:set_tags, instances.map(&:id), errors)
    end

    # Resolve security group names to their ids in the given VPC
    def get_vpc_security_group_ids(vpc_id, group_names)
      group_map = {}
      @log.info "resolving security groups #{group_names} in #{vpc_id}"
      vpc = AWS::EC2::VPC.new(vpc_id, :ec2_endpoint => "ec2.#{@region}.amazonaws.com")
      vpc.security_groups.each do |sg|
        next if sg.vpc_id != vpc_id
        group_map[sg.name] = sg.group_id
      end
      group_ids = []
      group_names.each do |sg_name|
        raise "Couldn't find security group #{sg_name} in #{vpc_id}" unless group_map.has_key?(sg_name)
        group_ids << group_map[sg_name]
      end
      group_ids
    end

    def set_classic_link(left_to_process, classic_link)
      return unless classic_link
      return unless classic_link['vpc_id']

      security_group_ids = classic_link['security_group_ids'] || []
      security_group_names = classic_link['security_groups'] || []
      return if security_group_ids.empty? && security_group_names.empty?

      if !security_group_names.empty?
        extra_group_ids = get_vpc_security_group_ids(classic_link['vpc_id'], security_group_names)
        security_group_ids = security_group_ids + extra_group_ids
      end

      @log.info "applying classic link settings on #{left_to_process.count} instance(s)"

      errors = []
      processed = []
      times_out_at = Time.now + MAX_RUNNING_STATE_WAIT_TIME
      until left_to_process.empty?
        wait_time_expire_or_sleep(times_out_at)

        # we can only apply classic link when instances are in the running state
        # lets apply classiclink as instances become available so we don't wait longer than necessary
        recently_running = left_to_process.select{ |inst| inst.status == :running }
        left_to_process = left_to_process.reject{ |inst| recently_running.include?(inst) }

        processed += recently_running
        errors += run_batch_operation(recently_running) do |instance|
          begin
            result = ec2.client.attach_classic_link_vpc({
                :instance_id => instance.id,
                :vpc_id => classic_link['vpc_id'],
                :groups => security_group_ids,
              })
            result.error
          rescue StandardError => e
            e
          end
        end
      end

      check_errors(:set_classic_link, processed.map(&:id), errors)
    end

    def enable_termination_protection(instances)
      @log.info "enabling termination protection on instance(s)"
      errors = run_batch_operation(instances) do |instance|
        begin
          resp = ec2.client.modify_instance_attribute({
              :instance_id => instance.id,
              :disable_api_termination => {
                :value => true
              }
            })
          resp.error  # returns nil (success) unless there was an error
        rescue StandardError => e
          e
        end
      end
      check_errors(:enable_termination_protection, instances.map(&:id), errors)
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
      return @ec2 if @ec2

      # calculate our ec2 url
      ec2_url = "ec2.#{@region}.amazonaws.com"

      if @vpc_id
        @ec2 = AWS::EC2::VPC.new(@vpc_id, :ec2_endpoint => ec2_url)
      else
        @ec2 = AWS::EC2.new(:ec2_endpoint => ec2_url)
      end

      @ec2
    end

    def wait_time_expire_or_sleep(times_out_at)
      now = Time.now
      if now >= times_out_at
        raise TimeoutError, "exceded timeout of #{MAX_RUNNING_STATE_WAIT_TIME} seconds"
      else
        sleep [RUNNING_STATE_WAIT_SLEEP_TIME, times_out_at - now].min
      end
    end

    def configure_aws_creds_and_region
      # configure AWS with creds/region
      aws_configs = {:region => @region}
      aws_configs.merge!({
        :access_key_id     => @aws_access_key,
        :secret_access_key => @aws_secret_key
      }) if @aws_access_key && @aws_secret_key
      aws_configs.merge!({
        :session_token     => @aws_session_token,
      }) if @aws_session_token
      AWS.config(aws_configs)
    end
  end
end
