require 'logger'
require 'erb'
require 'aws-sdk'

require_relative "stemcell/version"

module Stemcell
  class Stemcell
    def initialize(opts={})
      @log = Logger.new(STDOUT)
      @log.debug "opts are #{opts.inspect}"
      ['aws_access_key',
       'aws_secret_key',
       'region',
       'machine_type',
       'image',
       'security_group',

       'chef_role',
       'git_branch',
       'git_key',
       'git_origin',
       'key_name',
      ].each do |req|
        raise ArgumentError, "missing required param #{req}" unless opts[req]
        instance_variable_set("@#{req}",opts[req])
      end

      @zone = opts.include?('availability_zone') ? opts['availability_zone'] : nil
      @ec2_url = "ec2.#{@region}.amazonaws.com"
      @timeout = 120
      @start_time = Time.new

      @tags = {
        'Name' => "#{@chef_role}-#{@git_branch}",
        'Group' => "#{@chef_role}-#{@git_branch}",
        'created_by' => ENV['USER'],
        'stemcell' => VERSION,
      }

      if opts['tags']
        opts['tags'].split(',').each do |tag_set|
          key, value = tag_set.split('=')
          @tags[key] = value
        end
      end

      begin
        @git_key_contents = File.read(@git_key)
      rescue Object => e
        raise "\ncould not open specified key #{@git_key}:\n#{e.inspect}#{e.backtrace}"
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
      set_tags(instances)
      print_run_info(instances)
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
      @log.info "Waiting for #{instances.count} instances (#{instances.inspect}):"

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

    def do_launch(opts={})
      options = {
        :image_id => @image,
        :security_groups => @security_group,
        :user_data => @user_data,
        :instance_type => @machine_type,
        :key_name => @key_name,
      }
      options[:availability_zone] = @zone if @zone
      options[:count] = opts['count'] if opts.include?('count')

      instances = @ec2_region.instances.create(options)
      instances = [instances] unless instances.class == Array
      instances.each do |instance|
        @log.info "launched instance #{instance.instance_id}"
      end
      return instances
    end

    def set_tags(instances=[])
      instances.each do |instance|
        instance.tags.set(@tags)
      end
    end

    def render_template
      this_file = File.expand_path __FILE__
      base_dir = File.dirname this_file
      template_file_path = File.join(base_dir,'stemcell','templates','bootstrap.sh.erb')
      template_file = File.read(template_file_path)
      erb_template = ERB.new(template_file)
      generated_template = erb_template.result(binding)
      return generated_template
    end

    def bail(instances)
      return if instances.nil?
      instances.each do |instance|
        log.warn "Terminating instance #{instance.instance_id}"
        instance.delete
      end
    end
  end
end
