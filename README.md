# Stemcell

Stemcell launches instances

## Installation

Add this line to your application's Gemfile:

    gem 'stemcell'

And then execute:

    $ bundle

Or install it yourself as:
   $ gem install stemcell.gemspec

## Configuration

You will need to edit .stemcellrc and add the specified params. You
can get most of the options from your .chef/knife.rb but you will need
to get the new chef deploy key so that instances that you launch can
download code.

## Usage

### Include your base config:

    $ source .stemcellrc

### Simple launch:

    $ ./bin/stemcell --chef-role $your_chef_role --git-branch $your_chef_branch

This will cause instance(s) to be launched and their ip's and instance
id to be printed to the screen.

### More options:

    $ ./bin/stemcell --help

### Watching install:

    $ ssh unbutu@$IP 'tail -f /var/log/init*'


### Terminating:

This still needs to be completed. For now, you can kill using the
amazon cli tools or the web ui.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
