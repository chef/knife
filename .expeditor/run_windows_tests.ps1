$ErrorActionPreference = "Stop"

Write-Host "--- Configuring Artifactory access"
$env:ARTIFACTORY_ENDPOINT = "https://artifactory-internal.ps.chef.co/artifactory"
$env:ARTIFACTORY_USERNAME = "REDACTED@chef.io"
$gem_source = "$env:ARTIFACTORY_ENDPOINT/api/gems/omnibus-gems-local"

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
Move-Item -Path $corrected_path -Destination "$cache_path\chef-19.1.36-universal-mingw-ucrt.gem" -Force

# Configure bundler for Windows platform and vendor path
Write-Host "--- Configuring bundler for Windows platform"
bundle config set --local path vendor/bundle
bundle config set --local force_ruby_platform false
bundle config set --local no_prune true
bundle lock --add-platform x64-mingw-ucrt

# Install dependencies from Gemfile
Write-Host "--- Installing gems from Gemfile"
bundle install --jobs=7 --retry=3
if ($LASTEXITCODE -ne 0) { throw "❌ Bundle install failed with exit code $LASTEXITCODE" }

# Verify that chef gem is actually installed
Write-Host "--- Verifying chef gem installation"
$chef_info = bundle info chef 2>&1
if ($chef_info -match "chef \(19.1.36\)") {
    Write-Host "✅ Chef gem installed successfully via Bundler"
} else {
    throw "❌ Chef gem not found via Bundler"
}

Write-Host "+++ Executing bundle exec task"
bundle exec rspec --format documentation --backtrace --color


# Run the actual test task
Write-Host "+++ Executing bundle exec task"
bundle exec @args
if ($LASTEXITCODE -ne 0) { throw "❌ Command failed with exit code $LASTEXITCODE" }
