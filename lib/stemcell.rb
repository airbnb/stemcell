require 'logger'
require 'erb'
require 'aws-sdk'

require_relative "stemcell/version"

module Stemcell
  class Stemcell
    def initialize(opts={})
      @log = Logger.new(STDOUT)
      @log.level = Logger::INFO unless ENV['DEBUG']
      @log.debug "creating new stemcell object"
      @log.debug "opts are #{opts.inspect}"
      ['aws_access_key',
       'aws_secret_key',
       'region',
      ].each do |req|
        raise ArgumentError, "missing required param #{req}" unless opts[req]
        instance_variable_set("@#{req}",opts[req])
      end

      @ec2_url = "ec2.#{@region}.amazonaws.com"
      @timeout = 120
      @start_time = Time.new

      AWS.config({:access_key_id => @aws_access_key, :secret_access_key => @aws_secret_key})
      @ec2 = AWS::EC2.new(:ec2_endpoint => @ec2_url)
      @ec2_region = @ec2.regions[@region]
    end


    def launch(opts={})
      verify_required_options(opts,[
        'image_id',
        'security_groups',
        'key_name',
        'count',
        'chef_role',
        'chef_environment',
        'chef_data_bag_secret',
        'git_branch',
        'git_key',
        'git_origin',
        'instance_type',
      ])

      # attempt to accept keys as file paths
      opts['git_key'] = try_file(opts['git_key'])
      opts['chef_data_bag_secret'] = try_file(opts['chef_data_bag_secret'])

      # generate tags and merge in any that were specefied as in inputs
      tags = {
        'Name' => "#{opts['chef_role']}-#{opts['chef_environment']}",
        'Group' => "#{opts['chef_role']}-#{opts['chef_environment']}",
        'created_by' => ENV['USER'],
        'stemcell' => VERSION,
      }
      tags.merge!(opts['tags']) if opts['tags']

      # generate user data script to boot strap instance based on the
      # opts that we were passed.
      user_data = render_template(opts)

      launch_options = {
        :image_id => opts['image_id'],
        :security_groups => opts['security_groups'],
        :user_data => opts['user_data'],
        :instance_type => opts['instance_type'],
        :key_name => opts['key_name'],
        :count => opts['count'],
        :user_data => user_data,
      }
      launch_options.merge({:availability_zone => opts['availability_zone']}) if opts['availability_zone']

      # launch instances
      instances = do_launch(launch_options)

      # wait for aws to report instance stats
      wait(instances)

      # set tags on all instances launched
      set_tags(instances, tags)

      print_run_info(instances)
      @log.info "launched instances successfully"
      return instances
    end

    private

    def print_run_info(instances)
      puts "here is the info for what's launched:"
      instances.each do |instance|
        puts "\tinstance_id: #{instance.instance_id}"
        puts "\tpublic ip:   #{instance.public_ip_address}"
        puts
      end
      puts "install logs will be in /var/log/init and /var/log/init.err"
    end

    def wait(instances)
      @log.info "Waiting up to #{@timeout} seconds for #{instances.count} instances (#{instances.inspect}):"

      while true
        sleep 5
        if Time.now - @start_time > @timeout
          bail(instances)
          raise TimeoutError, "exceded timeout of #{@timeout}"
        end

        if instances.select{|i| i.status != :running }.empty?
          break
        end
      end

      @log.info "all instances in running state"
    end

    def verify_required_options(params,required_options)
      @log.debug "params is #{params}"
      @log.debug "required_options are #{required_options}"
      required_options.each do |required|
        raise ArgumentError, "you need to provide option #{required}" unless params[required]
      end
    end

    def do_launch(opts={})
      @log.debug "about to launch instance(s) with options #{opts}"
      @log.info "launching instances"
      instances = @ec2_region.instances.create(opts)
      instances = [instances] unless instances.class == Array
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

    def render_template(opts={})
      this_file = File.expand_path __FILE__
      base_dir = File.dirname this_file
      template_file_path = File.join(base_dir,'stemcell','templates','bootstrap.sh.erb')
      template_file = File.read(template_file_path)
      erb_template = ERB.new(template_file)
      generated_template = erb_template.result(binding)
      @log.debug "genereated template is #{generated_template}"
      return generated_template
    end

    def bail(instances)
      return if instances.nil?
      instances.each do |instance|
        log.warn "Terminating instance #{instance.instance_id}"
        instance.delete
      end
    end

    # attempt to accept keys as file paths
    def try_file(opt="")
      begin
        return File.read(opt)
      rescue Object => e
        return opt
      end
    end

  end
end
