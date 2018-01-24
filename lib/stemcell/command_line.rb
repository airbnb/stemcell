require 'aws/creds'
require 'colored'

module Stemcell
  class CommandLine
    attr_reader :launcher
    attr_reader :showing_help
    attr_reader :chef_root
    attr_reader :chef_role

    VERSION_STRING = "Stemcell #{VERSION} (c) 2012-2016 Airbnb."
    BANNER_STRING  = "Launch instances from metadata stored in roles!\n" \
                     "Usage: stemcell [chef role] [options]"

    OPTION_PARSER_DEFAULTS = {
      'non_interactive' => false,
      'aws_creds'       => 'default',
      'ssh_user'        => 'ubuntu'
    }

    def self.run!
      CommandLine.new.run!
    end

    def run!
      determine_root_and_showing_help

      initialize_launcher
      retrieve_defaults
      configure_option_parser

      options = parse_options_or_print_help
      determine_role(options)

      print_usage_and_exit unless chef_role
      # If we didn't successfully initialize the launcher, we should exit.
      exit unless @launcher

      print_version
      display_chef_repo_warnings

      # Retrieve AWS credentials via the aws-creds gems (if available)
      awc_name = options.delete('aws_creds')
      credentials = retrieve_credentials_from_awc(awc_name)
      options.merge!(credentials) if credentials
      # Move launcher in the non-interactive mode (if requested)
      launcher.interactive = !options.delete('non_interactive')

      instances = launch_instance(chef_role, options)
      tail_converge(instances, options) if options['tail']

      puts "\nDone.\n".green
    end

    private

    def determine_root_and_showing_help
      # First pass at parsing the options to find the local chef root and
      # whether or not we're showing the help screen.
      provisional_option_parser = OptionParser.new(:override_help => true)
      initial_options = provisional_option_parser.parse!(ARGV.dup)

      # Remove the role before parsing any remaining options.
      @showing_help = !!initial_options['help']
      @chef_root    =   initial_options['local_chef_root']

      # If we didn't receive a chef root, assume the current directory.
      @chef_root  ||=   File.expand_path('.')
    end

    def initialize_launcher
      @launcher = MetadataLauncher.new(:chef_root => chef_root)
    rescue MissingMetadataConfigError
      puts "Couldn't find `stemcell.json` in the local chef repo.".red
      puts "You must specify the root of the local checkout of your chef " \
           "respository by using the --local-chef-root options or " \
           "setting the LOCAL_CHEF_ROOT environment variable."
    rescue MetadataConfigParseError => e
      error "Couldn't parse the `stemcell.json` file: #{e.message}"
    end

    def launch_instance(role, options={})
      launcher.run!(role, options)
    rescue RoleExpansionError
      error "There was a problem expanding the #{chef_role} role. " \
            "Perhaps it or one of its dependencies does not exist."
    rescue MissingStemcellOptionError => e
      error "The '#{e.option}' attribute needs to be specified on the " \
            "command line, in the role, in the stemcell.json defaults, " \
            "or set by the #{e.option.upcase.gsub('-','_')} environment variable."
    rescue UnknownBackingStoreError => e
      error "Unknown backing store type: #{e.backing_store}."
    end

    def tail_converge(instances, options={})
      puts "\nTailing the initial converge. Press Ctrl-C to exit...".green

      if instances.count > 1
        puts "\nYou're launching more than one instance."
        puts "Showing you on the output from #{instances.first.instance_id}."
      end

      puts "\n"
      tailer = LogTailer.new(instances.first.public_dns_name, options['ssh_user'])
      tailer.run!
    end

    def retrieve_defaults
      @default_options = launcher ? launcher.default_options : {}
      @default_branch  = @default_options['git_branch']
    end

    def configure_option_parser
      parser_defaults = OPTION_PARSER_DEFAULTS
      if showing_help
        parser_defaults = parser_defaults.merge!(@default_options)
        transform_parser_defaults(parser_defaults)
      end

      @option_parser = OptionParser.new({
        :defaults => parser_defaults,
        :version  => VERSION_STRING,
        :banner   => BANNER_STRING
      })
    end

    def transform_parser_defaults(pd)
      # There are some special cases, eg security groups and tags. Security groups
      # are an array in the template, but trollop expects a string. Likewise,
      # in the case of tags, they are represented as a hash, but trollop wants
      # a string once again. In both cases, the data types are encoded as a
      # comma-separated list when presented as defaults.
      pd['security_groups'] &&= pd['security_groups'].join(',')
      pd['tags'] &&= pd['tags'].to_a.map { |p| p.join('=') }.join(',')
      pd['chef_cookbook_attributes'] &&= pd['chef_cookbook_attributes'].join(',')
    end

    def parse_options_or_print_help
      parsed_options = @option_parser.parse!(ARGV)
      # Parsed options will contain nil values, strip them out.
      parsed_options.keys.each do |key|
        value = parsed_options[key]
        parsed_options.delete(key) unless key.is_a?(String) && value
      end
      parsed_options
    end

    def determine_role(options)
      role = ARGV.shift
      @chef_role = role if role && role.length > 0
      @chef_role ||= options['chef_role']
    end

    def retrieve_credentials_from_awc(name)
      creds = AWS::Creds[name || 'default']
      return creds && {
        'aws_access_key' => creds.access_key_id,
        'aws_secret_key' => creds.secret_access_key
      }
    rescue AWS::Creds::InvalidKeyTab,
           AWS::Creds::InvalidKeyPair
    end

    def validate_chef_root
      unless chef_root_valid?
        error "This isn't a chef repository: no roles folder."
      end
    end

    def display_chef_repo_warnings
      # Print a series of warnings about the chef repo state.
      if not_default_branch?
        warning "You are not on the '#{@default_branch}' branch!"
      end
      if has_unstaged_changes?
        warning "You have unstaged changes."
      end
      if has_uncommitted_changes?
        warning "Your index contains uncommitted changes."
      end
    end

    def chef_root_valid?
      File.directory?(File.join(chef_root, 'roles'))
    end

    def not_default_branch?
      run_in_chef("git rev-parse --abbrev-ref HEAD").strip != @default_branch
    end

    def has_unstaged_changes?
      run_in_chef("git diff-files --quiet --ignore-submodules")
      $? != 0
    end

    def has_uncommitted_changes?
      run_in_chef("git diff-index --cached --quiet HEAD --ignore-submodules")
      $? != 0
    end

    def run_in_chef(command)
      `cd #{chef_root}; #{command}`
    end

    def error(string)
      warn "\nERROR: #{string}\n".red
      exit 1
    end

    def warning(string)
      warn "\nWARNING: #{string}".red
    end

    def print_version
      puts "#{VERSION_STRING}\n"
    end

    def print_usage_and_exit
      puts "#{BANNER_STRING}\n"
      exit
    end
  end
end
