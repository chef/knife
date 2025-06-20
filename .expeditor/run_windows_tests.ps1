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
gem sources --add $gem_source | Out-Null

# Download the Chef gem manually (incorrectly named on Artifactory)
Write-Host "--- Downloading Chef gem from Artifactory"
$downloaded_path = "$env:TEMP\chef-19.1.36-universal-unknown.gem"
Invoke-WebRequest -Uri "$gem_source/gems/chef-19.1.36-universal-unknown.gem" -OutFile $downloaded_path -UseBasicParsing

# Rename gem to correct name for its internal platform
Write-Host "--- Renaming gem file to match correct platform"
$corrected_path = "$env:TEMP\chef-19.1.36-universal-mingw-ucrt.gem"
Rename-Item -Path $downloaded_path -NewName (Split-Path $corrected_path -Leaf)

# Move the gem into vendor/cache for bundler to pick it up
Write-Host "--- Moving gem to vendor/cache"
$cache_path = "vendor/cache"
if (!(Test-Path $cache_path)) { New-Item -ItemType Directory -Path $cache_path | Out-Null }
$final_cached_path = "$cache_path\chef-19.1.36-universal-mingw-ucrt.gem"
Move-Item -Path $corrected_path -Destination $final_cached_path -Force

# Preinstall the Chef gem manually
Write-Host "--- Installing Chef gem manually"
gem install $final_cached_path

# Lock bundler to Windows platform and configure bundler settings
Write-Host "--- Configuring bundler for Windows platform"
bundle config set --local path vendor/bundle
bundle config set --local force_ruby_platform false
bundle lock --add-platform x64-mingw-ucrt

# Install dependencies from Gemfile using local cache
Write-Host "--- Installing gems from Gemfile"
bundle install --local --jobs=7 --retry=3
if ($LASTEXITCODE -ne 0) { throw "Bundle install failed with exit code $LASTEXITCODE" }

# Verify Chef gem was installed
Write-Host "--- Verifying Chef gem installation"
bundle exec ruby -e "puts Gem.loaded_specs['chef'].full_name"
if ($LASTEXITCODE -ne 0) { throw "Chef gem verification failed with exit code $LASTEXITCODE" }

# Run the actual test task
Write-Host "+++ Executing bundle exec task"
bundle exec @args
if ($LASTEXITCODE -ne 0) { throw "Command failed with exit code $LASTEXITCODE" }
