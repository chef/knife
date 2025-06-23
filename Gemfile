source "https://rubygems.org"

gem "knife", path: "."

# ✅ Declare chef first — without a remote source block
# This forces Bundler to resolve it from vendor/cache when available
gem "chef", "19.1.36", path: "vendor/cache/chef-19.1.36-universal-mingw-ucrt"

# ✅ Other Chef gems still pulled from Artifactory
source "https://artifactory-internal.ps.chef.co/artifactory/api/gems/omnibus-gems-local" do
  gem "chef-config", "19.1.36"
  gem "chef-utils", "19.1.36"
  gem "ohai", ">= 19.1"
end

# Platform-specific gems
if RUBY_PLATFORM.match?(/mswin|mingw|windows/)
  # gem "fiddle", "<= 1.1.6"
  gem "win32ole"
  gem "win32-process", "~> 0.9"
end

# Runtime dependencies
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

#, "~> 1.0", platforms: [:mswin, :mingw, :x64_mingw, :universal_mingw]

group :omnibus_package, :pry do
  gem "pry"
  gem "pry-byebug"
  gem "pry-stack_explorer"
end

group :chefstyle do
  gem "chefstyle"
end
