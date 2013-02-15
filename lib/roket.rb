require 'logger'
require 'erb'
require 'aws-sdk'

require_relative "roket/version"

module Roket
  class Roket
    def initialize(opts={})
      @log = Logger.new(STDOUT)
      @log.debug "opts are #{opts.inspect}"
      ['aws_access_key',
       'aws_secret_key',
       'chef_validation_key_name',
       'chef_validation_key',
       'chef_role',
       'chef_environment',
       'key_name',
      ].each do |req|
        raise ArgumentError, "missing required param #{req}" unless opts[req]
        instance_variable_set("@#{req}",opts[req])
      end

      @security_group = opts['security_group'] ? opts['security_group'] : 'default'
      @image = opts['image'] ? opts['image'] : 'ami-d726abbe'
      @machine_type = opts['machine_type'] ? opts['machine_type'] : 'm1.small'
      @region = opts['region'] ? opts['region'] : 'us-east-1'
      @ec2_url = "ec2.#{@region}.amazonaws.com"
      @timeout = 120
      @start_time = Time.new

      begin
        @chef_validation_key_value = File.read(@chef_validation_key)
      rescue Object => e
        raise "\ncould not open specified key #{@chef_validation_key}:\n#{e.inspect}#{e.backtrace}"
      end

      if opts['chef_data_bag_secret']
        begin
          @chef_data_bag_secret = File.read(opts['chef_data_bag_secret'])
        rescue Object => e
          raise "\ncould not open specified secret key file #{opts['chef_data_bag_secret']}:\n#{e.inspect}#{e.backtrace}"
        end
      else
        @chef_data_bag_secret = ''
      end

      AWS.config({:access_key_id => @aws_access_key, :secret_access_key => @aws_secret_key})
      @ec2 = AWS::EC2.new(:ec2_endpoint => @ec2_url)
      @ec2_region = @ec2.regions[@region]

      @user_data = render_template
    end

    def launch(opts={})
      File.open('/tmp/user-data', 'w') {|f| f.write(@user_data) }
      instances = do_launch(opts)
      wait(instances)
      print_run_info(instances)
      print_config_info
      return instances
    end

    private

    def print_config_info
      puts "install logs will be in /var/log/init and /var/log/init.err"
    end

    def print_run_info(instances)
      puts "here is the info for what's launched:"
      instances.each do |instance|
        puts "\tinstance_id: #{instance.instance_id}"
        puts "\tpublic ip:   #{instance.public_ip_address}"
        puts
      end
    end

    def wait(instances)
      sleep 3
      while true
        if Time.now - @start_time > @timeout
          bail(instances)
          raise TimeoutError, "exceded timeout of #{@timeout}"
        end
        puts "instances is #{instances.inspect}"
        if instances.select{|i| i.status != :running }.empty?
          @log.info "all instances in running state"
          return
        end
        @log.info "instances not ready yet. sleeping..."
        sleep 5
        return wait(instances)
      end
    end

    def do_launch(opts={})
      options = {
        :image_id => @image,
        :security_groups => @security_group,
        :user_data => @user_data,
        :instance_type => @machine_type,
        :key_name => @key_name,
      }
      options.merge!({:availability_zone => opts['avilibility_zone']}) if opts['availability_zone']
      options.merge!({:count => opts['count']}) if opts['count']
      puts "creating instance with options:\n#{options}"
      instances = @ec2_region.instances.create(options)
      instances = [instances] unless instances.class == Array
      instances.each do |instance|
        @log.info "launched instance #{instance.instance_id}"
      end
      return instances
    end

    def render_template
      this_file = File.expand_path __FILE__
      base_dir = File.dirname this_file
      template_file_path = File.join(base_dir,'roket','templates','bootstrap.sh.erb')
      template_file = File.read(template_file_path)
      erb_template = ERB.new(template_file)
      generated_template = erb_template.result(binding)
      return generated_template
    end

    def bail(instances)
      return if instances.nil?
      instances.each do |instance|
        instance.delete
      end
    end

  end
end
