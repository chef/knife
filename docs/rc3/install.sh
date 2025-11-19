#!/bin/sh
# Chef Infra Client 19 Installer for Linux x86_64
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

# Presigned URLs for Chef Infra Client 19 packages
# These will be filled in with actual presigned URLs
deb_presigned_url="https://chef-hab-migration-tool-bucket.s3.amazonaws.com/Release-Candidate-3/chef-ice/19.2.RC3/linux/x86_64/chef-ice-19.2.rc3-linux.deb?AWSAccessKeyId=AKIAW4FPVFT6C42N3U6R&Signature=cmJmplCvrkVXK5MtqCmidrz3rds%3D&Expires=1776916085"
rpm_presigned_url="https://chef-hab-migration-tool-bucket.s3.amazonaws.com/Release-Candidate-3/chef-ice/19.2.RC3/linux/x86_64/chef-ice-19.2.rc3-linux.rpm?AWSAccessKeyId=AKIAW4FPVFT6C42N3U6R&Signature=FUbFKD2qMux2TBK7ltNPLuExQGk%3D&Expires=1776916329"

# helpers.sh
############
# This section has some helper functions to make life easier.
#
# Outputs:
# $tmp_dir: secure-ish temp directory that can be used during installation.
############

# Check whether a command exists - returns 0 if it does, 1 if it does not
exists() {
  if command -v $1 >/dev/null 2>&1
  then
    return 0
  else
    return 1
  fi
}

# Output the instructions to report bug about this script
report_bug() {
  echo ""
  echo "Please file a Bug Report at https://github.com/chef/knife/issues/new"
  echo "Please include as many details about the problem as possible i.e., how to reproduce"
  echo "the problem (if possible), type of the Operating System and its version, etc.,"
  echo "and any other relevant details that might help us with troubleshooting."
  echo ""
}

checksum_mismatch() {
  echo "Package checksum mismatch!"
  report_bug
  exit 1
}

unable_to_retrieve_package() {
  echo "Unable to retrieve a valid package!"
  report_bug
  echo "Download URL: $download_url"
  if test "x$stderr_results" != "x"; then
    echo "\nDEBUG OUTPUT FOLLOWS:\n$stderr_results"
  fi
  exit 1
}

unsupported_platform() {
  echo "This installer only supports Linux x86_64 systems"
  echo "Detected: $platform $platform_version on $machine"
  echo ""
  report_bug
  exit 1
}

capture_tmp_stderr() {
  # spool up /tmp/stderr from all the commands we called
  if test -f "$tmp_dir/stderr"; then
    output=`cat $tmp_dir/stderr`
    stderr_results="${stderr_results}\nSTDERR from $1:\n\n$output\n"
    rm $tmp_dir/stderr
  fi
}

# do_wget URL FILENAME
do_wget() {
  echo "trying wget..."
  wget --user-agent="Chef-Infra-19-Installer" -O "$2" "$1" 2>$tmp_dir/stderr
  rc=$?

  # check for bad return status or empty output
  if test $rc -ne 0 || test ! -s "$2"; then
    capture_tmp_stderr "wget"
    return 1
  fi

  return 0
}

# do_curl URL FILENAME
do_curl() {
  echo "trying curl..."
  curl -A "Chef-Infra-19-Installer" --retry 5 -sL -D $tmp_dir/stderr "$1" > "$2"
  rc=$?

  # check for bad return status or empty output
  if test $rc -ne 0 || test ! -s "$2"; then
    capture_tmp_stderr "curl"
    return 1
  fi

  return 0
}

# do_fetch URL FILENAME
do_fetch() {
  echo "trying fetch..."
  fetch --user-agent="Chef-Infra-19-Installer" -o "$2" "$1" 2>$tmp_dir/stderr
  # check for bad return status
  test $? -ne 0 && return 1
  return 0
}

# do_perl URL FILENAME
do_perl() {
  echo "trying perl..."
  perl -e 'use LWP::Simple; getprint($ARGV[0]);' "$1" > "$2" 2>$tmp_dir/stderr
  rc=$?

  # check for bad return status or empty output
  if test $rc -ne 0 || test ! -s "$2"; then
    capture_tmp_stderr "perl"
    return 1
  fi

  return 0
}

# do_python URL FILENAME
do_python() {
  echo "trying python..."
  python -c "import sys,urllib2; sys.stdout.write(urllib2.urlopen(urllib2.Request(sys.argv[1], headers={ 'User-Agent': 'Chef-Infra-19-Installer' })).read())" "$1" > "$2" 2>$tmp_dir/stderr
  rc=$?

  # check for bad return status or empty output
  if test $rc -ne 0 || test ! -s "$2"; then
    capture_tmp_stderr "python"
    return 1
  fi
  return 0
}

# returns 0 if checksums match
do_checksum() {
  if exists sha256sum; then
    echo "Comparing checksum with sha256sum..."
    checksum=`sha256sum $1 | awk '{ print $1 }'`
    return `test "x$checksum" = "x$2"`
  elif exists shasum; then
    echo "Comparing checksum with shasum..."
    checksum=`shasum -a 256 $1 | awk '{ print $1 }'`
    return `test "x$checksum" = "x$2"`
  else
    echo "WARNING: could not find a valid checksum program, pre-install shasum or sha256sum in your O/S image to get validation..."
    return 0
  fi
}

# do_download URL FILENAME
do_download() {
  echo "downloading $1"
  echo "  to file $2"

  # we try all of these until we get success.
  if exists wget; then
    do_wget "$1" "$2" && return 0
  fi

  if exists curl; then
    do_curl "$1" "$2" && return 0
  fi

  if exists fetch; then
    do_fetch "$1" "$2" && return 0
  fi

  if exists perl; then
    do_perl "$1" "$2" && return 0
  fi

  if exists python; then
    do_python "$1" "$2" && return 0
  fi

  unable_to_retrieve_package
}

# install_file TYPE FILENAME
# TYPE is "rpm" or "deb"
install_file() {
  echo "Installing Chef Infra Client 19"
  case "$1" in
    "rpm")
      echo "installing with rpm..."
      rpm -Uvh --oldpackage --replacepkgs "$2"
      ;;
    "deb")
      echo "installing with dpkg..."
      dpkg -i "$2"
      ;;
    *)
      echo "Unknown filetype: $1"
      echo "This installer only supports RPM and DEB packages on Linux x86_64"
      report_bug
      exit 1
      ;;
  esac
  if test $? -ne 0; then
    echo "Installation failed"
    report_bug
    exit 1
  fi
}

if test "x$TMPDIR" = "x"; then
  tmp="/tmp"
else
  tmp=$TMPDIR
fi
# secure-ish temp dir creation without having mktemp available (DDoS-able but not exploitable)
tmp_dir="$tmp/install.sh.$$"
(umask 077 && mkdir $tmp_dir) || exit 1

############
# end of helpers.sh
############

# Check for required presigned URLs
if test "x$deb_presigned_url" = "x" || test "x$rpm_presigned_url" = "x"; then
  echo "ERROR: Presigned URLs not configured"
  echo "Please set deb_presigned_url and rpm_presigned_url variables in this script"
  exit 1
fi

# platform_detection.sh
############
# This section detects Linux distribution and architecture
#
# Outputs:
# $platform: Name of the platform (linux only).
# $platform_version: Version of the platform.
# $machine: System's architecture (must be x86_64).
# $package_type: Either "deb" or "rpm" based on the distribution.
############

machine=`uname -m`
os=`uname -s`

# Only support Linux x86_64
if test "$os" != "Linux"; then
  echo "ERROR: This installer only supports Linux systems"
  echo "Detected OS: $os"
  unsupported_platform
fi

if test "$machine" != "x86_64"; then
  echo "ERROR: This installer only supports x86_64 architecture"
  echo "Detected architecture: $machine"
  unsupported_platform
fi

platform="linux"
package_type=""

# Detect package manager type
if test -f "/etc/debian_version"; then
  # Debian/Ubuntu systems use DEB packages
  package_type="deb"
  platform_version=`cat /etc/debian_version`
elif test -f "/etc/redhat-release"; then
  # RHEL/CentOS/Fedora systems use RPM packages
  package_type="rpm"
  platform_version=`sed 's/^.\+ release \([.0-9]\+\).*/\1/' /etc/redhat-release`
elif test -f "/etc/system-release"; then
  # Amazon Linux and other systems use RPM packages
  package_type="rpm"
  platform_version=`sed 's/^.\+ release \([.0-9]\+\).*/\1/' /etc/system-release`
elif test -f "/etc/SuSE-release" || test -f "/etc/SUSE-brand"; then
  # SUSE systems use RPM packages
  package_type="rpm"
  if test -f "/etc/SuSE-release"; then
    platform_version=`head -1 /etc/SuSE-release | awk '{print $3}'`
  else
    platform_version="unknown"
  fi
else
  echo "ERROR: Unable to detect Linux distribution"
  echo "This installer supports Debian/Ubuntu (DEB) and RHEL/CentOS/Fedora/SUSE (RPM) based systems"
  unsupported_platform
fi

echo "Detected: Linux $platform_version ($machine) - Package type: $package_type"

############
# end of platform_detection.sh
############

# Set download URL based on package type
if test "$package_type" = "deb"; then
  download_url="$deb_presigned_url"
  filename="chef-infra-client_19_amd64.deb"
elif test "$package_type" = "rpm"; then
  download_url="$rpm_presigned_url"
  filename="chef-infra-client-19-1.x86_64.rpm"
else
  echo "ERROR: Unable to determine package type"
  unsupported_platform
fi

echo "Will download Chef Infra Client 19 ($package_type package)"
echo "From: $download_url"

# Set up download filename
download_filename="$tmp_dir/$filename"

# ensure the parent directory where we download the installer always exists
download_dir=`dirname $download_filename`
(umask 077 && mkdir -p $download_dir) || exit 1

# Download the package
do_download "$download_url" "$download_filename"

# Install the package
echo "Installing Chef Infra Client 19..."
install_file "$package_type" "$download_filename"

# Cleanup
if test "x$tmp_dir" != "x"; then
  rm -r "$tmp_dir"
fi

echo ""
echo "Chef Infra Client 19 installation completed successfully!"
echo ""