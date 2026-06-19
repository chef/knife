
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
plugin_commands=(
  "ec2 server list"
  "google server list"
  "windows bootstrap"
)

for plugin_command in "${plugin_commands[@]}"; do
  if ! hab pkg exec "${pkg_ident}" bash -c "knife ${plugin_command} --help" >/dev/null 2>&1; then
    echo -e "\nERROR: knife plugin command '${plugin_command}' is not available in package '${pkg_ident}'\n" >&2
    exit 1
  fi
done
echo "All bundled plugins verified successfully"
