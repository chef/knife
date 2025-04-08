# knife-standalone-engineeringexcellence
Repository with copy of knife folder from chef/chef for testing builds, test, and pipelines if it were to be broken out of the chef client repository.  To be renamed when effort is completed.

# NEED a new readme for knife standalone

TODO: generate first build - remove require relative references, gemfile changes for dep on chef/chef parent, gemspec
`rake build` seems to work until we dynaically reference these other components 

`rake install`
knife 19.0.68 built to pkg/knife-19.0.68.gem.
knife 19.0.68 built to pkg/knife-19.0.68.gem.
rake aborted!
knife 19.0.68 built to pkg/knife-19.0.68.gem.
knife 19.0.68 built to pkg/knife-19.0.68.gem.
rake aborted!
rake aborted!

Running `gem install C:/Users/loomis/Documents/GitHub/knife-prototype/knife/pkg/knife-19.0.68.gem` failed with the following output:

ERROR:  Could not find a valid gem 'chef' (>= 19) (required by 'C:/Users/loomis/Documents/GitHub/knife-prototype/knife/pkg/knife-19.0.68.gem' (>= 0)) in any repository
ERROR:  Possible alternatives: chef

C:/Users/loomis/.local/share/gem/ruby/3.2.0/gems/rake-13.2.1/exe/rake:27:in `<top (required)>'
Tasks: TOP => install
(See full trace by running task with --trace)

TODO: set up "real" repository in chef GH org with first build
TODO: check the .gitignore
TODO: set up build pipelines for gem and into Habitat buuilder to https://bldr.habitat.sh/#/pkgs/chef/knife/latest

TODO: relationship to https://github.com/chef/knife-ec-backup ?
TODO: establish channel strategy - is this LTS?