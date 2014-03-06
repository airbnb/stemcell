require 'aws-sdk'
require 'logger'
require 'erb'
require 'pp'
require "stemcell/version"
require "stemcell/option_parser"

module Stemcell
  class Launcher

    REQUIRED_OPTIONS = [
      'aws_access_key',
      'aws_secret_key',
      'region'
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
      'security_groups',
      ['availability_zone', 'vpc_subnet_id'],
      'count'
    ]

    LAUNCH_PARAMETERS = [
      'chef_package_source',
      'chef_version',
      'chef_role',
      'chef_environment',
      'chef_data_bag_secret',
      'git_branch',
      'git_key',
      'git_origin',
      'key_name',
      'instance_type',
      'instance_hostname',
      'instance_domain_name',
      'image_id',
      'availability_zone',
      'count',
      'security_groups',
      'tags',
      'iam_role',
      'ebs_optimized',
      'block_device_mappings',
      'ephemeral_devices',
      'placement_group',
      'vpc_subnet_id',
      'private_ip_address'
    ]

    TEMPLATE_PATH = '../templates/bootstrap.sh.erb'
    LAST_BOOTSTRAP_LINE = "Stemcell bootstrap finished successfully!"

    def initialize(opts={})
      @log = Logger.new(STDOUT)
      @log.level = Logger::INFO unless ENV['DEBUG']
      @log.debug "creating new stemcell object"
      @log.debug "opts are #{opts.inspect}"

      REQUIRED_OPTIONS.each do |req|
        raise ArgumentError, "missing required param #{req}" unless opts[req]
        instance_variable_set("@#{req}",opts[req])
      end

      @ec2_url = "ec2.#{@region}.amazonaws.com"
      @timeout = 300
      @start_time = Time.new

      AWS.config({
        :access_key_id     => @aws_access_key,
        :secret_access_key => @aws_secret_key})

      @ec2 = AWS::EC2.new(:ec2_endpoint => @ec2_url)
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

      if opts['security_groups'].kind_of?(Array)
        opts['security_groups'].each do |name|
          if name.start_with?("sg-")
            if launch_options[:security_group_ids].nil?
              launch_options[:security_group_ids] = []
            end
            launch_options[:security_group_ids] << name
          else
            if launch_options[:security_groups].nil?
              launch_options[:security_groups] = []
            end
            launch_options[:security_groups] << name
          end
        end
      end

      # specify availability zone (optional)
      if opts['availability_zone']
        launch_options[:availability_zone] = opts['availability_zone']
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

      if opts['vpc_subnet_id']
        launch_options[:subnet] = opts['vpc_subnet_id']
      end

      if opts['vpc_subnet_id'] && opts['private_ip_address']
        launch_options[:private_ip_address] = opts['private_ip_address']
      end

      #

      # generate user data script to bootstrap instance, include in launch
      # options UNLESS we have manually set the user-data (ie. for ec2admin)
      launch_options[:user_data] = opts.fetch('user_data', render_template(opts))

      # launch instances
      instances = do_launch(launch_options)

      # set tags on all instances launched
      set_tags(instances, tags)
      @log.info "sent ec2 api requests successfully"

      # wait for aws to report instance stats
      if opts.fetch('wait', true)
        wait(instances)
        print_run_info(instances)
        @log.info "launched instances successfully"
      end

      return instances
    end

    def find_instance(id)
      return @ec2.instances[id]
    end

    def kill(instances,opts={})
      return if instances.nil?
      instances.each do |i|
        begin
          instance = find_instance(i)
          @log.warn "Terminating instance #{instance.instance_id}"
          instance.terminate
        rescue AWS::EC2::Errors::InvalidInstanceID::NotFound => e
          throw e unless opts[:ignore_not_found]
        end
      end
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

    def verify_required_options(params,required_options)
      @log.debug "params is #{params}"
      @log.debug "required_options are #{required_options}"
      required_options.each do |required|

        # Array signals that at least one argument inside array is required
        if required.is_a?(Array)
          unless required.any? { |option| params.include?(option) && !params[option].nil? }
            raise Stemcell::MissingStemcellOptionError.new(required)
          end
        else
          unless params.include?(required) && params[required] != nil
            raise Stemcell::MissingStemcellOptionError.new(required)
          end
        end
      end
    end

    private

    def print_run_info(instances)
      puts "\nhere is the info for what's launched:"
      instances.each do |instance|
        puts "\tinstance_id: #{instance.instance_id}"
        puts "\tpublic ip:   #{instance.public_ip_address}"
        if instance.private_ip_address
          puts "\tprivate ip:  #{instance.private_ip_address}"
        end
        puts
      end
      puts "install logs will be in /var/log/init and /var/log/init.err"
    end

    def wait(instances)
      @log.info "Waiting up to #{@timeout} seconds for #{instances.count} " \
                "instance(s) (#{instances.inspect}):"

      while true
        sleep 5
        if Time.now - @start_time > @timeout
          kill(instances)
          raise TimeoutError, "exceded timeout of #{@timeout}"
        end

        if instances.select{|i| i.status != :running }.empty?
          break
        end
      end

      @log.info "all instances in running state"
    end

    def do_launch(opts={})
      @log.debug "about to launch instance(s) with options #{opts}"
      @log.info "launching instances"
      instances = @ec2.instances.create(opts)
      instances = [instances] unless Array === instances
      instances.each do |instance|
        @log.info "launched instance #{instance.instance_id}"
      end
      return instances
    end

    def set_tags(instances=[],tags)
      @log.info "setting tags on instance(s)"
      instances.each do |instance|
        instance.tags.set(tags)
      end
    end

    # attempt to accept keys as file paths
    def try_file(opt="")
      begin
        return File.read(opt)
      rescue Object => e
        @log.warn "Could not read file #{opt}"
        return opt
      end
    end

  end
end
