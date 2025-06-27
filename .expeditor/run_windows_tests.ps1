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
Move-Item -Path $corrected_path -Destination "$cache_path\chef-19.1.36-universal-mingw-ucrt.gem" -Force

Write-Host "--- Configuring bundler for Windows platform"
bundle config set --local path vendor/bundle
bundle config set --local force_ruby_platform false
bundle config set --local no_prune true
bundle lock --add-platform x64-mingw-ucrt

Write-Host "--- Installing gems from Gemfile"
bundle install --jobs=7 --retry=3
if ($LASTEXITCODE -ne 0) { throw "Bundle install failed with exit code $LASTEXITCODE" }

$version = Ruby -v | Out-String
$version = $version.Trim()
Write-Host "Ruby version: $version"

# Determine Ruby version path
if ($version -match "3.1") {
    $ruby_ver = "3.1.0"
} elseif ($version -match "3.4") {
    $ruby_ver = "3.4.0"
} else {
    Write-Host "WARNING: Unknown Ruby version. Skipping DLL check."
    $ruby_ver = $null
}

# Fix DLL name casing if needed
if ($ruby_ver) {
    $dll_dir = Join-Path "C:\workdir\vendor\bundle\ruby" $ruby_ver
    $dll_dir = Join-Path $dll_dir "gems\chef-powershell-18.1.0\bin\ruby_bin_folder\AMD64"

    $correct_dll = Join-Path $dll_dir "Chef.PowerShell.Wrapper.dll"
    $wrong_dll = Join-Path $dll_dir "Chef.Powershell.Wrapper.dll"

    Write-Host "--- Listing DLLs in folder before fix:"
    Get-ChildItem -Path $dll_dir -Filter "*.dll" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Host "Found DLL: $($_.FullName)"
    }

    if (!(Test-Path $correct_dll) -and (Test-Path $wrong_dll)) {
        Write-Host "Fixing DLL casing: copying $wrong_dll to $correct_dll"
        Copy-Item -Path $wrong_dll -Destination $correct_dll -Force
    }

    if (Test-Path $correct_dll) {
        Write-Host "DLL now present: $correct_dll"
    } else {
        Write-Host "DLL still missing after attempted fix."
    }

    Write-Host "--- Listing DLLs in folder after fix:"
    Get-ChildItem -Path $dll_dir -Filter "*.dll" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Host "Found DLL: $($_.FullName)"
    }
}

Write-Host "--- Searching for msvcrt.dll on disk"
$lddpaths = Get-ChildItem -Path "C:\" -Filter "msvcrt.dll" -Recurse -ErrorAction SilentlyContinue
if ($lddpaths) {
    foreach ($ldd in $lddpaths) {
        Write-Host "Found msvcrt.dll at: $($ldd.FullName)"
    }
} else {
    Write-Host "No msvcrt.dll found in the directory tree."
}

Write-Host "+++ Executing bundle exec task"
bundle exec $args
if ($LASTEXITCODE -ne 0) { throw "Command failed with exit code $LASTEXITCODE" }
