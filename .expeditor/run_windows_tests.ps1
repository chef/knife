$ErrorActionPreference="stop"


$env:ARTIFACTORY_ENDPOINT="artifactory-internal.ps.chef.co/artifactory"
$env:ARTIFACTORY_USERNAME="REDACTED@chef.io"
#$lita_password=aws ssm get-parameter --name "artifactory-lita-password" --with-decryption --query Parameter.Value --output text --region us-west-2
#$env:ARTIFACTORY_PASSWORD="$(vault read -field password account/static/artifactory/buildkite)"
# git clone https://github.com/chef/chef.git
# cd chef ; bundle install; cd chef-utils; gem build chef-utils.gemspec; gem install chef-utils-*.gem ; cd .. ;
# cd chef-config; gem build chef-config.gemspec; gem install chef-config-*.gem ; cd ..;
# gem build chef-universal-mingw-ucrt.gemspec; gem install chef-*.gem ; cd ..;
Write-Host "--- bundle install"

# Set bundler config
bundle config --local path vendor/bundle
bundle config set --local without 'docs development profile'
bundle config set --local disable_checksum_validation true

# Install gems
bundle install --jobs=7 --retry=3 --verbose
if ($LASTEXITCODE -ne 0) { throw "bundle install failed" }
Write-Host "--- Ruby Platform Check"
ruby -e "puts 'RUBY_PLATFORM: ' + RUBY_PLATFORM"

Write-Host "+++ bundle exec task"

# Debug: Show Ruby and Bundler versions
ruby -v
bundle -v

# Debug: Show environment variables
Write-Host "Environment Variables:"
Get-ChildItem Env:
# Debug: Show installed gems
bundle list
# Run the task with better argument handling
& bundle exec @args
if ($LASTEXITCODE -ne 0) { throw "bundle exec $args failed" }