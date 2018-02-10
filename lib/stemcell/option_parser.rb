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
        :env   => 'AWS_SECRET_KEY',
        :hide  => true
      },
      {
        :name  => 'aws_session_token',
        :desc  => "aws session token",
        :type  => String,
        :env   => 'AWS_SESSION_TOKEN',
        :hide  => true
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
        :name  => 'security_group_ids',
        :desc  => "comma-separated list of security group IDs to launch instance with",
        :type  => String,
        :env   => 'SECURITY_GROUP_IDS'
      },
      {
        :name  => 'availability_zone',
        :desc  => "zone in which to launch instances",
        :type  => String,
        :env   => 'AVAILABILITY_ZONE'
      },
      {
        :name  => 'vpc_id',
        :desc  => "VPC ID for which to launch this instance",
        :type  => String,
        :env   => 'VPC_ID'
      },
      {
        :name  => 'classic_link_vpc_id',
        :desc  => 'VPC ID to which this instance will be classic-linked',
        :type  => String,
        :env   => 'CLASSIC_LINK_VPC_ID',
      },
      {
        :name  => 'classic_link_security_group_ids',
        :desc  => 'comma-separated list of security group IDs to link into ClassicLink; not used unless classic_link_vpc_id is set',
        :type  => String,
        :env   => 'CLASSIC_LINK_SECURITY_GROUP_IDS',
      },
      {
        :name  => 'classic_link_security_groups',
        :desc  => 'comma-separated list of security groups to link into ClassicLink; not used unless classic_link_vpc_id is set',
        :type  => String,
        :env   => 'CLASSIC_LINK_SECURITY_GROUPS',
      },
      {
        :name  => 'subnet',
        :desc  => "VPC subnet for which to launch this instance",
        :type  => String,
        :env   => 'SUBNET'
      },
      {
        :name  => 'private_ip_address',
        :desc  => "VPC private IP to use",
        :type  => String,
        :env   => 'PRIVATE_IP_ADDRESS'
      },
      {
        :name  => 'dedicated_tenancy',
        :desc  => "Enable dedicated tenancy",
        :env   => 'DEDICATED_TENANCY',
        :default => false,
      },
      {
        :name  => 'associate_public_ip_address',
        :desc  => "Associate public IP address (for VPC)",
        :env   => 'ASSOCIATE_PUBLIC_IP_ADDRESS',
        :default => false,
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
        :name  => 'termination_protection',
        :desc  => "Prevent created instances from being terminated via the API",
        :type  => String,
        :env   => 'TERMINATION_PROTECTION'
      },
      {
        :name  => 'instance_initiated_shutdown_behavior',
        :desc  => "What happens when the instance shuts down? ('stop' or 'terminate')",
        :type  => String,
        :default => 'stop',
        :env   => 'INSTANCE_INITIATED_SHUTDOWN_BEHAVIOR',
      },
      {
        :name  => 'block_device_mappings',
        :desc  => 'block device mappings',
        :type  => String,
        :env   => 'BLOCK_DEVICE_MAPPINGS'
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
        :name  => 'chef_data_bag_secret_path',
        :desc  => "instance-local path to the secret file",
        :type  => String,
        :env   => 'CHEF_DATA_BAG_SECRET_PATH'
      },
      {
        :name => 'chef_role',
        :desc => "chef role of instance to be launched",
        :type => String,
        :env  => 'CHEF_ROLE'
      },
      {
        :name  => 'chef_version',
        :desc  => "the chef version we will bootstrap on the box (defaults to 11.4.0)",
        :type  => String,
        :env   => 'CHEF_VERSION'
      },
      {
        :name  => 'chef_package_source',
        :desc  => "source of chef packages (defaults to https://opscode-omnibus-packages.s3.amazonaws.com)",
        :type  => String,
        :env   => 'CHEF_PACKAGE_SOURCE'
      },
      {
        :name  => 'chef_environment',
        :desc  => "chef environment in which this instance will run",
        :type  => String,
        :env   => 'CHEF_ENVIRONMENT'
      },
      {
        :name  => 'chef_cookbook_attributes',
        :desc  => "comma-separated list of cookbook attribute files to load during role expansion",
        :type  => String,
        :env   => 'CHEF_COOKBOOK_ATTRIBUTES'
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
        :name  => 'instance_hostname',
        :desc  => "the hostname of new instances; defaults to the instance id if omitted",
        :type  => String,
        :env   => 'INSTANCE_HOSTNAME'
      },
      {
        :name  => 'instance_domain_name',
        :desc  => "the domain part of the FQDN of created instances (like airbnb.com)",
        :type  => String,
        :env   => 'INSTANCE_DOMAIN_NAME'
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
      },
      {
        :name  => 'contexts',
        :desc  => "comma-separated list of contexts to override certain values",
        :type  => String,
        :env   => "CONTEXTS",
      },
      {
        :name  => 'batch_operation_retries',
        :desc  => "maximum number of retries",
        :type  => Integer,
        :env   => 'BATCH_OPERATION_RETRIES',
        :short => :r,
        :default => 3,
      },
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
          if defn[:hide]
            default = "<hidden>"
          else
            default = ENV[defn[:env]] || _this.defaults[defn[:name]]
          end

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

      # Populate the hidden defaults. Some (like aws secret key) is :hidden so that Trollop wont print that into stdout
      _defns.each do |defn|
        if defn[:hide] && options[defn[:name]] == "<hidden>"
          options[defn[:name]] = ENV[defn[:env]] || _this.defaults[defn[:name]]
        end
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

      # parse block_device_mappings to convert it from the standard CLI format
      # to the EC2 Ruby API format.
      # All of this is a bit hard to find so here are some docs links to
      # understand

      # CLI This format is documented by typing
      # ec2-run-instances --help and looking at the -b option
      # Basically, it's either

      # none
      # ephemeral<number>
      # '[<snapshot-id>][:<size>[:<delete-on-termination>][:<type>[:<iops>]]]'

      # Ruby API (that does call to the native API)
      # gems/aws-sdk-1.17.0/lib/aws/ec2/instance_collection.rb
      # line 91 + example line 57

      if options['block_device_mappings']
        block_device_mappings = []
        options['block_device_mappings'].split(',').each do |device_set|
          device,devparam = device_set.split('=')

          mapping = {}

          if devparam == 'none'
            mapping = { :no_device => device }
          else
            mapping = { :device_name => device }
            if devparam =~ /^ephemeral[0-3]/
              mapping[:virtual_name] = devparam
            else
              # we have a more complex 'ebs' parameter
              #'[<snapshot-id>][:<size>[:<delete-on-termination>][:<type>[:<iops>]]]'

              mapping[:ebs] = {}

              devparam = devparam.split ':'

              # a bit ugly but short and won't change
              # notice the to_i on volume_size parameter
              mapping[:ebs][:snapshot_id] = devparam[0] unless (devparam[0].nil? || devparam[0].empty?)
              mapping[:ebs][:volume_size] = devparam[1].to_i

              # defaults to true - except if we have the exact string "false"
              mapping[:ebs][:delete_on_termination] = (devparam[2] != "false")

              # optional. notice the to_i on iops parameter
              mapping[:ebs][:volume_type] = devparam[3] unless (devparam[3].nil? || devparam[3].empty?)
              mapping[:ebs][:iops] = devparam[4].to_i unless (devparam[4].nil? || devparam[4].empty?)

            end
          end

          block_device_mappings.push mapping
        end

        options['block_device_mappings'] = block_device_mappings
      end

      # convert security_groups from comma separated string to ruby array
      options['security_groups'] &&= options['security_groups'].split(',')
      options['security_group_ids'] &&= options['security_group_ids'].split(',')
      # convert ephemeral_devices from comma separated string to ruby array
      options['ephemeral_devices'] &&= options['ephemeral_devices'].split(',')
      # convert chef_cookbook_attributes from comma separated string to ruby array
      options['chef_cookbook_attributes'] &&= options['chef_cookbook_attributes'].split(',')

      # format the classic link options
      if options['classic_link_vpc_id']
        options['classic_link']['vpc_id'] = options['classic_link_vpc_id']
      end
      if options['classic_link_security_group_ids']
        options['classic_link']['security_group_ids'] = options['classic_link_security_group_ids'].split(',')
      end
      if options['classic_link_security_groups']
        options['classic_link']['security_groups'] = options['classic_link_security_groups'].split(',')
      end

      options
    end

  end
end
