#!/bin/bash
set -eu

echo "---"
echo "env:"
echo "  BUILD_TIMESTAMP: $(date +%Y-%m-%d_%H-%M-%S)"
echo "  CHEF_LICENSE_SERVER: http://hosted-license-service-lb-8000-606952349.us-west-2.elb.amazonaws.com:8000/"
echo "steps:"
echo ""

emit_linux_step() {
  platform="$1"

  if [[ "$platform" == *"-aarch64" ]]; then
    image="chefes/omnibus-toolchain-${platform%-aarch64}:3.0.39"
    queue="default-privileged-aarch64"
  else
    image="chefes/omnibus-toolchain-${platform}:3.0.39"
    queue="default-privileged"
  fi

  echo "- label: \"run-specs-$platform-ruby-3.4\""
  echo "  retry:"
  echo "    automatic:"
  echo "      limit: 1"
  echo "  agents:"
  echo "    queue: $queue"
  echo "  plugins:"
  echo "  - docker#v3.5.0:"
  echo "      image: $image"
  echo "      environment:"
  echo "        - FORCE_FFI_YAJL=ext"
  echo "        - CHEF_LICENSE=accept-no-persist"
  echo "        - CHEF_LICENSE_SERVER=http://hosted-license-service-lb-8000-606952349.us-west-2.elb.amazonaws.com:8000/"
  echo "      propagate-environment: true"
  echo "  commands:"
  echo "    - .expeditor/run_linux_tests.sh rake spec"
  echo "  timeout_in_minutes: 90"
}

linux_platforms=(
  "rocky-8"
  "rocky-8-aarch64"
  "rhel-9"
  "rhel-9-aarch64"
  "debian-11"
  "debian-11-aarch64"
  "rocky-9"
  "rocky-9-aarch64"
  "ubuntu-2204"
  "ubuntu-2204-aarch64"
)

for platform in "${linux_platforms[@]}"; do
  emit_linux_step "$platform"
done

echo "- label: \"cookstyle-ruby-3.4\""
echo "  retry:"
echo "    automatic:"
echo "      limit: 1"
echo "  agents:"
echo "    queue: default-privileged"
echo "  plugins:"
echo "  - docker#v3.5.0:"
echo "      image: ruby:3.4"
echo "      propagate-environment: true"
echo "  commands:"
echo "    - .expeditor/run_linux_tests.sh \"rake style\""
echo "  timeout_in_minutes: 90"

echo "- label: \"run-specs-windows-ruby-3.4\""
echo "  retry:"
echo "    automatic:"
echo "      limit: 1"
echo "  agents:"
echo "    queue: default-windows-2019-privileged"
echo "  plugins:"
echo "  - docker#v3.5.0:"
echo "      image: rubydistros/windows-2019:3.4"
echo "      shell:"
echo "      - powershell"
echo "      - \"-Command\""
echo "      environment:"
echo "        - FORCE_FFI_YAJL=ext"
echo "        - EXPIRE_CACHE=true"
echo "        - CHEF_LICENSE=accept-no-persist"
echo "        - CHEF_LICENSE_SERVER=http://hosted-license-service-lb-8000-606952349.us-west-2.elb.amazonaws.com:8000/"
echo "      propagate-environment: true"
echo "  commands:"
echo "    - powershell .expeditor/run_windows_tests.ps1 rake spec"
echo "  timeout_in_minutes: 90"
