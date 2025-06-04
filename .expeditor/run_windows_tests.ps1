$ErrorActionPreference="stop"
# Write-Host "---- printing aws version"
# aws --version
# Write-Host "----  printing aws version"
Write-Host "---- getting chef gem"

# Ensure unzip (Expand-Archive) and Vault are available

# Install Vault if not present
if (-not (Get-Command vault -ErrorAction SilentlyContinue)) {
    Write-Host "--- installing vault"
    $vaultVersion = "1.8.2"
    $vaultZip = "vault_${vaultVersion}_windows_amd64.zip"
    $vaultUrl = "https://releases.hashicorp.com/vault/$vaultVersion/$vaultZip"
    $vaultTmp = "$env:TEMP\$vaultZip"
    Invoke-WebRequest -Uri $vaultUrl -OutFile $vaultTmp
    Expand-Archive -Path $vaultTmp -DestinationPath $env:TEMP -Force
    Move-Item -Path "$env:TEMP\vault.exe" -Destination "C:\Windows\System32\vault.exe" -Force
    Remove-Item $vaultTmp
}

# Expand-Archive is built-in on modern PowerShell/Windows, so unzip is not needed separately.
# If you need to unzip other files, use Expand-Archive:
# Expand-Archive -Path <zipfile> -DestinationPath <folder> -Force

$env:ARTIFACTORY_ENDPOINT="artifactory-internal.ps.chef.co/artifactory"
$env:ARTIFACTORY_USERNAME="REDACTED@chef.io"
#$lita_password=aws ssm get-parameter --name "artifactory-lita-password" --with-decryption --query Parameter.Value --output text --region us-west-2
$env:ARTIFACTORY_PASSWORD="$(vault read -field password account/static/artifactory/buildkite)"
Write-Host "---- getting chef gem done"
# git clone https://github.com/chef/chef.git
# cd chef ; bundle install; cd chef-utils; gem build chef-utils.gemspec; gem install chef-utils-*.gem ; cd .. ;
# cd chef-config; gem build chef-config.gemspec; gem install chef-config-*.gem ; cd ..;
# gem build chef-universal-mingw-ucrt.gemspec; gem install chef-*.gem ; cd ..;
bundle config --local path vendor/bundle
gem install win32ole
gem install ffi-libarchive
bundle install --jobs=7 --retry=3
Write-Host "--- bundle  install done"
bundle exec task

$env:RUBYOPT="-W0"; bundle exec $args
if ($LASTEXITCODE -ne 0) { throw "$args failed" }
