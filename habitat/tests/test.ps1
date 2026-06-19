$ErrorActionPreference = "Stop"

$project_root = (& git rev-parse --show-toplevel).Trim()
$pkg_ident = $args[0]

function Error {
    param ([string]$message)
    Write-Error "`nERROR: $message`n"
    exit 1
}

if (-not $pkg_ident) {
    Error "no hab package identity provided"
}

$package_version = ($pkg_ident -split '/')[2]

Set-Location $project_root
Write-Output "Testing $pkg_ident executables"
$version = (& hab pkg exec $pkg_ident knife -v).Trim()
Write-Output $version

$actual_version = ($version -replace '.*version: ([0-9]+\.[0-9]+\.[0-9]+).*', '$1')
Write-Output $actual_version

if ($actual_version -notlike "*$package_version*") {
    Error "knife version is not the expected version. Expected '$package_version', got '$actual_version'"
}

Write-Output "Verifying bundled knife plugins are available"
foreach ($plugin in @("ec2", "google", "windows")) {
    & hab pkg exec $pkg_ident knife $plugin --help *> $null
    if ($LASTEXITCODE -ne 0) {
        Error "knife plugin '$plugin' is not available in package '$pkg_ident'"
    }
}
