#!/bin/bash
set -euo pipefail

pkg_ident="$1"

error () {
  local message="$1"
  echo -e "\nERROR: ${message}\n" >&2
  exit 1
}

[[ -n "$pkg_ident" ]] || error 'no hab package identity provided'

package_version=$(awk -F / '{print $3}' <<<"$pkg_ident")

# Get the installed package path
pkg_path=$(hab pkg path "$pkg_ident")

echo "Testing ${pkg_ident} executables at ${pkg_path}"

# Test knife version
version=$("${pkg_path}/bin/knife" -v)
echo "$version"
actual_version=$(echo "$version" | sed -E 's/.*version: ([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
echo "Detected version: $actual_version"

if [[ "$actual_version" != *"$package_version"* ]]; then
  error "knife version is not the expected version. Expected '$package_version', got '$actual_version'"
fi

echo "Verifying bundled knife plugins are available"
plugin_checks=(
  "ec2:Available ec2 subcommands"
  "google:Available google subcommands"
  "windows:Available windows subcommands"
)

for plugin_check in "${plugin_checks[@]}"; do
  plugin_name="${plugin_check%%:*}"
  expected_output="${plugin_check#*:}"

  output=$("${pkg_path}/bin/knife" "${plugin_name}" 2>&1 || true)
  if echo "${output}" | grep -q "${expected_output}"; then
    echo "Plugin '${plugin_name}' is available"
  else
    echo -e "\nERROR: knife plugin '${plugin_name}' is not available in package '${pkg_ident}'\n" >&2
    exit 1
  fi
done

echo "All bundled plugins verified successfully"
