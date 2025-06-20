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

# 1. Download chef gem with corrected platform tag
Write-Host "--- Downloading chef gem with incorrect platform name"
$gem_url = "$gem_source/gems/chef-19.1.36-universal-unknown.gem"
$downloaded_path = "$env:TEMP\chef-19.1.36-universal-unknown.gem"

Invoke-WebRequest -Uri $gem_url -OutFile $downloaded_path -UseBasicParsing

# Verify the file was downloaded
if (Test-Path $downloaded_path) {
    Write-Host "✅ Chef gem downloaded successfully to $downloaded_path"
    Write-Host "`n--- Listing .gem files in TEMP directory ---"
    Get-ChildItem "$env:TEMP\*.gem" | Format-Table Name, Length, LastWriteTime
} else {
    Write-Host "❌ Chef gem download failed."
    exit 1
}

# 2. Configure Bundler
Write-Host "--- Configuring Bundler"
bundle config --local path vendor/bundle

# 3. Run bundle install with local gems
Write-Host "--- Running bundle install"
bundle install --jobs=7 --retry=3 --local
if ($LASTEXITCODE -ne 0) { throw "Bundle install failed with exit code $LASTEXITCODE" }

# Install gems from Gemfile
Write-Host "--- Installing gems from Gemfile"
bundle install --gemfile Gemfile --jobs=7 --retry=3
if ($LASTEXITCODE -ne 0) { throw "Bundle install failed with exit code $LASTEXITCODE" }

# Verify Chef gem installation
Write-Host "--- Verifying Chef gem installation"
bundle exec gem list chef
if ($LASTEXITCODE -ne 0) { throw "Chef gem verification failed with exit code $LASTEXITCODE" }

# 4. Run the actual task
Write-Host "+++ Executing bundle exec task"
bundle exec @args
if ($LASTEXITCODE -ne 0) { throw "Command failed with exit code $LASTEXITCODE" }
