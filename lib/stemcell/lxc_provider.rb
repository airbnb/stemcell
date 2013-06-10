require 'digest/md5'

require 'logger'
require 'erb'
require 'lxc'

require 'stemcell/provider'

module Stemcell
  class LXCProvider < Provider
    def initialize(opts={})
      @log = Logger.new(STDOUT)
      @log.level = Logger::INFO unless ENV['DEBUG']
      @log.debug "creating new Stemcell object using LXC provider"
      @log.debug "opts are #{opts.inspect}"

      raise 'LXC is not installed on this system' unless LXC.installed?

      # Ubuntu's LXC requires sudo to do anything useful
      LXC.use_sudo = true

      # If user already knows the image name, set it here
      if opts['image_name']
        image = LXC.container(opts['image_name'])
        if image.exists?
          @image = image
        else
          raise "No existing image with name #{opts['image_name']}"
        end
      end
    end

    def launch(opts={})
      opts['count'] = opts['count'] || 1

      unless @image
        verify_required_options(opts,[
          'chef_role',
          'chef_environment',
          'chef_data_bag_secret',
          'git_branch',
          'git_key',
          'git_origin',
          'guest_key'
        ])

        # Create a new image or discover one with identical configuration
        create_image(opts)
      end

      opts['count'].times do
        @image.start
      end

      wait(LXC.containers)
    end

    def create_image(opts)
      image_name = generate_image_name(opts['chef_role'], opts)
      @image = LXC::Container.new(image_name)
      return true if @image.exists?

      # Render the bootstrap script and write to a temp file
      init_template = render_template('bootstrap.sh.erb', opts)
      init_template_path = write_to_tmp('bootstrap.sh', init_template)

      template_options = []
      template_options << "-u #{init_template_path}"

      image.create({
          :template => opts['template'],
          :template_options => template_options,
          :config_file => opts['config_file']
      })
    end

    def destroy_image
      @image.destroy
    end

    def generate_image_name(name, config)
      "#{roles}-#{Digest::MD5.hexdigest(config.to_s)}"
    end

    def wait(instances)
      instances.each do |instance|
        instance.wait('RUNNING')
      end
    end

    def find_instance(name)
      LXC.containers(name)[0]
    end

    def write_to_tmp(filename, content)
      # Hash by content to avoid needless duplicates
      hash = Digest::MD5.hexdigest(content)
      tmp_path = File.join('/tmp', "#{filename}-#{hash}")

      File.open(tmp_path, 'w') do |file|
        file.write(content)
      end unless File.exist?(tmp_path)

      tmp_path
    end

  end
end
