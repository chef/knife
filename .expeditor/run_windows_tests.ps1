$ErrorActionPreference="stop"
Write-Host "---- getting chef gem"

$env:ARTIFACTORY_ENDPOINT="artifactory-internal.ps.chef.co/artifactory"
$env:ARTIFACTORY_USERNAME="REDACTED@chef.io"
#$lita_password=aws ssm get-parameter --name "artifactory-lita-password" --with-decryption --query Parameter.Value --output text --region us-west-2
#$env:ARTIFACTORY_PASSWORD="$(vault read -field password account/static/artifactory/buildkite)"
# git clone https://github.com/chef/chef.git
# cd chef ; bundle install; cd chef-utils; gem build chef-utils.gemspec; gem install chef-utils-*.gem ; cd .. ;
# cd chef-config; gem build chef-config.gemspec; gem install chef-config-*.gem ; cd ..;
# gem build chef-universal-mingw-ucrt.gemspec; gem install chef-*.gem ; cd ..;
bundle config --local path vendor/bundle
gem install win32ole
gem install ffi-libarchive
git clone https://github.com/chef/chef
git checkout main
bundle install --jobs=7 --retry=3
bundle install --deployment
bundle config unset deployment
Write-Host "--- bundle  install done"
Write-Host "---- getting chef gem done"

Write-Host "+++ bundle exec task"

$env:RUBYOPT="-W0"; bundle exec $args
if ($LASTEXITCODE -ne 0) { throw "$args failed" }
