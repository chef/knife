source "https://rubygems.org"

gem "knife", path: "."

gem "chef", ">= 19.1"
gem "chef-config", ">= 19.1"
gem "chef-utils", ">= 19.1"
gem "ohai", ">= 19.1"

# Windows-specific gems
if RUBY_PLATFORM.match?(/mswin|mingw|windows/)
  gem "appbundler"
end

# Only include these gems when Ruby version is 3.4.x
if RUBY_VERSION.start_with?("3.4") && RUBY_PLATFORM.match?(/mswin|mingw|windows/)
  gem "win32ole"
  gem "win32-process", "~> 0.9"
end

# Runtime dependencies
gem "syslog"
gem "ostruct"
gem "csv"
gem "libyajl2", ">= 2.1" # Explicitly require newer version from rubygems.org
gem "faraday", ">= 2.14.3" # Code scan remediation; transitive dep via chef-licensing/inspec-core
gem "mixlib-authentication", "=3.0.10" #Pinning this to a specific version to avoid breaking changes

group :development, :test do
  gem "cheffish", ">= 14"
  gem "webmock"
  gem "crack", "< 1.0.2"
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

group :habitat do
  gem "knife-ec2", "~> 2.2.0"
  gem "knife-google", "~> 5.0.15"
  gem "knife-windows", "~> 5.0.7"
  gem "knife-vcenter", "~>5.0", ">= 5.1.1"
end
