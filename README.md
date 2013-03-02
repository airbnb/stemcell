# Stemcell #

Stemcell launches instances in EC2.
These instances are created to your specification, with knobs like AMI, instance type, and region exposed.
The instances are bootstrapped with chef-solo, using a specified git repo and branch as the source of roles and recipes.

## Installation

Add this line to your application's Gemfile:

```bash
gem 'stemcell'
```

And then execute:

```bash
$ bundle
```

Or install it yourself as:

```bash
$ gem install stemcell
```

## Configuration

You should create an rc file for stemcell with your standard options
(and place it in the root dir as .stemcellrc?). You can see an example
in examples/stemcellrc. You can get most of the options from your
.chef/knife.rb but you will need to get the new chef deploy key so
that instances that you launch can download code.

## Usage

### Include your base config:

```bash
$ source .stemcellrc
```

### Simple launch:

```bash
$ ./bin/stemcell --chef-role $your_chef_role --git-branch $your_chef_branch
```

This will cause instance(s) to be launched and their ip's and instance
id to be printed to the screen.

### More options:

```bash
$ ./bin/stemcell --help
```

### Watching install:

```bash
$ ssh ubuntu@$IP 'tail -f /var/log/init*'
```

### Terminating:

To terminate, use the necrosis command and pass a space seperated list of instance ids:

```bash
$ necrosis i-12345678 i-12345679 i-12345670
```

## Automation ##

This README presents `stemcell` as a tool for administrators to use to create instances.
However, we designed `stemcell` to be easily useful for automated systems which control server infrastructure.
These automated systems can call out to `stemcell` on the command-line or use the ruby classes directly.

To see how we manage our cloud, check out the rest of SmartStack, especially Cortex, our auto-scaling system.

## Similar Tools ##

There are a few additional tools which bootstrap EC2 instances with chef-solo.
If you're using chef-server, obvious answer is [knife-ec2](https://github.com/opscode/knife-ec2).
Unless you're working on a big team where lots of people edit cookbooks simultaneously, we strongly recommend this approach!
It's especially excellent when paired with [hosted chef](http://www.opscode.com/hosted-chef/), which makes getting off the ground with configuration management fast and easy.

If you want to use knife-ec2 with chef-solo, you could use [knife solo](http://matschaffer.github.com/knife-solo/).
Another approach which is great for interactive usage involves [using fabric to bootstrap chef](http://unfoldthat.com/2012/06/02/quick-deploy-chef-solo-fabric.html)([with gist](https://gist.github.com/va1en0k/2859812)).

Finally, we couldn't resist doing a bit of code archeology.
People have been using chef with EC2 for a long time!
One early article is [this one](http://web.archive.org/web/20110404114025/http://probablyinteractive.com/2009/3/29/Amazon%20EC2%20+%20Chef%20=%20Mmmmm.html), which isn't even on the web anymore.
However, it's spawned some recently-active tools like [this](https://github.com/conormullen/chef-bootstrap) and [this](https://github.com/grempe/chef-solo-bootstrap).
Similar approaches are mentioned [here](http://www.opinionatedprogrammer.com/2011/06/chef-solo-tutorial-managing-a-single-server-with-chef/), with code [herh](https://github.com/ciastek/ubuntu-chef-solo) or [here](https://github.com/riywo/ubuntu-chef-solo) (with accompanying [blog post](http://weblog.riywo.com/post/35976125760))
[This article](http://illuminatedcomputing.com/posts/2012/02/simple-chef-solo-tutorial/), also mentions many worthwhile predecessors.
