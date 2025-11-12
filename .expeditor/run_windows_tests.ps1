$ErrorActionPreference = "Stop"

# TODO: Remove the download, rename, and move steps for the Chef gem to vendor/cache once the correct name is available in Artifactory or the gem gets published to the rubygems.org
# This workaround is necessary because the Chef gem for Windows is currently published to the artifactory with an incorrect name.
Write-Host "--- Configuring Artifactory access"
$env:ARTIFACTORY_ENDPOINT = "https://artifactory-internal.ps.chef.co/artifactory"
$env:ARTIFACTORY_USERNAME = "REDACTED@chef.io"
$gem_source = "$env:ARTIFACTORY_ENDPOINT/api/gems/omnibus-gems-local"

Write-Host "--- Downloading Chef gem from Artifactory"
$downloaded_path = "$env:TEMP\chef-19.1.97-universal-unknown.gem"
Invoke-WebRequest -Uri "$gem_source/gems/chef-19.1.97-universal-unknown.gem" -OutFile $downloaded_path -UseBasicParsing

Write-Host "--- Renaming gem file to match correct platform"
$corrected_path = "$env:TEMP\chef-19.1.97-universal-mingw-ucrt.gem"
Rename-Item -Path $downloaded_path -NewName (Split-Path $corrected_path -Leaf)

Write-Host "--- Moving gem to vendor/cache"
$cache_path = "vendor/cache"
if (!(Test-Path $cache_path)) { New-Item -ItemType Directory -Path $cache_path | Out-Null }
Move-Item -Path $corrected_path -Destination "$cache_path/chef-19.1.97-universal-mingw-ucrt.gem" -Force

Write-Host "--- Configuring bundler for Windows platform"
bundle config set --local path vendor/bundle
bundle config set --local force_ruby_platform false
bundle config set --local no_prune true
bundle lock --add-platform x64-mingw-ucrt

Write-Host "--- Installing gems from Gemfile"
bundle install --jobs=7 --retry=3
if ($LASTEXITCODE -ne 0) { throw "Bundle install failed with exit code $LASTEXITCODE" }

Write-Host "+++ Executing bundle exec task"
bundle exec $args
if ($LASTEXITCODE -ne 0) { throw "Command failed with exit code $LASTEXITCODE" }
