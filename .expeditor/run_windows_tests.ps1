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

# Install core Chef components
Write-Host "--- Installing Core Gems: chef-utils, chef-config, ohai ---"
gem install chef-utils  --version "19.1.36" --source $gem_source
gem install chef-config --version "19.1.36" --source $gem_source
gem install ohai --source $gem_source

# Install Windows-specific dependencies
Write-Host "--- Installing win32-eventlog ---"
gem install win32-eventlog --source "https://rubygems.org"

Write-Host "--- Installing ffi Gem (native) ---"
gem install ffi --platform=x64-mingw32 --source "https://rubygems.org"

# Download and install chef gem manually
$gem_name = "chef-19.1.36-universal-unknown.gem"
$gem_url = "$gem_source/gems/$gem_name"
$gem_path = "$env:TEMP\$gem_name"

Write-Host "--- Downloading Chef Gem: $gem_url ---"
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
gem install $gem_path --force --ignore-dependencies

# Validate installation
Write-Host "--- Validating Chef Installation ---"
$installed_output = gem list chef --local

if ($installed_output -match "chef\s+\(19\.1\.36") {
    Write-Host $installed_output
    Write-Host "✅ Chef gem installed successfully"

    Write-Host "--- Chef Client Version ---"
    $chefClientPath = (Get-Command chef-client -ErrorAction SilentlyContinue).Path
    if ($chefClientPath) {
        & $chefClientPath -v
    } else {
        Write-Host "⚠️ 'chef-client' executable not found in PATH"
    }

    # 🔍 New additions
    Write-Host "--- Verifying chef gem info ---"
    gem info chef

    Write-Host "--- RubyGems environment ---"
    gem env

    $Ruby31Bin = "C:\ruby31\bin"
    $Ruby34Bin = "C:\ruby34\bin"

    Write-Host "`n--- 📦 Files in Ruby 3.1 bin ($Ruby31Bin) ---"
    if (Test-Path $Ruby31Bin) {
      Get-ChildItem "$Ruby31Bin" -File | Sort-Object Name | Format-Table Name, Length, LastWriteTime
    } else {
    Write-Host "❌ Ruby 3.1 bin path not found: $Ruby31Bin"
    }

    Write-Host "`n--- 📦 Files in Ruby 3.4 bin ($Ruby34Bin) ---"
    if (Test-Path $Ruby34Bin) {
      Get-ChildItem "$Ruby34Bin" -File | Sort-Object Name | Format-Table Name, Length, LastWriteTime
    } else {
    Write-Host "❌ Ruby 3.4 bin path not found: $Ruby34Bin"
    }

} else {
    Write-Host "❌ Chef gem installation failed"
    Write-Host "Installed gems:"
    Write-Host $installed_output
    exit 1
}

# Reinstall ffi to ensure native compatibility
Write-Host "--- Reinstalling ffi to Ensure Platform Match ---"
gem install ffi --source "https://rubygems.org"

# Bundler configuration and install
Write-Host "--- Configuring Bundler ---"
bundle config --local path vendor/bundle

Write-Host "--- Running bundle install (local) ---"
bundle install --jobs=7 --retry=3
if ($LASTEXITCODE -ne 0) {
    throw "❌ bundle install failed with exit code $LASTEXITCODE"
}

# Run task
Write-Host "+++ Executing bundle exec task +++"
bundle exec @args
if ($LASTEXITCODE -ne 0) {
    throw "❌ Command failed with exit code $LASTEXITCODE"
}
