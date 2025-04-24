$ErrorActionPreference="stop"
Write-Host "--- Cloning chef repo (if needed)"

# Clone the chef repo only if not already present
if (!(Test-Path "chef")) {
  git clone https://github.com/chef/chef.git
}

Set-Location chef

Write-Host "--- Setting up bundler"

# Make sure bundler installs to vendor
bundle config set --local path vendor/bundle

# Install bundler dependencies from GitHub sources (see Gemfile)
bundle install --jobs=7 --retry=3

# Install native dependencies manually if needed
gem install win32ole
gem install ffi-libarchive
gem install chef-powershell

# Generate binstubs for easier access
bundle binstubs knife --path ./bin --force

# Add binstubs to PATH for current session
$env:PATH = "$PSScriptRoot\bin;$env:PATH"

# Validate that everything is working
bundle exec knife --version
Write-Host "--- bundle install done"

# Run tests
Write-Host "+++ Running tests"
bundle exec rake spec
if ($LASTEXITCODE -ne 0) { throw "$args failed" }
