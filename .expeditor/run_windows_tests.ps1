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

# Add Artifactory source
Write-Host "--- Adding Artifactory gem source"
gem sources --add $gem_source

# Always download Chef gem from Artifactory
Write-Host "--- Downloading Chef gem from Artifactory"
$gem_url = "$env:ARTIFACTORY_ENDPOINT/api/gems/omnibus-gems-local/gems/chef-19.1.36-universal-unknown.gem"
$downloaded_path = "$env:TEMP\chef-19.1.36-universal-unknown.gem"
Invoke-WebRequest -Uri $gem_url -OutFile $downloaded_path -UseBasicParsing

# Rename the gem file to match the expected platform name
Write-Host "--- Renaming gem file to match expected platform name"
$corrected_path = "$env:TEMP\chef-19.1.36-universal-mingw-ucrt.gem"
Rename-Item -Path $downloaded_path -NewName $corrected_path

# Move the gem to vendor/cache for Bundler to recognize
Write-Host "--- Moving gem to vendor/cache"
$cache_path = "vendor/cache"
if (!(Test-Path $cache_path)) { New-Item -ItemType Directory -Path $cache_path }
$destination_path = "$cache_path\chef-19.1.36-universal-mingw-ucrt.gem"
if (Test-Path $destination_path) {
    Write-Host "--- File already exists in vendor/cache, overwriting"
    Remove-Item -Path $destination_path -Force
}
Move-Item -Path $corrected_path -Destination $destination_path

# Install gems from Gemfile using Bundler
Write-Host "--- Installing gems from Gemfile using Bundler"
bundle config set --local path vendor/bundle
bundle install --gemfile Gemfile --jobs=7 --retry=3
if ($LASTEXITCODE -ne 0) { throw "Bundle install failed with exit code $LASTEXITCODE" }

# Verify Chef gem installation
Write-Host "--- Verifying Chef gem installation"
bundle exec gem list chef
if ($LASTEXITCODE -ne 0) { throw "Chef gem verification failed with exit code $LASTEXITCODE" }

# Run the actual task
Write-Host "+++ Executing bundle exec task"
bundle exec @args
if ($LASTEXITCODE -ne 0) { throw "Command failed with exit code $LASTEXITCODE" }
