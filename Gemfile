source "https://rubygems.org"

gem "knife", path: "."
gem "syslog"
gem "ostruct"
gem "csv"

group(:development, :test) do
  gem "cheffish", ">= 14" # testing only , but why didn't this need to explicit in chef?
  gem "webmock"
  gem "crack", "< 0.4.6" # due to https://github.com/jnunemaker/crack/pull/75
  gem "rake", ">= 12.3.3"
  gem "rspec"
  gem "abbrev"
  gem "benchmark"
  gem "reline"
end

group(:omnibus_package, :pry) do
  gem "pry"
  gem "pry-byebug"
  gem "pry-stack_explorer"
end

group(:chefstyle) do
  gem "chefstyle", git: "https://github.com/chef/chefstyle.git", branch: "main"
end

gem "ohai", git: "https://github.com/chef/ohai.git", branch: "main"
gem "chef", git: "https://github.com/chef/chef.git", branch: "main"
gem "chef-config", git: "https://github.com/chef/chef", branch: "main", glob: "chef-config/chef-config.gemspec"
gem "chef-utils", git: "https://github.com/chef/chef", branch: "main", glob: "chef-utils/chef-utils.gemspec"
# gem "chef", path: "../chef"
# gem "chef-utils",
# gem "chef-config", path: File.expand_path("../chef/chef-config", __dir__) if File.exist?(File.expand_path("../chef/chef-config", __dir__))

platforms :mswin, :mingw, :x64_mingw do
  gem "fiddle" "<= 1.1.6"
  gem "win32ole"
end