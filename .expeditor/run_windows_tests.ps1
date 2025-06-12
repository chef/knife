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

# ===== CRITICAL CHANGES START HERE =====
# 1. First manually install the problematic gem
Write-Host "--- Manually installing chef gem"
gem install chef -v '19.1.36-universal-unknown' --source "https://artifactory-internal.ps.chef.co/artifactory/api/gems/omnibus-gems-local" --force

# 2. Configure Bundler to handle the version correctly
bundle config set force_ruby_platform true

# 3. Use dots instead of hyphens in Gemfile reference
# (You'll need to modify your Gemfile to use:)
# gem "chef", "19.1.36.universal.unknown" 
# ===== CRITICAL CHANGES END HERE =====

Write-Host "--- bundle install"
bundle config --local path vendor/bundle
bundle install --verbose --jobs=7 --retry=3 --local  # Added --local flag
gem update --system
Write-Host "--- bundle install done"

Write-Host "+++ bundle exec task"
$env:RUBYOPT = "-W0"
bundle exec @args
if ($LASTEXITCODE -ne 0) { throw "Command failed with exit code $LASTEXITCODE" }