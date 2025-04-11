$ErrorActionPreference="stop"
Add-WindowsCapability -Online -Name OpenSSH.Client
Write-Host "--- bundle install"
bundle config build.chef --without-win32-event-log
bundle config --local path vendor/bundle
git clone https://github.com/chef/chef.git
cd chef ; bundle install; rake install ; cd ..
bundle config set --local without docs development profile
bundle install --jobs=7 --retry=3


Write-Host "+++ bundle exec task"



bundle exec $args
if ($LASTEXITCODE -ne 0) { throw "$args failed" }
