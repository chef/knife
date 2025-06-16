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

# 1. Install MSYS2 and MINGW development tools (required for native extensions)
# Write-Host "--- Setting up build tools"
# ridk enable
# ridk install 3  # Installs MSYS2 and MINGW (only needed once per system)

# 2. Install chef dependencies (build from source)
Write-Host "--- Installing chef-utils, chef-config, and ohai"
gem install chef-utils   --version "19.1.36" --source $gem_source
gem install chef-config  --version "19.1.36" --source $gem_source
gem install ohai --source $gem_source

Write-Host "--- Installing win32-eventlog from rubygems"
gem install win32-eventlog --source "https://rubygems.org"

Write-Host "--- Installing native ffi gem for Windows"
# gem install ffi --platform=x64-mingw-ucrt --source "https://rubygems.org"
gem install ffi --platform=x64-mingw32 --source "https://rubygems.org"

# 3. Download and install chef gem with corrected platform tag
Write-Host "--- Downloading chef gem with incorrect platform name"
$gem_url = "$gem_source/gems/chef-19.1.36-universal-unknown.gem"
$downloaded_path = "$env:TEMP\chef-19.1.36-universal-unknown.gem"

Invoke-WebRequest -Uri $gem_url -OutFile $downloaded_path -UseBasicParsing

# Verify the file was downloaded
if (Test-Path $downloaded_path) {
    Write-Host "✅ Chef gem downloaded successfully to $downloaded_path"
} else {
    Write-Host "❌ Chef gem download failed."
    exit 1
}
# $renamed_path    = "$env:TEMP\chef-19.1.36-universal-mingw-ucrt.gem"

# Invoke-WebRequest -Uri $gem_url -OutFile $downloaded_path

# Write-Host "--- Renaming to correct platform name"
# Rename-Item -Path $downloaded_path -NewName (Split-Path $renamed_path -Leaf)

# 4. Install the gem
Write-Host "--- Installing chef gem"
gem install --local $downloaded_path --force --ignore-dependencies

# Verify installation
$installed = gem list chef --local

if ($installed) {
    Write-Host "✅ Chef gem installed successfully"
} else {
    Write-Host "❌ Chef gem installation failed"
    exit 1
}

# Ensure ffi gem is installed with the correct platform and version
Write-Host "--- Reinstalling ffi gem with correct platform"
gem install ffi --source "https://rubygems.org"

# 4. Configure Bundler
Write-Host "--- Configuring Bundler"
bundle config set force_ruby_platform true
bundle config set path vendor/bundle

# 5. Run bundle install with local gems
Write-Host "--- Running bundle install"
bundle install --verbose --jobs=7 --retry=3 --local
if ($LASTEXITCODE -ne 0) { throw "Bundle install failed with exit code $LASTEXITCODE" }

# 6. Run the actual task
Write-Host "+++ Executing bundle exec task"
bundle exec @args
if ($LASTEXITCODE -ne 0) { throw "Command failed with exit code $LASTEXITCODE" }
