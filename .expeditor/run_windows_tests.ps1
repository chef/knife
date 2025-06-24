$ErrorActionPreference = "Stop"

Write-Host "--- gem source before add"
gem source

$env:USER = "root"
$env:LANG = "C.UTF-8"
$env:LANGUAGE = "C.UTF-8"

Write-Host "---- getting chef gem"
$env:ARTIFACTORY_ENDPOINT = "https://artifactory-internal.ps.chef.co/artifactory"
$env:ARTIFACTORY_USERNAME = "REDACTED@chef.io"

Write-Host "--- gem source before add"
gem source | ForEach-Object { $_ -replace ':$','' }
Write-Host "--- gem source after add"
gem source -a "https://artifactory-internal.ps.chef.co/artifactory/api/gems/omnibus-gems-local"
Write-Host "---- getting chef gem done"

Write-Host "--- bundle install"
bundle config --local path vendor/bundle
bundle install --jobs=7 --retry=3
gem update --system
Write-Host "--- bundle install done"

Write-Host "+++ bundle exec task"
$env:RUBYOPT = "-W0"
bundle exec @args
if ($LASTEXITCODE -ne 0) { throw "Command failed with exit code $LASTEXITCODE" }