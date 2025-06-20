$ErrorActionPreference = "Stop"

# Set environment variables
$env:USER = "root"
$env:LANG = "C.UTF-8"
$env:LANGUAGE = "C.UTF-8"
$env:RUBYOPT = "-W0"

Write-Host "--- Configuring Artifactory access"
$env:ARTIFACTORY_ENDPOINT = "https://artifactory-internal.ps.chef.co/artifactory"
$env:ARTIFACTORY_USERNAME = "REDACTED@chef.io"
$gem_source = "$env:ARTIFACTORY_ENDPOINT/api/gems/omnibus-gems-local"

# Add Artifactory gem source
Write-Host "--- Adding Artifactory gem source"
gem sources --add $gem_source

# Download the Chef gem manually (incorrectly named on Artifactory)
Write-Host "--- Downloading Chef gem from Artifactory"
$downloaded_path = "$env:TEMP\chef-19.1.36-universal-unknown.gem"
Invoke-WebRequest -Uri "$gem_source/gems/chef-19.1.36-universal-unknown.gem" -OutFile $downloaded_path -UseBasicParsing

# Rename gem to correct name for its internal platform
Write-Host "--- Renaming gem file to match platform"
$corrected_path = "$env:TEMP\chef-19.1.36-universal-mingw-ucrt.gem"
Rename-Item -Path $downloaded_path -NewName (Split-Path $corrected_path -Leaf)

# Move the gem into vendor/cache for bundler to find
Write-Host "--- Moving gem to vendor/cache"
$cache_path = "vendor/cache"
if (!(Test-Path $cache_path)) { New-Item -ItemType Directory -Path $cache_path }
Move-Item -Path $corrected_path -Destination "$cache_path\chef-19.1.36-universal-mingw-ucrt.gem" -Force

# Preinstall the Chef gem manually to avoid bundler platform resolution issues
Write-Host "--- Installing Chef gem manually"
gem install "$cache_path\chef-19.1.36-universal-mingw-ucrt.gem"

# Lock bundler platform and configure local path
Write-Host "--- Configuring bundler for Windows platform"
bundle config set --local path vendor/bundle
bundle config set --local force_ruby_platform false
bundle lock --add-platform x64-mingw-ucrt

# Install all gems from Gemfile
Write-Host "--- Installing gems from Gemfile"
bundle install --local --jobs=7 --retry=3
if ($LASTEXITCODE -ne 0) { throw "Bundle install failed with exit code $LASTEXITCODE" }

# Verify Chef gem installation
Write-Host "--- Verifying Chef gem installation"
bundle exec gem list chef
if ($LASTEXITCODE -ne 0) { throw "Chef gem verification failed with exit code $LASTEXITCODE" }

# Run bundle exec task
Write-Host "+++ Executing
