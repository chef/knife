$ErrorActionPreference="stop"
Write-Host "--- bundle install"
#ridk install 1 2 3
#ridk enable
Write-Host "--- cloning chef for  install"
#git clone https://github.com/chef/chef.git
#cd chef ; bundle install; cd chef-utils; gem build chef-utils.gemspec; gem install chef-utils-*.gem ; cd .. ;
#cd chef-config; gem build chef-config.gemspec; gem install chef-config-*.gem ; cd ..;
#gem build chef-universal-mingw-ucrt.gemspec; gem install chef-*.gem ; cd ..;
bundle config --local path vendor/bundle
gem install win32ole
gem install ffi-libarchive
bundle install --jobs=7 --retry=3
Write-Host "--- bundle  install done"

Write-Host "+++ bundle exec task"



bundle exec $args
if ($LASTEXITCODE -ne 0) { throw "$args failed" }
