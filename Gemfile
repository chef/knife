source "https://rubygems.org"

gem "knife", path: "."

# GitHub source block for Windows only
if Gem.win_platform?
  gem "chef-utils", git: "https://github.com/chef/chef.git", branch: "main"
  gem "chef-config", git: "https://github.com/chef/chef.git", branch: "main"
  gem "ohai", git: "https://github.com/chef/ohai.git", branch: "main"
  gem "chef", git: "https://github.com/chef/chef.git", branch: "main"
else
  source "https://artifactory-internal.ps.chef.co/artifactory/api/gems/omnibus-gems-local" do
    gem "chef", ">= 19.1"
    gem "chef-config", ">= 19.1"
    gem "chef-utils", ">= 19.1"
    gem "ohai", ">= 19.1"
  end
end

# Platform specific gems
if RUBY_PLATFORM.match?(/mswin|mingw|windows/)
  gem "fiddle", "<= 1.1.6"
  gem "win32ole"
  gem "win32-process", "~> 0.9"
end

# Runtime dependencies
gem "syslog"
gem "ostruct"
gem "csv"

# Native extensions for Windows
gem "ffi", "1.17.2", platforms: [:mswin, :mingw]
gem "ffi-win32-extensions", "~> 1.0", platforms: [:mswin, :mingw]

# Development and test
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

# Style
group :chefstyle do
  gem "chefstyle"
end

# Interactive shell extras
group :omnibus_package, :pry do
  gem "pry"
  gem "pry-byebug"
  gem "pry-stack_explorer"
end