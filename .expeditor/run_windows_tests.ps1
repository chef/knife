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

Write-Host "--- Installing gems from Gemfile"
bundle install --jobs=7 --retry=3
if ($LASTEXITCODE -ne 0) { throw "❌ Bundle install failed with exit code $LASTEXITCODE" }

$version = Ruby -v | Out-String
$version = $version.Trim()
Write-Host "Ruby version reported by Ruby -v: '$version'"

if ($version -match "3.1") {
    Write-Host "❗ Ruby 3.1 detected: Fixing Chef PowerShell DLL casing after bundle install"
    $dll_folder_31 = "C:/workdir/vendor/bundle/ruby/3.1.0/gems/chef-powershell-18.1.0/bin/ruby_bin_folder/AMD64/"
    $expected_dll_31 = Join-Path $dll_folder_31 "Chef.PowerShell.Wrapper.dll"

    if (!(Test-Path -Path $expected_dll_31)) {
        $existing_dlls = Get-ChildItem -Path $dll_folder_31 -Filter "*.dll" -ErrorAction SilentlyContinue
        foreach ($dll in $existing_dlls) {
            if ($dll.Name -ieq "Chef.Powershell.Wrapper.dll" -and $dll.Name -cne "Chef.PowerShell.Wrapper.dll") {
                $source = $dll.FullName
                $dest = $expected_dll_31
                Write-Host "🔧 Creating corrected DLL copy: $dest"
                Copy-Item -Path $source -Destination $dest -Force
            }
        }
    }

    if (Test-Path -Path $expected_dll_31) {
        Write-Host "✅ DLL now found with correct casing at: $expected_dll_31"
    } else {
        Write-Host "❌ DLL still missing even after casing correction"
    }

    Write-Host "--- Final DLL list in folder (Ruby 3.1):"
    Get-ChildItem -Path $dll_folder_31 -Filter "*.dll" | ForEach-Object { Write-Host "📦 $($_.FullName)" }
}
elseif ($version -match "3.4") {
    Write-Host "✅ Ruby 3.4 detected: chef-powershell works without additional changes."
    $dll_folder_34 = "C:/workdir/vendor/bundle/ruby/3.4.0/gems/chef-powershell-18.1.0/bin/ruby_bin_folder/AMD64/"
    $expected_dll_34 = Join-Path $dll_folder_34 "Chef.PowerShell.Wrapper.dll"

    if (Test-Path -Path $expected_dll_34) {
        Write-Host "✅ DLL found at expected path for Ruby 3.4"
    } else {
        Write-Host "❌ DLL missing at expected path for Ruby 3.4"
    }

    Write-Host "--- Final DLL list in folder (Ruby 3.4):"
    Get-ChildItem -Path $dll_folder_34 -Filter "*.dll" | ForEach-Object { Write-Host "📦 $($_.FullName)" }
}
else {
    Write-Host "⚠️ Unknown Ruby version detected: $version"
}

Write-Host "--- Now looking for msvcrt.dll"
$lddpaths = Get-ChildItem -Path "C:\" -Filter "msvcrt.dll" -Recurse -ErrorAction SilentlyContinue
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
