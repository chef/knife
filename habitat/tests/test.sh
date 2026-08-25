
set -euo pipefail


project_root="$(git rev-parse --show-toplevel)"
pkg_ident="$1"
# print error message followed by usage and exit
error () {
  local message="$1"

  echo -e "\nERROR: ${message}\n" >&2

  exit 1
}

[[ -n "$pkg_ident" ]] || error 'no hab package identity provided'

package_version=$(awk -F / '{print $3}' <<<"$pkg_ident")

cd "${project_root}"
echo "Testing ${pkg_ident} executables"
version=$(hab pkg exec "${pkg_ident}" knife -v)
echo $version
actual_version=$(echo "$version" | sed -E 's/.*version: ([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
echo $actual_version

if [[ "$actual_version" != *"$package_version"* ]]; then
  error "knife version is not the expected version. Expected '$package_version', got '$actual_version'"
fi

echo "Verifying bundled knife plugins are available"
plugin_checks=(
  "ec2:Available ec2 subcommands"
  "google:Available google subcommands"
  "windows:Available windows subcommands"
  "vcenter:Available vcenter subcommands"
)

for plugin_check in "${plugin_checks[@]}"; do
  plugin_name="${plugin_check%%:*}"
  expected_output="${plugin_check#*:}"

  output=$(hab pkg exec "${pkg_ident}" bash -c "knife ${plugin_name} 2>&1" || true)
  if echo "${output}" | grep -q "${expected_output}"; then
    echo "Plugin '${plugin_name}' is available"
  else
    echo -e "\nERROR: knife plugin '${plugin_name}' is not available in package '${pkg_ident}'\n" >&2
    exit 1
  fi
done
echo "All bundled plugins verified successfully"
