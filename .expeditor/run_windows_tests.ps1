$ErrorActionPreference="stop"

Write-Host "--- Unsetting any bundler mirrors"
bundle config unset mirror.https://rubygems.org

Write-Host "---- Configuring TLS (for corporate proxies)"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "---- Installing Vault if not present"
if (-not (Get-Command vault -ErrorAction SilentlyContinue)) {
    $vaultVersion = "1.8.2"
    $vaultZip = "vault_${vaultVersion}_windows_amd64.zip"
    $vaultUrl = "https://releases.hashicorp.com/vault/$vaultVersion/$vaultZip"
    $vaultTmp = "$env:TEMP\$vaultZip"
    Invoke-WebRequest -Uri $vaultUrl -OutFile $vaultTmp
    Expand-Archive -Path $vaultTmp -DestinationPath $env:TEMP -Force
    Move-Item -Path "$env:TEMP\vault.exe" -Destination "C:\Windows\System32\vault.exe" -Force
    Remove-Item $vaultTmp
}

Write-Host "--- Configuring Artifactory environment"
$env:ARTIFACTORY_ENDPOINT = "artifactory-internal.ps.chef.co/artifactory"
$env:ARTIFACTORY_USERNAME = "REDACTED@chef.io"
$env:ARTIFACTORY_PASSWORD = "$(vault read -field password account/static/artifactory/buildkite)"

Write-Host "--- Cleaning bundle directory"
if (Test-Path "vendor\bundle") {
  Remove-Item -Recurse -Force "vendor\bundle"
}

bundle cache --clean

Write-Host "--- Installing required system gems"
gem install win32ole
gem install ffi-libarchive

Write-Host "--- Setting bundler path and installing"
bundle config --local path vendor/bundle
bundle install --jobs=7 --retry=3

Write-Host "--- Running task"
$env:RUBYOPT="-W0"
bundle exec $args
if ($LASTEXITCODE -ne 0) {
  throw "$args failed"
}
