$ErrorActionPreference = "Stop"

# 1. GEM INSTALLATION -------------------------------------------------------
Write-Host "=== PHASE 1: Install base gems from Artifactory ==="

$dependencies = @(
    "chef-utils --version 19.1.36",
    "chef-config --version 19.1.36",
    "ohai --version 19.1.36",
    "win32-eventlog",
    "ffi --platform=x64-mingw32"
)

foreach ($dep in $dependencies) {
    $args = "$dep --source https://artifactory-internal.ps.chef.co/artifactory/api/gems/omnibus-gems-local --no-document --platform=x64-mingw-ucrt"
    Write-Host "Installing: $dep"
    Invoke-Expression "gem install $args"
}

# 2. DOWNLOAD & VERIFY CHEF GEM ---------------------------------------------
Write-Host "`n=== PHASE 2: Download and verify chef gem ==="

$gem_name = "chef-19.1.36-universal-unknown.gem"
$gem_url = "https://artifactory-internal.ps.chef.co/artifactory/api/gems/omnibus-gems-local/gems/$gem_name"
$gem_path = "$env:TEMP\$gem_name"
$extract_path = "$env:TEMP\chef_gem_contents"

Invoke-WebRequest -Uri $gem_url -OutFile $gem_path

# Extract and verify contents
Add-Type -AssemblyName System.IO.Compression.FileSystem
Remove-Item -Recurse -Force $extract_path -ErrorAction SilentlyContinue
[System.IO.Compression.ZipFile]::ExtractToDirectory($gem_path, $extract_path)

$required_paths = @(
    "lib/chef.rb",
    "lib/chef/mixin/convert_to_class_name.rb",
    "lib/chef/knife.rb"
)

$missing_files = $required_paths | Where-Object { -not (Test-Path "$extract_path/$_") }
if ($missing_files) {
    throw "❌ CORRUPT GEM - Missing files: $($missing_files -join ', ')"
}

# 3. INSTALL CHEF GEM -------------------------------------------------------
Write-Host "`n=== PHASE 3: Install chef gem ==="
gem install $gem_path --ignore-dependencies --force --platform=x64-mingw-ucrt

# 4. LOAD PATH FIX ----------------------------------------------------------
Write-Host "`n=== PHASE 4: Configure Ruby load path ==="

# Add all dependent gem paths to RUBYOPT manually
$load_paths = @(
    (gem which chef-utils).Replace("lib/chef-utils.rb", ""),
    (gem which chef-config).Replace("lib/chef-config.rb", ""),
    (gem which ohai).Replace("lib/ohai.rb", ""),
    (gem which chef).Replace("lib/chef.rb", "")
)

$env:RUBYOPT = "-I" + ($load_paths -join ";") + " $env:RUBYOPT"

# 5. VALIDATION -------------------------------------------------------------
Write-Host "`n=== PHASE 5: Validate Chef load ==="

$test_script = @"
require 'chef'
require 'chef/mixin/convert_to_class_name'
require 'chef/knife'
puts '✅ SUCCESS: All Chef files loaded correctly'
"@

$test_file = "$env:TEMP\chef_load_test.rb"
$test_script | Out-File $test_file -Encoding ASCII
ruby $test_file

# 6. EXECUTION --------------------------------------------------------------
Write-Host "`n=== PHASE 6: Execute your task ==="

# Skip bundler and use plain execution
ruby your_script.rb @args
if ($LASTEXITCODE -ne 0) {
    throw "❌ Task failed with exit code $LASTEXITCODE"
}
