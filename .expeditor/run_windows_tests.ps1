$ErrorActionPreference = "Stop"

# Environment setup
$env:USER = "root"
$env:LANG = "C.UTF-8"
$env:LANGUAGE = "C.UTF-8"
$env:RUBYOPT = "-W0"

# Skip Artifactory setup on Windows
if (-not $IsWindows) {
  Write-Host "`n--- Configuring Artifactory Access (Non-Windows Only) ---"
  $env:ARTIFACTORY_ENDPOINT = "https://artifactory-internal.ps.chef.co/artifactory"
  $gem_source = "$env:ARTIFACTORY_ENDPOINT/api/gems/omnibus-gems-local"
  gem sources --add $gem_source
}

# Install Windows-specific native dependencies
Write-Host "--- Installing win32-eventlog (Windows-only) ---"
gem install win32-eventlog --source "https://rubygems.org"

Write-Host "--- Installing ffi Gem (Windows native) ---"
gem install ffi --platform=x64-mingw32 --source "https://rubygems.org"

# Validate Ruby and Gem Setup
Write-Host "--- RubyGems environment ---"
gem env

Write-Host "--- Ruby version ---"
ruby -v

# # --- Bundler install ---
# if (-not (Get-Command bundle -ErrorAction SilentlyContinue)) {
#   Write-Host "--- Installing bundler ---"
#   gem install bundler --no-document
# }

# --- Bundle setup ---
Write-Host "--- Configuring Bundler path ---"
bundle config set --local path vendor/bundle

Write-Host "--- Running bundle install ---"
bundle install --jobs=7 --retry=3
if ($LASTEXITCODE -ne 0) {
    throw "❌ bundle install failed with exit code $LASTEXITCODE"
}

# Validate chef and its binstub
Write-Host "--- Verifying Chef Executables ---"
$chefPath = (Get-Command chef-client -ErrorAction SilentlyContinue).Path
if ($chefPath) {
    & $chefPath -v
} else {
    Write-Host "⚠️ 'chef-client' executable not found in PATH"
}

# Show installed gems
Write-Host "--- Installed Chef Gems ---"
bundle list | Select-String "chef"

# Run the given task
Write-Host "+++ Executing bundle exec task +++"
bundle exec @args
if ($LASTEXITCODE -ne 0) {
    throw "❌ Command failed with exit code $LASTEXITCODE"
}
