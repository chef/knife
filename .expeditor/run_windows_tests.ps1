$ErrorActionPreference = "Stop"

# Environment setup
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
gem sources --add $gem_source

# Install core Chef components with explicit platform
Write-Host "--- Installing Core Gems with Windows Platform ---"
gem install chef-utils --version "19.1.36" --platform=x64-mingw-ucrt --source $gem_source --no-document
gem install chef-config --version "19.1.36" --platform=x64-mingw-ucrt --source $gem_source --no-document
gem install ohai --platform=x64-mingw-ucrt --source $gem_source --no-document

# Install Windows-specific dependencies
Write-Host "--- Installing Windows Dependencies ---"
gem install win32-eventlog --platform=x64-mingw32 --source "https://rubygems.org" --no-document
gem install ffi --platform=x64-mingw32 --source "https://rubygems.org" --no-document

# Download and install chef gem with platform override
$gem_name = "chef-19.1.36-universal-unknown.gem"
$gem_url = "$gem_source/gems/$gem_name"
$gem_path = "$env:TEMP\$gem_name"

Write-Host "--- Downloading Chef Gem: $gem_url ---"
Invoke-WebRequest -Uri $gem_url -OutFile $gem_path -UseBasicParsing

if (Test-Path $gem_path) {
    Write-Host "✅ Chef gem downloaded: $gem_path"
    
    Write-Host "--- Installing with Windows Platform Enforcement ---"
    gem install $gem_path --platform=x64-mingw-ucrt
    
    # Verify installation structure
    $chefPath = (gem which chef).Replace("chef.rb", "")
    if (-not (Test-Path "$chefPath/lib/chef/mixin/convert_to_class_name.rb")) {
        throw "❌ Critical Chef files missing - gem may be corrupted"
    }
} else {
    Write-Host "❌ Failed to download Chef gem."
    exit 1
}

# Force regenerate binstubs
Write-Host "--- Regenerating Binstubs ---"
gem regenerate_binstubs chef --force

# Validate installation
Write-Host "--- Validating Chef Installation ---"
$installed_output = gem list chef --local

if ($installed_output -match "chef\s+\(19\.1\.36") {
    Write-Host "✅ Chef installed: $installed_output"
    
    # Verify load path
    Write-Host "--- Testing File Accessibility ---"
    ruby -e "require 'chef/mixin/convert_to_class_name'; puts '✓ convert_to_class_name loaded successfully'"
    
} else {
    Write-Host "❌ Chef gem installation failed"
    exit 1
}

# Clean and reinstall bundle
Write-Host "--- Clean Bundle Install ---"
Remove-Item -Recurse -Force vendor/bundle -ErrorAction SilentlyContinue
bundle config set force_ruby_platform true
bundle install --jobs=7 --retry=3

# Run task with explicit load path
Write-Host "+++ Executing with Load Path Fixes +++"
$chef_lib_path = (gem which chef).Replace("chef.rb", "")
$env:RUBYOPT = "-I$chef_lib_path $env:RUBYOPT"
bundle exec @args
if ($LASTEXITCODE -ne 0) {
    throw "❌ Command failed with exit code $LASTEXITCODE"
}