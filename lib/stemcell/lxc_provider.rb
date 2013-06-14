require 'digest/md5'
require 'base64'

require 'logger'
require 'erb'
require 'lxc'
require 'posix/spawn'

require 'stemcell/provider'

module Stemcell
  class LXCProvider < Provider
    attr_reader :image

    def initialize(opts={})
      @log = Logger.new(STDOUT)
      @log.level = Logger::INFO unless ENV['DEBUG']
      @log.debug "creating new Stemcell object using LXC provider"
      @log.debug "opts are #{opts.inspect}"

      # Ubuntu's LXC requires sudo to do anything useful
      @lxc = LXC.new(:use_sudo => true)

      # If user already knows the image name, set it here
      if opts['image_name']
        image = @lxc.container(opts['image_name'])
        if image.exists?
          @image = image
        else
          raise "No existing image with name #{opts['image_name']}"
        end
      end
    end

    def launch(opts={})
      opts['count'] = opts['count'] || 1
      verify_required_options(opts, ['guest_key'])

      unless @image
        verify_required_options(opts,[
          'chef_role',
          'chef_environment',
          'chef_data_bag_secret',
          'git_branch',
          'git_key',
          'git_origin',
          'guest_public_key'
        ])

        # Specify the type of instance. Affects the bootstrap.sh template
        # TODO: This is a hack. Shouldn't put random stuff into opts object
        opts['instance_provider'] = 'lxc'

        # Create a new image or discover one with identical configuration
        create_image(opts)
      end

      # Keep track of containers already running to compare after launching
      existing = {}
      @lxc.containers.each do |c|
        existing[c.name] = true
      end

      # LXC gem doesn't play well with start-ephemeral. Spawn own processes for now
      command = "sudo lxc-start-ephemeral -d "
      command << "-o #{@image.name} "
      command << "-S #{opts['guest_key']}"

      opts['count'].times do
        pid = POSIX::Spawn::spawn(command, :in => "/dev/null", :out => "/dev/null")
        sleep 0.125
      end

      # Identify the containers that were not previously existing and wait on them to start
      launched = @lxc.containers.select {|c| existing[c.name].nil?}
      wait(launched)

      launched
    end

    def create_image(opts)
      image_name = generate_image_name(opts['chef_role'], opts)
      @image = LXC::Container.new(:lxc=> @lxc, :name => image_name)
      return @image if @image.exists?

      # Read options as paths or file contents
      opts['git_key'] = try_file(opts['git_key'])
      opts['guest_public_key'] = try_file(opts['guest_public_key'])
      opts['chef_data_bag_secret'] = try_file(opts['chef_data_bag_secret'])

      # Render the bootstrap scripts and write to a tmp
      cloud_config = render_template('cloud-config.txt.erb', opts)
      cloud_config_path = write_to_tmp('cloud-config.txt', cloud_config_path)

      user_script = render_template('bootstrap.sh.erb', opts)
      user_script_path = write_to_tmp('bootstrap.sh', user_script)

      # Combine cloud config and user data using Ubuntu's built-in tool
      cloud_init_path = write_mime_multipart('/tmp/cloud_init', cloud_config_path, user_script_path)

      template_options = []
      template_options << "-u #{cloud_init_path}"

      @image if @image.create("-t ubuntu-cloud", "--", template_options)
    end

    def destroy_image
      @image.destroy
    end

    def generate_image_name(role, config)
      # Hash the config, base64 encode to shorten. Remove 
      hash = Base64.urlsafe_encode64(Digest::MD5.digest(config.to_s)).chomp("==")
      "#{role}-#{hash}"
    end

    def wait(instances)
      instances.each do |instance|
        instance.wait('RUNNING')
      end
    end

    def get_instance_ip(name)
      # Find the IP from the DHCP leases given out by dnsmasq
      cmd = "grep #{name} /var/lib/misc/dnsmasq.leases | awk '{print $3}'"
      child = POSIX::Spawn::Child.new(cmd.strip)
      child.out.strip
    end

    def find_instance(name)
      @lxc.containers.select {|c| c.name == name}[0]
    end

    def instances
      @lxc.containers.select {|c| c.running?}
    end

    private
      def write_to_tmp(filename, content)
        # Hash by content to avoid needless duplicates
        hash = Base64.urlsafe_encode64(Digest::MD5.digest(content)).chomp("==")
        tmp_path = File.join('/tmp', "#{filename}-#{hash}")

        File.open(tmp_path, 'w') do |file|
          file.write(content)
        end unless File.exist?(tmp_path)

        tmp_path
      end

      def write_mime_multipart(opts)
        cmd = "write-mime-multipart"
        cmd << " #{opts[:cloud_config]}:text/cloud-config" if opts[:cloud_config]
        cmd << " #{opts[:user_data]}:text/x-shellscript" if opts[:user_data]

        child = POSIX::Spawn::Child.new(cmd.strip)
        child.out
      end

  end
end
