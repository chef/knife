$ErrorActionPreference = "Stop"

# 0. ENVIRONMENT SETUP -----------------------------------------------------
$env:USER = "root"
$env:LANG = "C.UTF-8"
$env:LANGUAGE = "C.UTF-8"
$env:RUBYOPT = "-W0"

Write-Host "`n--- Configuring Artifactory Access ---"
$env:ARTIFACTORY_ENDPOINT = "https://artifactory-internal.ps.chef.co/artifactory"
$gem_source = "$env:ARTIFACTORY_ENDPOINT/api/gems/omnibus-gems-local"

# Add Artifactory gem source
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
    Get-ChildItem "$env:TEMP\*.gem" | Format-Table Name, Length, LastWriteTime
} else {
    throw "❌ Failed to download Chef gem."
}

Write-Host "--- Installing Chef Gem from Downloaded File ---"
gem install $gem_path --force --platform=x64-mingw-ucrt

# 3. VALIDATION -------------------------------------------------------------
Write-Host "`n--- Validating Chef Installation ---"
$gem_home = & gem env gemdir
$chef_gem_root = Get-ChildItem "$gem_home/gems" -Directory | Where-Object {
    $_.Name -like "chef-19.1.36*"
} | Select-Object -First 1

if (-not $chef_gem_root) {
    throw "❌ Could not locate installed chef gem in $gem_home"
}

# Validate presence of required lib files
$required_files = @(
    "lib/chef.rb",
    "lib/chef/mixin/convert_to_class_name.rb",
    "lib/chef/knife.rb"
)

$missing = $required_files | Where-Object {
    -not (Test-Path (Join-Path $chef_gem_root.FullName $_))
}

if ($missing.Count -gt 0) {
    throw "❌ Installed chef gem is broken — missing files: $($missing -join ', ')"
}

# Test loading
Write-Host "--- Testing Chef require statements ---"
$test_script = @"
require 'chef'
require 'chef/mixin/convert_to_class_name'
require 'chef/knife'
puts '✅ SUCCESS: Chef modules loaded'
"@
$test_file = "$env:TEMP\chef_load_test.rb"
$test_script | Out-File $test_file -Encoding ASCII
ruby $test_file

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
