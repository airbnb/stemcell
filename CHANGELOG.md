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
