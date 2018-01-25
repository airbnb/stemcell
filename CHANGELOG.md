# 0.11.9
- Transform chef_cookbook_attributes option for command-line parser
- Set vpc_id when creating Launcher object

# 0.11.8
- Configure AWS earlier to work around aws-sdk-v1 vpc bug

# 0.11.7
- Convert security group names to ids when launching VPC instances
- Allow classic link to associate VPC security groups by name

# 0.11.6
- Result of role expansion needs to be a mutable object

# 0.11.5
- No changes

# 0.11.4
- Support for setting normal attributes in role expansio
- Support for loading cookbook attributes

# 0.11.3
- add legacy-mode flag to bootstrap.sh.erb when launching Chef 12.11 or newer

# 0.11.2
- fix undefined VERSION constant

# 0.11.1
- update bootstrap.sh to support launched_by file, site-cookbooks, ohai_plugins, and retries if the initial converge fails
- include version in version string

# 0.11.0
- allow user to specify `contexts` to override certain attributes

# 0.10.1
- check for nil classic link

# 0.10.0
- allow launching termination-protected instances
- enable classic link

# 0.9.1
- Don't require aws keys for Stemcell::Launcher to allow for launching via iam role

# 0.9.0
- ...

# 0.8.1
- Add retry mechanism for instances launch/termination
- Make `Launcher::launch!` transaction-like, which reclaims all partially launched instances in the event of non-intermittent error
- Display better error message with reason and failed instances
- Take converge lock during initial converge

# 0.8.0
- Support for VPC [Brenden](https://github.com/brndnmtthws)
- Support relative paths and home alias in `Launcher#try_file` [Patrick Viet](https://github.com/patrickviet)
- Add Ohai hint for EC2 [sandstrom](https://github.com/sandstrom)
- Less verbose download progress for chef [sandstrom](https://github.com/sandstrom)

# 0.7.1
- relax version constraint on Chef gem
