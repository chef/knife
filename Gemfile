source "https://rubygems.org"

gem "knife", path: "."
gem "syslog"
gem "ostruct"
gem "csv"

group(:development, :test) do
  gem "cheffish",">= 14" # testing only , but why didn't this need to explicit in chef?
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
  gem "chefstyle"
end

#gem "chef", git: "https://github.com/chef/chef.git", branch: "main"
# gem "chef-config", git: "https://github.com/chef/chef", branch: "main", glob: "chef-config/chef-config.gemspec"
# gem "chef-utils", git: "https://github.com/chef/chef", branch: "main", glob: "chef-utils/chef-utils.gemspec"
gem "chef", git: "https://github.com/chef/chef.git", ref: "292591c273b561e70d91785f0187e5a4ab33aa74"
source "https://artifactory-internal.ps.chef.co/artifactory/api/gems/omnibus-gems-local" do
  gem "chef-config", "= 19.1.33"
  gem "chef-utils", "= 19.1.33"
  #gem "chef", ">=19.1"
  gem "ohai", "= 19.1.3"
end
# gem "chef", path: "../chef"
# gem "chef-utils",
# gem "chef-config", path: File.expand_path("../chef/chef-config", __dir__) if File.exist?(File.expand_path("../chef/chef-config", __dir__))

platforms :mswin, :mingw, :x64_mingw do
  gem "fiddle", "<= 1.1.6"
  gem "win32ole"
end