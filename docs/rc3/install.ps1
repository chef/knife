# Chef Infra Client 19 Installer for Windows x64
# Uses presigned URLs for direct download and installation
#
# Copyright:: Copyright (c) 2010-2018 Chef Software, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

[CmdletBinding()]
param(
    [switch]$WhatIf
)

# Presigned URL for Chef Infra Client 19 MSI package
# This will be filled in with actual presigned URL
$msi_presigned_url = "https://chef-hab-migration-tool-bucket.s3.amazonaws.com/Release-Candidate-3/chef-ice/19.2.RC3/windows/x86_64/chef-ice-19.2.rc3-windows.msi?AWSAccessKeyId=AKIAW4FPVFT6C42N3U6R&Signature=rmb4GgaxE6oPEfVHiAugsg7xMBI%3D&Expires=1776916373"

# Global variables
$script:TempDir = $null
$script:StderrResults = ""

############
# Helper Functions
############

function Test-CommandExists {
    param([string]$Command)
    try {
        if (Get-Command $Command -ErrorAction SilentlyContinue) {
            return $true
        }
        return $false
    }
    catch {
        return $false
    }
}

function Write-BugReport {
    Write-Host ""
    Write-Host "Please file a Bug Report at https://github.com/chef/knife/issues/new" -ForegroundColor Yellow
    Write-Host "Please include as many details about the problem as possible i.e., how to reproduce" -ForegroundColor Yellow
    Write-Host "the problem (if possible), type of the Operating System and its version, etc.," -ForegroundColor Yellow
    Write-Host "and any other relevant details that might help us with troubleshooting." -ForegroundColor Yellow
    Write-Host ""
}

function Write-ChecksumMismatch {
    Write-Host "Package checksum mismatch!" -ForegroundColor Red
    Write-BugReport
    exit 1
}

function Write-UnableToRetrievePackage {
    param([string]$DownloadUrl, [string]$ErrorDetails = "")

    Write-Host "Unable to retrieve a valid package!" -ForegroundColor Red
    Write-BugReport
    Write-Host "Download URL: $DownloadUrl" -ForegroundColor Yellow
    if ($ErrorDetails) {
        Write-Host "`nDEBUG OUTPUT FOLLOWS:`n$ErrorDetails" -ForegroundColor Yellow
    }
    exit 1
}

function Write-UnsupportedPlatform {
    param([string]$Platform, [string]$Version, [string]$Architecture)

    Write-Host "This installer only supports Windows x64 systems" -ForegroundColor Red
    Write-Host "Detected: $Platform $Version on $Architecture" -ForegroundColor Yellow
    Write-Host ""
    Write-BugReport
    exit 1
}

function New-SecureTempDirectory {
    $tempPath = if ($env:TEMP) { $env:TEMP } else { $env:TMP }
    if (-not $tempPath) { $tempPath = "$env:USERPROFILE\AppData\Local\Temp" }

    $tempDirName = "chef-infra-install-$(Get-Random)"
    $fullPath = Join-Path $tempPath $tempDirName

    try {
        New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
        return $fullPath
    }
    catch {
        Write-Host "Failed to create temporary directory: $_" -ForegroundColor Red
        exit 1
    }
}

function Invoke-SecureDownload {
    param(
        [string]$Url,
        [string]$OutputPath
    )

    Write-Host "Downloading from: $Url"
    Write-Host "To file: $OutputPath"

    try {
        # Use TLS 1.2 for secure downloads
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "Chef-Infra-19-Installer")

        # Add progress indicator for large downloads
        $webClient.DownloadProgressChanged += {
            param($eventSender, $e)
            if ($e.ProgressPercentage % 10 -eq 0) {
                Write-Progress -Activity "Downloading Chef Infra Client 19" -Status "Progress: $($e.ProgressPercentage)%" -PercentComplete $e.ProgressPercentage
            }
        }

        $webClient.DownloadFileCompleted += {
            param($eventSender, $e)
            Write-Progress -Activity "Downloading Chef Infra Client 19" -Completed
            if ($e.Error) {
                throw $e.Error
            }
        }

        $webClient.DownloadFileAsync((New-Object System.Uri($Url)), $OutputPath)

        # Wait for download to complete
        while ($webClient.IsBusy) {
            Start-Sleep -Milliseconds 100
        }

        $webClient.Dispose()

        # Verify file was downloaded
        if (-not (Test-Path $OutputPath) -or (Get-Item $OutputPath).Length -eq 0) {
            throw "Downloaded file is empty or does not exist"
        }

        Write-Host "Download completed successfully" -ForegroundColor Green
        return $true
    }
    catch {
        $script:StderrResults += "Download error: $($_.Exception.Message)`n"
        Write-Host "Download failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-FileChecksum {
    param(
        [string]$FilePath,
        [string]$ExpectedChecksum
    )

    if (-not $ExpectedChecksum) {
        Write-Host "WARNING: No checksum provided, skipping verification..." -ForegroundColor Yellow
        return $true
    }

    try {
        Write-Host "Verifying file checksum..."
        $hash = Get-FileHash -Path $FilePath -Algorithm SHA256
        $actualChecksum = $hash.Hash.ToLower()
        $expectedLower = $ExpectedChecksum.ToLower()

        if ($actualChecksum -eq $expectedLower) {
            Write-Host "Checksum verification passed" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "Checksum mismatch!" -ForegroundColor Red
            Write-Host "Expected: $expectedLower" -ForegroundColor Yellow
            Write-Host "Actual:   $actualChecksum" -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        Write-Host "WARNING: Could not verify checksum: $($_.Exception.Message)" -ForegroundColor Yellow
        return $true
    }
}

function Install-MsiPackage {
    param(
        [string]$MsiPath
    )

    Write-Host "Installing Chef Infra Client 19 (MSI)..." -ForegroundColor Green

    if ($WhatIf) {
        Write-Host "WHATIF: Would install MSI package: $MsiPath" -ForegroundColor Cyan
        return $true
    }

    try {
        # Install MSI silently with logging
        $logPath = Join-Path $script:TempDir "chef-install.log"
        $arguments = @(
            "/i"
            "`"$MsiPath`""
            "/quiet"
            "/norestart"
            "/L*v"
            "`"$logPath`""
        )

        Write-Host "Running: msiexec.exe $($arguments -join ' ')"
        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $arguments -Wait -PassThru -NoNewWindow

        if ($process.ExitCode -eq 0) {
            Write-Host "Installation completed successfully!" -ForegroundColor Green
            return $true
        }
        elseif ($process.ExitCode -eq 3010) {
            Write-Host "Installation completed successfully (reboot required)" -ForegroundColor Yellow
            return $true
        }
        else {
            Write-Host "Installation failed with exit code: $($process.ExitCode)" -ForegroundColor Red
            if (Test-Path $logPath) {
                Write-Host "Installation log:" -ForegroundColor Yellow
                Get-Content $logPath | Select-Object -Last 20 | Write-Host
            }
            return $false
        }
    }
    catch {
        Write-Host "Installation failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-AdministratorPrivileges {
    $currentUser = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
}

function Get-WindowsVersionInfo {
    try {
        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
        return @{
            Platform = "Windows"
            Version = $osInfo.Version
            Caption = $osInfo.Caption
            Architecture = $osInfo.OSArchitecture
        }
    }
    catch {
        # Fallback method
        $osInfo = Get-WmiObject -Class Win32_OperatingSystem
        return @{
            Platform = "Windows"
            Version = $osInfo.Version
            Caption = $osInfo.Caption
            Architecture = $osInfo.OSArchitecture
        }
    }
}

############
# Main Installation Logic
############

function Main {
    Write-Host "Chef Infra Client 19 Installer for Windows" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan

    # Check for required presigned URLs
    if (-not $msi_presigned_url) {
        Write-Host "ERROR: Presigned URL not configured" -ForegroundColor Red
        Write-Host "Please set msi_presigned_url variable in this script" -ForegroundColor Yellow
        exit 1
    }

    # Platform detection
    Write-Host "Detecting platform..."
    $osInfo = Get-WindowsVersionInfo

    Write-Host "Detected: $($osInfo.Caption) ($($osInfo.Version)) - $($osInfo.Architecture)" -ForegroundColor Green

    # Validate platform support
    if ($osInfo.Platform -ne "Windows") {
        Write-UnsupportedPlatform -Platform $osInfo.Platform -Version $osInfo.Version -Architecture $osInfo.Architecture
    }

    if ($osInfo.Architecture -notmatch "64") {
        Write-Host "ERROR: This installer only supports 64-bit Windows systems" -ForegroundColor Red
        Write-Host "Detected architecture: $($osInfo.Architecture)" -ForegroundColor Yellow
        Write-UnsupportedPlatform -Platform $osInfo.Platform -Version $osInfo.Version -Architecture $osInfo.Architecture
    }

    # Check administrator privileges
    if (-not (Test-AdministratorPrivileges)) {
        Write-Host "ERROR: Administrator privileges required for installation" -ForegroundColor Red
        Write-Host "Please run this script as Administrator" -ForegroundColor Yellow
        exit 1
    }

    # Create secure temporary directory
    $script:TempDir = New-SecureTempDirectory
    Write-Host "Using temporary directory: $script:TempDir" -ForegroundColor Gray

    try {
        # Set download parameters for MSI package
        $downloadUrl = $msi_presigned_url
        $filename = "chef-infra-client-19-1-x64.msi"
        $downloadPath = Join-Path $script:TempDir $filename

        Write-Host "Will download Chef Infra Client 19 (MSI package)" -ForegroundColor Green

        # Download the package
        $downloadSuccess = Invoke-SecureDownload -Url $downloadUrl -OutputPath $downloadPath
        if (-not $downloadSuccess) {
            Write-UnableToRetrievePackage -DownloadUrl $downloadUrl -ErrorDetails $script:StderrResults
        }

        # Install the MSI package
        $installSuccess = Install-MsiPackage -MsiPath $downloadPath

        if (-not $installSuccess) {
            Write-Host "Installation failed" -ForegroundColor Red
            Write-BugReport
            exit 1
        }

        Write-Host ""
        Write-Host "Chef Infra Client 19 installation completed successfully!" -ForegroundColor Green
        Write-Host ""

        # Verify installation
        try {
            $chefVersion = & chef-client --version 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Verification: $chefVersion" -ForegroundColor Green
            }
        }
        catch {
            Write-Host "Installation completed, but chef-client command verification failed" -ForegroundColor Yellow
            Write-Host "You may need to restart your command prompt or add Chef to your PATH" -ForegroundColor Yellow
        }
    }
    finally {
        # Cleanup
        if ($script:TempDir -and (Test-Path $script:TempDir)) {
            try {
                Remove-Item -Path $script:TempDir -Recurse -Force
                Write-Host "Temporary files cleaned up" -ForegroundColor Gray
            }
            catch {
                Write-Host "Warning: Could not clean up temporary directory: $script:TempDir" -ForegroundColor Yellow
            }
        }
    }
}

############
# Script Execution
############

# Set error action preference
$ErrorActionPreference = "Stop"

# Run main function
try {
    Main
}
catch {
    Write-Host "Unexpected error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Yellow
    Write-BugReport
    exit 1
}
