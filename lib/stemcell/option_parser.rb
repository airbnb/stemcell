require 'trollop'

module Stemcell
  class OptionParser
    attr_reader :options

    attr_reader :defaults
    attr_reader :version
    attr_reader :banner

    def initialize(config={})
      @defaults = config[:defaults] || {}
      @version = config[:version]
      @banner = config[:banner]
    end

    def parse!
      # The block passed to Trollop#options is evaluated in the binding of the
      # trollop parser itself, it doesn't have access to the this instance.
      # So use a value that can be captured instead!
      _this = self

      @options = Trollop::options do
        version _this.version if _this.version
        banner  _this.banner  if _this.banner

        opt('aws_access_key',
            "aws access key",
            :type => String,
            :default => ENV['AWS_ACCESS_KEY']
            )

        opt('aws_secret_key',
            "aws secret key",
            :type => String,
            :default => ENV['AWS_SECRET_KEY']
            )

        opt('region',
            'ec2 region to launch in',
            :type => String,
            :default => ENV['REGION'] || _this.defaults['region']
            )

        opt('instance_type',
            'machine type to launch',
            :type => String,
            :default => ENV['INSTANCE_TYPE'] || _this.defaults['instance_type']
            )

        opt('image_id',
            'ami to use for launch',
            :type => String,
            :default => ENV['IMAGE_ID'] || _this.defaults['image_id']
            )

        opt('security_groups',
            'comma-separated list of security groups to launch instance with',
            :type => String,
            :default => ENV['SECURITY_GROUPS'] || _this.defaults['security_groups']
            )

        opt('availability_zone',
            'zone in which to launch instances',
            :type => String,
            :default => ENV['AVAILABILITY_ZONE']
            )

        opt('tags',
            'comma-separated list of key=value pairs to apply',
            :type => String,
            :default => ENV['TAGS']
            )

        opt('key_name',
            'aws ssh key name for the ubuntu user',
            :type => String,
            :default => ENV['KEY_NAME']
            )

        opt('iam_role',
            'IAM role to associate with the instance',
            :type => String,
            :default => ENV['IAM_ROLE']
            )

        opt('placement_group',
            'Placement group to associate with the instance',
            :type => String,
            :default => ENV['PLACEMENT_GROUP']
            )

        opt('ebs_optimized',
            'launch an EBS-Optimized instance',
            :type => :flag
            )

        opt('ephemeral_devices',
            'comma-separated list of block devices to map ephemeral devices to',
            :type => String,
            :default => ENV['EPHEMERAL_DEVICES']
            )

        opt('chef_data_bag_secret',
            'path to secret file (or the string containing the secret)',
            :type => String,
            :default => ENV['CHEF_DATA_BAG_SECRET']
            )

        opt('chef_role',
            'chef role of instance to be launched',
            :type => String,
            :default => ENV['CHEF_ROLE']
            )

        opt('chef_environment',
            'chef environment in which this instance will run',
            :type => String,
            :default => ENV['CHEF_ENVIRONMENT']
            )

        opt('git_origin',
            'git origin to use',
            :type => String,
            :default => ENV['GIT_ORIGIN']
            )

        opt('git_branch',
            'git branch to run off',
            :type => String,
            :default => ENV['GIT_BRANCH'] || _this.defaults['git_branch']
            )

        opt('git_key',
            'path to the git repo deploy key (or the string containing the key)',
            :type => String,
            :default => ENV['GIT_KEY']
            )

        opt('count',
            'number of instances to launch',
            :type => Integer,
            :default => ENV['COUNT'] || _this.defaults[:count]
            )
      end

      # convert tags from string to ruby hash
      tags = {}
      if options['tags']
        options['tags'].split(',').each do |tag_set|
          key, value = tag_set.split('=')
          tags[key] = value
        end
      end
      options['tags'] = tags

      # convert security_groups from comma seperated string to ruby array
      options['security_groups'] &&= options['security_groups'].split(',')

      # convert ephemeral_devices from comma separated string to ruby array
      options['ephemeral_devices'] &&= options['ephemeral_devices'].split(',')

      options
    end

  end
end