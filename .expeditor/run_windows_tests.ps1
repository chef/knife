$ErrorActionPreference = "Stop"

# Set environment variables
$env:USER = "root"
$env:LANG = "C.UTF-8"
$env:LANGUAGE = "C.UTF-8"
$env:RUBYOPT = "-W0"

Write-Host "--- Configuring Artifactory access"
$env:ARTIFACTORY_ENDPOINT = "https://artifactory-internal.ps.chef.co/artifactory"
$gem_source = "$env:ARTIFACTORY_ENDPOINT/api/gems/omnibus-gems-local"

# Add Artifactory gem source
Write-Host "--- Adding Artifactory gem source"
gem sources --add $gem_source

# Download Chef gem from Artifactory
Write-Host "--- Downloading Chef gem from Artifactory"
$wrong_name = "chef-19.1.36-universal-unknown.gem"
$correct_name = "chef-19.1.36-universal-mingw-ucrt.gem"
$downloaded_path = "$env:TEMP\$wrong_name"
Invoke-WebRequest -Uri "$gem_source/gems/$wrong_name" -OutFile $downloaded_path -UseBasicParsing

# Rename the gem file to match platform
Write-Host "--- Renaming gem file to match expected platform"
$corrected_path = "$env:TEMP\$correct_name"
Rename-Item -Path $downloaded_path -NewName $correct_name -Force

# Move to vendor/cache for Bundler
Write-Host "--- Moving gem to vendor/cache"
$cache_path = "vendor/cache"
if (!(Test-Path $cache_path)) { New-Item -ItemType Directory -Path $cache_path }
Move-Item -Path $corrected_path -Destination "$cache_path\$correct_name" -Force

Write-Host "--- Installing gems with Bundler"
gem specification vendor/cache/chef-19.1.36-universal-mingw-ucrt.gem platform

# Install all gems
Write-Host "--- Installing gems with Bundler"
bundle config set --local path vendor/bundle
bundle config set --local force_ruby_platform false
bundle install --local --jobs=7 --retry=3
if ($LASTEXITCODE -ne 0) { throw "Bundle install failed with exit code $LASTEXITCODE" }

# Confirm installation
Write-Host "--- Verifying Chef gem installation"
bundle exec gem list chef
if ($LASTEXITCODE -ne 0) { throw "Chef gem verification failed with exit code $LASTEXITCODE" }

# Run task
Write-Host "+++ Executing bundle exec task"
bundle exec @args
if ($LASTEXITCODE -ne 0) { throw "Command failed with exit code $LASTEXITCODE" }
