$ErrorActionPreference="stop"
Write-Host "--- Cloning chef repo"

if (!(Test-Path "chef")) {
  git clone https://github.com/chef/chef.git
}

Set-Location chef

Write-Host "--- Cleaning up old bundle state"

if (Test-Path "Gemfile.lock") {
  Remove-Item "Gemfile.lock"
}
if (Test-Path "vendor/bundle") {
  Remove-Item -Recurse -Force "vendor/bundle"
}

Write-Host "--- Configuring bundler path"
bundle config set --local path vendor/bundle

Write-Host "--- Installing dependencies"
bundle install --jobs=7 --retry=3

Write-Host "--- Installing native gems"
gem install win32ole
gem install ffi-libarchive
gem install chef-powershell

Write-Host "--- Generating binstubs"
bundle binstubs knife --path ./bin --force

# Add binstubs to PATH
$env:PATH = "$PSScriptRoot\bin;$env:PATH"

Write-Host "--- Verifying knife"
bundle exec knife --version

Write-Host "--- Running tests"
bundle exec rake spec
if ($LASTEXITCODE -ne 0) { throw "$args failed" }
