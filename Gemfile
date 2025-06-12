source "https://rubygems.org"

gem "knife", path: "."

# Chef core dependencies, locked to a compatible version range
source "https://artifactory-internal.ps.chef.co/artifactory/api/gems/omnibus-gems-local" do
  if Gem.win_platform?
    gem "chef", "'19.1.36-universal-unknown'"
  else
    gem "chef", ">= 19.1"
  end
  gem "chef-config", ">= 19.1"
  gem "chef-utils", ">= 19.1"
  gem "ohai", ">= 19.1"
end

# Platform specific gems
if RUBY_PLATFORM.match?(/mswin|mingw|windows/)
  gem "fiddle", "<= 1.1.6"
  gem "win32ole"
  gem "win32-process", "~> 0.9"
end

# Runtime gems knife might need
gem "syslog"
gem "ostruct"
gem "csv"

group :development, :test do
  gem "cheffish", ">= 14"
  gem "webmock"
  gem "crack", "< 0.4.6"
  gem "rake", ">= 12.3.3"
  gem "rspec"
  gem "abbrev"
  gem "benchmark"
  gem "reline"
end

group :omnibus_package, :pry do
  gem "pry"
  gem "pry-byebug"
  gem "pry-stack_explorer"
end

group :chefstyle do
  gem "chefstyle"
end
