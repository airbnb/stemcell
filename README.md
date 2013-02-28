# Stemcell

Stemcell launches instances

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
$ ssh unbutu@$IP 'tail -f /var/log/init*'
```

### Terminating:

This still needs to be completed. For now, you can kill using the
amazon cli tools or the web ui.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
 