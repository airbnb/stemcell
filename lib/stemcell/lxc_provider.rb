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
    end

    def launch(opts={})
      verify_required_options(opts,[
        'count',
        'chef_role',
        'chef_environment',
        'chef_data_bag_secret',
        'git_branch',
        'git_key',
        'git_origin',
      ])


      default_opts = {
        'name' => Time.now.to_i.to_s,
        'template' => 'ubuntu-cloud',
        'count' => 1
      }
      opts.reverse_merge!(default_opts)

      opts['git_key'] = try_file(opts['git_key'])

      # Render the bootstrap script and write to a temp file
      init_template = render_template('bootstrap.sh.erb', opts)
      init_template_path = write_to_tmp('bootstrap.sh', init_template)

      template_options = []
      template_options << "-u #{init_template_path}"

      opts[:count].each do
        container = LXC::Container.new(opts[:name])
        container.create({
          :template => opts[:template],
          :template_options => template_options,
          :config_file => opts[:config_file]
        })
      end

      wait(LXC.containers)
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
