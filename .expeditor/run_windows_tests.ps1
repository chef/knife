$ErrorActionPreference = "Stop"

# 0. ENVIRONMENT SETUP -----------------------------------------------------
$env:USER = "root"
$env:LANG = "C.UTF-8"
$env:LANGUAGE = "C.UTF-8"
$env:RUBYOPT = "-W0"

Write-Host "`n--- Configuring Artifactory Access ---"
$env:ARTIFACTORY_ENDPOINT = "https://artifactory-internal.ps.chef.co/artifactory"
$env:ARTIFACTORY_USERNAME = "REDACTED@chef.io"
$gem_source = "$env:ARTIFACTORY_ENDPOINT/api/gems/omnibus-gems-local"

# Add Artifactory gem source
Write-Host "--- Adding Artifactory Gem Source ---"
gem sources --add $gem_source | Out-Null

# 1. GEM INSTALLATION -------------------------------------------------------
Write-Host "`n--- Installing Core Gems from Artifactory ---"
gem install chef-utils  --version "19.1.36" --source $gem_source --no-document
gem install chef-config --version "19.1.36" --source $gem_source --no-document

Write-Host "--- Installing ohai from RubyGems ---"
gem install ohai --no-document --source "https://rubygems.org"

Write-Host "--- Installing Windows Native Gems ---"
gem install win32-eventlog --source "https://rubygems.org" --no-document
gem install ffi --platform=x64-mingw32 --source "https://rubygems.org" --no-document

# 2. CHEF GEM DOWNLOAD & INSTALL --------------------------------------------
$gem_name = "chef-19.1.36-universal-unknown.gem"
$gem_url = "$gem_source/gems/$gem_name"
$gem_path = "$env:TEMP\$gem_name"

Write-Host "`n--- Downloading Chef Gem from Artifactory: $gem_url ---"
Invoke-WebRequest -Uri $gem_url -OutFile $gem_path -UseBasicParsing

if (Test-Path $gem_path) {
    Write-Host "✅ Chef gem downloaded: $gem_path"
    Write-Host "`n--- .gem files in TEMP directory ---"
    Get-ChildItem "$env:TEMP\*.gem" | Format-Table Name, Length, LastWriteTime
} else {
    Write-Host "❌ Failed to download Chef gem."
    exit 1
}

Write-Host "--- Installing Chef Gem from Downloaded File ---"
gem install $gem_path --force --platform=x64-mingw-ucrt

# --- Add broken gem's lib path to RUBYOPT manually ---
# Determine actual GEM_HOME from Ruby
$gem_home = & gem env gemdir
if (-not (Test-Path $gem_home)) {
    throw "❌ GEM_HOME '$gem_home' not found"
}

# Find the installed chef gem directory
$chef_gem_root = Get-ChildItem "$gem_home/gems" -Directory | Where-Object {
    $_.Name -like "chef-19.1.36*"
} | Select-Object -First 1

if (-not $chef_gem_root) {
    throw "❌ Could not locate chef gem in $gem_home"
}

# Patch RUBYOPT with the real path
$chef_data_lib = Join-Path $chef_gem_root.FullName "data\lib"
if (-not (Test-Path $chef_data_lib)) {
    throw "❌ 'data/lib' directory not found in $($chef_gem_root.FullName)"
}

Write-Host "⚠️ Patching RUBYOPT with $chef_data_lib"
$env:RUBYOPT = "-I$chef_data_lib $env:RUBYOPT"



# 3. VALIDATION -------------------------------------------------------------
Write-Host "`n--- Validating Chef Installation ---"
$installed_output = gem list chef --local

if ($installed_output -match "chef\s+\(19\.1\.36") {
    Write-Host $installed_output
    Write-Host "✅ Chef gem installed successfully"

    # Test actual file loading
    $test_script = @"
require 'chef'
require 'chef/mixin/convert_to_class_name'
require 'chef/knife'
puts '✅ SUCCESS: Chef modules loaded'
"@
    $test_file = "$env:TEMP\chef_load_test.rb"
    $test_script | Out-File $test_file -Encoding ASCII
    ruby $test_file
} else {
    Write-Host "❌ Chef gem installation failed"
    Write-Host $installed_output
    exit 1
}

# 4. PLATFORM RECHECK (ffi) -------------------------------------------------
Write-Host "`n--- Reinstalling ffi to Ensure Platform Match ---"
gem install ffi --source "https://rubygems.org" --no-document

# 5. BUNDLER INSTALL --------------------------------------------------------
Write-Host "`n--- Configuring Bundler ---"
bundle config --local path vendor/bundle

Write-Host "--- Running bundle install (local) ---"
bundle install --jobs=7 --retry=3 --local
if ($LASTEXITCODE -ne 0) {
    throw "❌ bundle install failed with exit code $LASTEXITCODE"
}

# 6. FINAL EXECUTION --------------------------------------------------------
Write-Host "`n+++ Executing bundle exec task +++"
bundle exec @args
if ($LASTEXITCODE -ne 0) {
    throw "❌ Command failed with exit code $LASTEXITCODE"
}
