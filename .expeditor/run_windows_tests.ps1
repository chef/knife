$ErrorActionPreference = "Stop"

Write-Host "--- Configuring Artifactory access"
$env:ARTIFACTORY_ENDPOINT = "https://artifactory-internal.ps.chef.co/artifactory"
$env:ARTIFACTORY_USERNAME = "REDACTED@chef.io"
$gem_source = "$env:ARTIFACTORY_ENDPOINT/api/gems/omnibus-gems-local"

Write-Host "--- Downloading Chef gem from Artifactory"
$downloaded_path = "$env:TEMP\chef-19.1.36-universal-unknown.gem"
Invoke-WebRequest -Uri "$gem_source/gems/chef-19.1.36-universal-unknown.gem" -OutFile $downloaded_path -UseBasicParsing

Write-Host "--- Renaming gem file to match correct platform"
$corrected_path = "$env:TEMP\chef-19.1.36-universal-mingw-ucrt.gem"
Rename-Item -Path $downloaded_path -NewName (Split-Path $corrected_path -Leaf)

Write-Host "--- Moving gem to vendor/cache"
$cache_path = "vendor/cache"
if (!(Test-Path $cache_path)) { New-Item -ItemType Directory -Path $cache_path | Out-Null }
Move-Item -Path $corrected_path -Destination "$cache_path/chef-19.1.36-universal-mingw-ucrt.gem" -Force

Write-Host "--- Configuring bundler for Windows platform"
bundle config set --local path vendor/bundle
bundle config set --local force_ruby_platform false
bundle config set --local no_prune true
bundle lock --add-platform x64-mingw-ucrt

Write-Host "--- Verifying Chef.PowerShell.Wrapper.dll existence at error path"

$expected_dll_31 = "C:\workdir\vendor\bundle\ruby\3.1.0\gems\chef-powershell-18.1.0\bin\ruby_bin_folder\AMD64\Chef.PowerShell.Wrapper.dll"
$expected_dll_34 = "C:\workdir\vendor\bundle\ruby\3.4.0\gems\chef-powershell-18.1.0\bin\ruby_bin_folder\AMD64\Chef.PowerShell.Wrapper.dll"

if ($version -match "3.1") {
    Write-Host "Checking Ruby 3.1 expected DLL path: $expected_dll_31"
    if (Test-Path -Path $expected_dll_31) {
        Write-Host "✅ Chef.PowerShell.Wrapper.dll FOUND for Ruby 3.1"
    } else {
        Write-Host "❌ Chef.PowerShell.Wrapper.dll MISSING for Ruby 3.1"
    }
}

if ($version -match "3.4") {
    Write-Host "Checking Ruby 3.4 expected DLL path: $expected_dll_34"
    if (Test-Path -Path $expected_dll_34) {
        Write-Host "✅ Chef.PowerShell.Wrapper.dll FOUND for Ruby 3.4"
    } else {
        Write-Host "❌ Chef.PowerShell.Wrapper.dll MISSING for Ruby 3.4"
    }
}

Write-Host "--- Installing gems from Gemfile"
bundle install --jobs=7 --retry=3
if ($LASTEXITCODE -ne 0) { throw "❌ Bundle install failed with exit code $LASTEXITCODE" }

Write-Host "--- Why is Chef PowerShell telling me the file is not found?"
Write-Host "--- Checking for Chef-PowerShell gem"
Write-Host "--- Verifying Chef-PowerShell gem installation"
$version = Ruby -v 
Write-Host "Ruby version: $version"
if ($version -match "3.1"){
    $dlls = Get-ChildItem -Path "C:/workdir/vendor/bundle/ruby/3.1.0/gems/chef-powershell-18.1.0/bin/ruby_bin_folder/AMD64/" -Filter "msvc*.dll"
    foreach ($dll in $dlls) {
        Write-Host "I have this DLL: $($dll.FullName)"
    }
}

Write-Host "--- Now looking for msvcrt.dll"
$lddpaths = gci -Path "C:\" -Filter "msvcrt.dll" -Recurse -ErrorAction SilentlyContinue
if ($lddpaths) {
    foreach ($ldd in $lddpaths) {
        Write-Host "Found msvcrt at: $($ldd.FullName)"
    }
} else {
    Write-Host "No msvcrt.dll found in the directory tree."
}

Write-Host "+++ Executing bundle exec task"
bundle exec $args
if ($LASTEXITCODE -ne 0) { throw "❌ Command failed with exit code $LASTEXITCODE" }