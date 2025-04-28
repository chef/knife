$ErrorActionPreference="stop"
Write-Host "--- bundle install"
bundle config --local path vendor/bundle
gem install win32ole
gem install ffi-libarchive
gem install chef-powershell

bundle install --jobs=7 --retry=3
Write-Host "--- bundle  install done"

Write-Host "--- Verifying knife"
bundle exec knife --version

Write-Host "+++ bundle exec task"
bundle exec rake spec

if ($LASTEXITCODE -ne 0) { throw "$args failed" }
