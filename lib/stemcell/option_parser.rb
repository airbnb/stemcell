require 'trollop'

module Stemcell
  class OptionParser
    attr_reader :options

    attr_reader :defaults
    attr_reader :version
    attr_reader :banner
    attr_reader :override_help

    OPTION_DEFINITIONS = [
      {
        :name  => 'local_chef_root',
        :desc  => "directory of your local chef repository",
        :type  => String,
        :env   =>  'LOCAL_CHEF_ROOT'
      },
      {
        :name  => 'aws_creds',
        :desc  => "select the aws credentials to use, via the aws-creds gem",
        :type  => String,
        :env   =>  'AWS_CREDS'
      },
      {
        :name  => 'aws_access_key',
        :desc  => "aws access key",
        :type  => String,
        :env   => 'AWS_ACCESS_KEY'
      },
      {
        :name  => 'aws_secret_key',
        :desc  => "aws secret key",
        :type  => String,
        :env   => 'AWS_SECRET_KEY'
      },
      {
        :name  => 'region',
        :desc  => "ec2 region to launch in",
        :type  => String,
        :env   => 'REGION'
      },
      {
        :name  => 'instance_type',
        :desc  => "machine type to launch",
        :type  => String,
        :env   => 'INSTANCE_TYPE'
      },
      {
        :name  => 'backing_store',
        :desc  => "select between the backing store templates",
        :type  => String,
        :env   =>  'BACKING_STORE'
      },
      {
        :name  => 'image_id',
        :desc  => "ami to use for launch",
        :type  => String,
        :env   => 'IMAGE_ID'
      },
      {
        :name  => 'security_groups',
        :desc  => "comma-separated list of security groups to launch instance with",
        :type  => String,
        :env   => 'SECURITY_GROUPS'
      },
      {
        :name  => 'availability_zone',
        :desc  => "zone in which to launch instances",
        :type  => String,
        :env   => 'AVAILABILITY_ZONE'
      },
      {
        :name  => 'tags',
        :desc  => "comma-separated list of key=value pairs to apply",
        :type  => String,
        :env   => 'TAGS'
      },
      {
        :name  => 'key_name',
        :desc  => "aws ssh key name for the ubuntu user",
        :type  => String,
        :env   => 'KEY_NAME'
      },
      {
        :name  => 'iam_role',
        :desc  => "IAM role to associate with the instance",
        :type  => String,
        :env   => 'IAM_ROLE'
      },
      {
        :name  => 'placement_group',
        :desc  => "Placement group to associate with the instance",
        :type  => String,
        :env   => 'PLACEMENT_GROUP'
      },
      {
        :name  => 'ebs_optimized',
        :desc  => "launch an EBS-Optimized instance",
        :type  => String,
        :env   => 'EBS_OPTIMIZED'
      },
      {
        :name  => 'ephemeral_devices',
        :desc  => "comma-separated list of block devices to map ephemeral devices to",
        :type  => String,
        :env   => 'EPHEMERAL_DEVICES'
      },
      {
        :name  => 'chef_data_bag_secret',
        :desc  => "path to secret file (or the string containing the secret)",
        :type  => String,
        :env   => 'CHEF_DATA_BAG_SECRET'
      },
      {
        :name => 'chef_role',
        :desc => "chef role of instance to be launched",
        :type => String,
        :env  => 'CHEF_ROLE'
      },
      {
        :name  => 'chef_environment',
        :desc  => "chef environment in which this instance will run",
        :type  => String,
        :env   => 'CHEF_ENVIRONMENT'
      },
      {
        :name  => 'git_origin',
        :desc  => "git origin to use",
        :type  => String,
        :env   => 'GIT_ORIGIN'
      },
      {
        :name  => 'git_branch',
        :desc  => "git branch to run off",
        :type  => String,
        :env   => 'GIT_BRANCH'
      },
      {
        :name  => 'git_key',
        :desc  => "path to the git repo deploy key (or the key as a string)",
        :type  => String,
        :env   => 'GIT_KEY'
      },
      {
        :name  => 'count',
        :desc  => "number of instances to launch",
        :type  => Integer,
        :env   => 'COUNT'
      },
      {
        :name  => 'tail',
        :desc  => "interactively tail the initial converge",
        :type  => nil,
        :env   => 'TAIL',
        :short => :t
      },
      {
        :name  => 'ssh_user',
        :desc  => "ssh username",
        :type  => String,
        :env   => 'SSH_USER',
        :short => :u
      },
      {
        :name  => 'non_interactive',
        :desc  => "assumes an affirmative answer to all prompts",
        :type  => nil,
        :env   => 'NON_INTERACTIVE',
        :short => :f
      }
    ]

    def initialize(config={})
      @defaults = config[:defaults] || {}
      @version = config[:version]
      @banner = config[:banner]
      @override_help = config[:override_help]
    end

    def parse!(args)
      # The block passed to Trollop#options is evaluated in the binding of the
      # trollop parser itself, it doesn't have access to the this instance.
      # So use a value that can be captured instead!
      _this = self
      _defns = OPTION_DEFINITIONS

      @options = Trollop::options(args) do
        version _this.version if _this.version
        banner  _this.banner  if _this.banner

        _defns.each do |defn|
          # Prioritize the environment variable, then the given default
          default = ENV[defn[:env]] || _this.defaults[defn[:name]]

          opt(
            defn[:name],
            defn[:desc],
              :type    => defn[:type],
              :short   => defn[:short],
              :default => default)
        end

        # Prevent trollop from showing its help screen
        opt('help', 'help', :short => :l) if _this.override_help
      end

      # convert tags from string to ruby hash
      if options['tags']
        tags = {}
        options['tags'].split(',').each do |tag_set|
          key, value = tag_set.split('=')
          tags[key] = value
        end
        options['tags'] = tags
      end

      # convert security_groups from comma seperated string to ruby array
      options['security_groups'] &&= options['security_groups'].split(',')
      # convert ephemeral_devices from comma separated string to ruby array
      options['ephemeral_devices'] &&= options['ephemeral_devices'].split(',')

      options
    end

  end
end
