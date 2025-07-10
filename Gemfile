source "https://rubygems.org"

gem "knife", path: "."

# TODO: Once these gems are published to rubygems.org, we don't need to specify them in these conditions.
if RUBY_PLATFORM.match?(/mswin|mingw|windows/)
  # --- Windows: chef from vendor/cache, others from Artifactory ---

  # Force Bundler to resolve chef from vendor/cache by declaring it without a source block
  gem "chef", "19.1.36"

  # Other Chef gems from Artifactory
  source "https://artifactory-internal.ps.chef.co/artifactory/api/gems/omnibus-gems-local" do
    gem "chef-config", "19.1.36"
    gem "chef-utils", "19.1.36"
    gem "ohai", ">= 19.1"
  end

else
  # --- Linux/macOS: all Chef gems from Artifactory ---
  source "https://artifactory-internal.ps.chef.co/artifactory/api/gems/omnibus-gems-local" do
    gem "chef", ">= 19.1"
    gem "chef-config", ">= 19.1"
    gem "chef-utils", ">= 19.1"
    gem "ohai", ">= 19.1"
  end
end

# Runtime dependencies
gem "syslog"
gem "ostruct"
gem "csv"
gem "mixlib-authentication", "=3.0.10" #Pinning this to a specific version to avoid breaking changes

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