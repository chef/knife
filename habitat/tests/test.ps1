$ErrorActionPreference = "Stop"

function Error {
    param (
        [string]$Message
    )
    Write-Host "`nERROR: $Message`n" -ForegroundColor Red
    exit 1
}

if (-not $args[0]) {
    Error "No hab package identity provided"
}

$pkg_ident = $args[0]
$package_version = ($pkg_ident -split '/')[2]

$project_root = git rev-parse --show-toplevel
Set-Location $project_root

Write-Host "Testing $pkg_ident executables"
$version = hab pkg exec $pkg_ident knife -v
Write-Host $version

$actual_version = if ($version -match "version: ([0-9]+\.[0-9]+\.[0-9]+)") {
    $matches[1]
} else {
    Error "Unable to extract version from output: $version"
}

if ($actual_version -notlike "*$package_version*") {
    Error "knife version is not the expected version. Expected '$package_version', got '$actual_version'"
}

Write-Host "--- Running tests for $Plan"

Write-Host "--- Checking system details"
uname -a

Write-Host "--- Installing dependencies"
# Add any dependency installation logic here if needed

Write-Host "--- Executing tests"
# Replace this with the actual test logic
Write-Host "Tests executed successfully!"