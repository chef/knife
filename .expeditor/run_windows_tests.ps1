$ErrorActionPreference = "Stop"

# Set environment variables
$env:USER = "root"
$env:LANG = "C.UTF-8"
$env:LANGUAGE = "C.UTF-8"
$env:RUBYOPT = "-W0"

Write-Host "--- Configuring Artifactory access"
$env:ARTIFACTORY_ENDPOINT = "https://artifactory-internal.ps.chef.co/artifactory"
$env:ARTIFACTORY_USERNAME = "REDACTED@chef.io"

# Add Artifactory source
Write-Host "--- Adding Artifactory gem source"
gem sources --add "https://artifactory-internal.ps.chef.co/artifactory/api/gems/omnibus-gems-local"

# 1. Install MSYS2 and MINGW development tools (required for native extensions)
Write-Host "--- Setting up build tools"
ridk enable
ridk install 3  # Installs MSYS2 and MINGW (only needed once per system)

# 2. Download and install the exact gem version
Write-Host "--- Downloading chef gem with incorrect platform name"
$gem_url = "https://artifactory-internal.ps.chef.co/artifactory/api/gems/omnibus-gems-local/gems/chef-19.1.36-universal-unknown.gem"
$downloaded_path = "$env:TEMP\chef-19.1.36-universal-unknown.gem"
$renamed_path = "$env:TEMP\chef-19.1.36-universal-mingw-ucrt.gem"

Invoke-WebRequest -Uri $gem_url -OutFile $downloaded_path

Write-Host "--- Renaming to correct platform name"
Rename-Item -Path $downloaded_path -NewName (Split-Path $renamed_path -Leaf)

Write-Host "--- Installing chef gem"
gem install --local $renamed_path --force --ignore-dependencies

# 3. Configure Bundler
Write-Host "--- Configuring Bundler"
bundle config set force_ruby_platform true
bundle config set path vendor/bundle

# 4. Run bundle install with local gems
Write-Host "--- Running bundle install"
bundle install --verbose --jobs=7 --retry=3 --local
if ($LASTEXITCODE -ne 0) { throw "Bundle install failed with exit code $LASTEXITCODE" }

# 5. Run the actual task
Write-Host "+++ Executing bundle exec task"
bundle exec @args
if ($LASTEXITCODE -ne 0) { throw "Command failed with exit code $LASTEXITCODE" }
