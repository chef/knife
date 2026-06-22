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
$plugin_checks = @(
    @{name = "ec2"; pattern = "Available ec2 subcommands"},
    @{name = "google"; pattern = "Available google subcommands"},
    @{name = "windows"; pattern = "Available windows subcommands"}
)

foreach ($check in $plugin_checks) {
    $output = & {
        $ErrorActionPreference = "Continue"
        & hab pkg exec $pkg_ident knife $($check.name) 2>&1
    } | Out-String
    if ($output -match $check.pattern) {
        Write-Output "Plugin '$($check.name)' is available"
    } else {
        Write-Error "knife plugin '$($check.name)' is not available in package '$pkg_ident'"
        exit 1
    }
}
Write-Output "All bundled plugins verified successfully"
