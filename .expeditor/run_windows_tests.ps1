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

Write-Host "--- Verifying Chef.PowerShell.Wrapper.dll existence at error path ---"
$version = Ruby -v | Out-String
$version = $version.Trim()
Write-Host "Ruby version reported by Ruby -v: '$version'"

if ($version -match "3.1") {
    Write-Host "❗ Ruby 3.1 detected: Chef PowerShell is known to fail due to missing or incompatible native DLLs."
    $expected_dll_31 = "C:\workdir\vendor\bundle\ruby\3.1.0\gems\chef-powershell-18.1.0\bin\ruby_bin_folder\AMD64\Chef.PowerShell.Wrapper.dll"
    Write-Host "Checking for DLL at: $expected_dll_31"
    if (Test-Path -Path $expected_dll_31) {
        Write-Host "✅ DLL FOUND at expected path for Ruby 3.1"
    } else {
        Write-Host "❌ DLL MISSING at expected path for Ruby 3.1"
    }
    Write-Host "👉 Forcing chef-powershell reinstall for Ruby 3.1"
    gem uninstall chef-powershell -x -a
    gem install chef-powershell -v 18.1.0 --platform x64-mingw-ucrt --source "$gem_source"
    Write-Host "✅ chef-powershell reinstall completed for Ruby 3.1"
} elseif ($version -match "3.4") {
    Write-Host "✅ Ruby 3.4 detected: chef-powershell works without additional changes."
    $expected_dll_34 = "C:\workdir\vendor\bundle\ruby\3.4.0\gems\chef-powershell-18.1.0\bin\ruby_bin_folder\AMD64\Chef.PowerShell.Wrapper.dll"
    Write-Host "Checking for DLL at: $expected_dll_34"
    if (Test-Path -Path $expected_dll_34) {
        Write-Host "✅ DLL FOUND at expected path for Ruby 3.4"
    } else {
        Write-Host "❌ DLL MISSING at expected path for Ruby 3.4"
    }
} else {
    Write-Host "⚠️ Unknown Ruby version detected: $version"
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
    $dlls = Get-ChildItem -Path "C:/workdir/vendor/bundle/ruby/3.1.0/gems/chef-powershell-18.1.0/bin/ruby_bin_folder/AMD64/"
    foreach ($dll in $dlls) {
        Write-Host "I have this DLL: $($dll.FullName)"
    }
}
if ($version -match "3.4"){
    $dlls = Get-ChildItem -Path "C:/workdir/vendor/bundle/ruby/3.4.0/gems/chef-powershell-18.1.0/bin/ruby_bin_folder/AMD64/"
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