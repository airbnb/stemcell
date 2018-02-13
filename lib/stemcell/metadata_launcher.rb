module Stemcell
  class MetadataLauncher
    attr_reader :chef_root
    attr_accessor :interactive

    attr_reader :source

    def initialize(options={})
      @chef_root = options[:chef_root]
      @interactive = options.fetch(:interactive, false)

      raise ArgumentError, "You must specify chef_root" unless chef_root

      @source = MetadataSource.new(chef_root)
    end

    def run!(role, override_options={})
      environment = expand_environment(override_options)
      launch_options = determine_options(role, environment, override_options)

      validate_options(launch_options)
      describe_instance(launch_options)
      invoke_launcher(launch_options)
    end

    def default_options
      source.default_options
    end

    private

    def expand_environment(override_opts)
      override_opts['chef_environment'] ||
        default_options['chef_environment']
    end

    def determine_options(role, environment, override_options)
      contexts = override_options.delete('contexts').split(',') rescue []
      # Initially assume that empty roles are not allowed
      allow_empty = false
      begin
        return source.expand_role(
          role,
          environment,
          contexts,
          override_options,
          :allow_empty_roles => allow_empty)
      rescue EmptyRoleError
        warn_empty_role
        allow_empty = true
        retry
      end
    end

    def validate_options(options={})
      [ Launcher::REQUIRED_OPTIONS,
        Launcher::REQUIRED_LAUNCH_PARAMETERS
      ].flatten.each do |arg|
        if options[arg].nil? or !options[arg]
          raise Stemcell::MissingStemcellOptionError.new(arg)
        end
      end
    end

    def describe_instance(options={})
      puts "\nYou're about to launch instance(s) with the following options:\n\n"

      options.keys.sort.each do |key|
        next if key == "aws_secret_key"
        value = options[key]
        next unless value
        spaces = " " * (30 - key.length)
        puts "  #{key}#{spaces}#{value.to_s.green}"
      end

      if interactive
        print "\nProceed? (y/N) "
        confirm = $stdin.gets
        exit unless confirm.chomp.downcase == 'y'
      end

      # One more new line to be pretty.
      print "\n"
    end

    def warn_empty_role
      warn "\nWARNING: This role contains no stemcell attributes.".yellow

      if interactive
        print "\nDo you want to launch it anyways? (y/N) "
        confirm = $stdin.gets
        exit unless confirm.chomp.downcase == 'y'
      end
    end

    def invoke_launcher(options={})
      launcher = Launcher.new({
        'aws_access_key'    => options['aws_access_key'],
        'aws_secret_key'    => options['aws_secret_key'],
        'aws_session_token' => options['aws_session_token'],
        'region'            => options['region'],
        'vpc_id'            => options['vpc_id'],
        'max_attempts'      => options['batch_operation_retries'],
      })
      # Slice off just the options used for launching.
      launch_options = {}
      Launcher::LAUNCH_PARAMETERS.each do |a|
        launch_options[a] = options[a]
      end
      # Create the instance from these options.
      launcher.launch(launch_options)
    end
  end
end
