# Bootstrap with Presigned URLs for Chef Infra Client 19 RC3

This guide explains how to use the custom `install.sh` and `install.ps1` scripts with presigned URLs to bootstrap Chef Infra Client 19 RC3 on Linux and Windows nodes using knife bootstrap.

## Overview

**Note: This approach is specifically designed for Chef Infra Client 19 RC3 release.** Since Chef Infra Client 19 packages are not yet available through the standard Chef download API (omnitruck), this presigned URL method enables customers to test and deploy the RC3 release before general availability.

The scripts in this directory provide a secure installation method for Chef Infra Client 19 RC3 using AWS S3 presigned URLs. This approach is essential for the RC3 release and is also ideal for:

- **RC3 Testing**: Early access to Chef Infra Client 19 features before GA
- **Pre-release Validation**: Testing in staging environments
- Air-gapped environments
- Enterprise networks with restricted internet access
- Private Chef Infra Client distributions
- Controlled software deployment pipelines

## Why Presigned URLs for RC3?

Chef Infra Client 19 is currently in RC3 (Release Candidate 3) status, which means:

1. **Pre-GA Availability**: The packages are not yet available through the standard Chef download API endpoints
2. **Limited Distribution**: RC3 packages are hosted in private S3 buckets with controlled access
3. **Testing Phase**: This enables customers to test Chef Infra Client 19 features before general availability
4. **Bootstrap Compatibility**: Allows existing knife bootstrap workflows to work with RC3 packages

Once Chef Infra Client 19 reaches General Availability (GA), the packages will be available through the standard omnitruck API, and the default bootstrap process will work without requiring presigned URLs.

## Scripts Description

### install.sh (Linux x86_64)

The `install.sh` script is designed for Linux systems and provides RC3-specific installation support for:

- **Debian/Ubuntu**: Uses `.deb` packages via `dpkg`
- **RHEL/CentOS/Fedora/SUSE**: Uses `.rpm` packages via `rpm`
- **Architecture**: x86_64 only
- **Download Methods**: curl, wget, fetch, or perl (automatic fallback)
- **Platform Detection**: Automatic OS and package type detection
- **RC3 Packages**: Configured with presigned URLs for Chef Infra Client 19 RC3

#### Key Features:
- Secure temporary directory creation
- Multiple download method fallbacks
- Package verification and installation
- Comprehensive error handling and reporting
- Support for HTTP proxy environments

### install.ps1 (Windows x64)

The `install.ps1` script is designed for Windows systems and provides RC3-specific installation support for:

- **Package Type**: MSI installer only
- **Architecture**: x64 systems
- **Security**: TLS 1.2 enforcement, Administrator privilege checking
- **Progress**: Download progress indication
- **Installation**: Silent MSI installation with proper error handling
- **RC3 Packages**: Configured with presigned URL for Chef Infra Client 19 RC3 MSI package

#### Key Features:
- Secure downloads with progress tracking
- MSI installer support with silent installation
- Administrator privilege validation
- Comprehensive error handling and logging
- Support for HTTP proxy environments
- PowerShell 3.0+ compatibility

## Presigned URL Configuration

Both scripts use presigned URLs that provide time-limited, authenticated access to Chef Infra Client 19 RC3 packages stored in AWS S3. Since these packages are not available through the standard Chef download API, presigned URLs are the only way to access RC3 packages for testing and early deployment.

### Required Presigned URLs for RC3

#### For install.sh (Linux):
```bash
# Debian/Ubuntu package (RC3)
deb_presigned_url="https://workstation-rc3-assets.s3.us-east-1.amazonaws.com/chef-ice-19.1.x_amd64.deb?[presigned-parameters]"

# RHEL/CentOS/Fedora package (RC3)
rpm_presigned_url="https://workstation-rc3-assets.s3.us-east-1.amazonaws.com/chef-ice-19.1.x.x86_64.rpm?[presigned-parameters]"
```

#### For install.ps1 (Windows):
```powershell
# MSI installer (RC3)
$msi_presigned_url = "https://workstation-rc3-assets.s3.us-east-1.amazonaws.com/chef-ice-19.1.x-x64.msi?[presigned-parameters]"
```

**Important**: Ensure URL encoding is preserved, especially forward slashes (`/`) in the credential parameter.

## Using with Knife Bootstrap for RC3

### Linux Node Bootstrap with RC3

Use the `--bootstrap-url` parameter to specify the presigned URL for the RC3 install.sh script:

```bash
knife bootstrap linux ssh TARGET_HOST \
  --ssh-user USERNAME \
  --ssh-password PASSWORD \
  --bootstrap-url "https://workstation-rc3-assets.s3.us-east-1.amazonaws.com/install.sh?[presigned-parameters]" \
  --node-name NODE_NAME \
  --run-list "recipe[cookbook::recipe]"
```

Example with key-based authentication for RC3:
```bash
knife bootstrap linux ssh 10.0.1.100 \
  --ssh-user ubuntu \
  --ssh-identity-file ~/.ssh/my-key.pem \
  --bootstrap-url "https://workstation-rc3-assets.s3.us-east-1.amazonaws.com/install.sh?X-Amz-Algorithm=AWS4-HMAC-SHA256&..." \
  --node-name web-server-01-rc3 \
  --run-list "recipe[nginx]"
```

### Windows Node Bootstrap with RC3

Use the `--bootstrap-url` parameter to specify the presigned URL for the RC3 install.ps1 script:

```bash
knife bootstrap windows winrm TARGET_HOST \
  --winrm-user USERNAME \
  --winrm-password PASSWORD \
  --bootstrap-url "https://workstation-rc3-assets.s3.us-east-1.amazonaws.com/install.ps1?[presigned-parameters]" \
  --node-name NODE_NAME \
  --run-list "recipe[cookbook::recipe]"
```

Example with domain authentication for RC3:
```bash
knife bootstrap windows winrm 10.0.1.200 \
  --winrm-user "DOMAIN\\username" \
  --winrm-password "password" \
  --bootstrap-url "https://workstation-rc3-assets.s3.us-east-1.amazonaws.com/install.ps1?X-Amz-Algorithm=AWS4-HMAC-SHA256&..." \
  --node-name app-server-01-rc3 \
  --run-list "recipe[iis]"
```

### Security Considerations

1. **URL Expiration**: Set appropriate expiration times for presigned URLs
2. **Access Control**: Ensure S3 bucket has proper IAM policies
3. **Network Security**: Use HTTPS for all communications
4. **Audit Logging**: Enable CloudTrail for S3 access logging
5. **URL Protection**: Avoid logging presigned URLs in plain text

## Troubleshooting

### Common Issues

1. **Expired URLs**: Regenerate presigned URLs if they expire
2. **Network Connectivity**: Verify target nodes can reach S3 endpoints
3. **Proxy Issues**: Configure proxy settings if required
4. **Permission Errors**: Ensure installation privileges on target nodes
5. **Package Conflicts**: Check for existing Chef installations

### Debug Information

Both scripts provide detailed error messages and support debugging:

**Linux**: Check `/tmp/install.sh.$$` directory for temporary files
**Windows**: Review PowerShell error output and Windows Event Logs

### Validation

Test the presigned URLs directly before using with knife bootstrap:

```bash
# Test Linux script
curl -O "https://your-bucket.s3.region.amazonaws.com/install.sh?[presigned-parameters]"
chmod +x install.sh
./install.sh

# Test Windows script (PowerShell)
Invoke-WebRequest -Uri "https://your-bucket.s3.region.amazonaws.com/install.ps1?[presigned-parameters]" -OutFile "install.ps1"
.\install.ps1
```

## Example Workflow for RC3

Complete workflow for setting up presigned URL-based bootstrap for Chef Infra Client 19 RC3:

1. **Obtain RC3 Access**: Get access to Chef Infra Client 19 RC3 packages through official channels
2. **Review Scripts**: Examine the provided install.sh and install.ps1 scripts with RC3 URLs
3. **Upload Scripts** (if needed): Store updated scripts in S3 with appropriate access controls
4. **Generate Script URLs**: Create presigned URLs for the RC3 installation scripts
5. **Bootstrap RC3 Nodes**: Use knife bootstrap with RC3 script URLs
6. **Test RC3 Features**: Validate Chef Infra Client 19 RC3 functionality
7. **Prepare for GA**: Plan migration to standard bootstrap process when GA is released

This RC3-specific approach enables early testing and validation of Chef Infra Client 19 features while maintaining enterprise security and deployment standards. Once the GA release is available through the standard Chef download API, customers can transition back to the default bootstrap process.

## Transition to GA

When Chef Infra Client 19 reaches General Availability:

1. **Standard Bootstrap**: Use default `knife bootstrap` without `--bootstrap-url`
2. **Omnitruck API**: Packages will be available through standard Chef download endpoints
3. **Automatic Updates**: Chef will handle package distribution through established channels
4. **Backward Compatibility**: Existing RC3 installations can be upgraded using standard Chef update processes
