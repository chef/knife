#!/bin/bash
#
# This script runs a passed in command, but first setups up the bundler caching on the repo

set -ue


echo "--- gem source before add"
gem source

# Ensure unzip is installed
if ! command -v unzip &> /dev/null; then
  echo "--- installing unzip"
  apt-get update && apt-get install -y unzip
fi
# Install Vault if not present
if ! command -v vault &> /dev/null; then
  echo "--- installing vault"
  VAULT_VERSION="1.8.2"
  VAULT_ZIP="vault_${VAULT_VERSION}_linux_amd64.zip"
  curl -sSLo /tmp/$VAULT_ZIP https://releases.hashicorp.com/vault/${VAULT_VERSION}/$VAULT_ZIP
  unzip -o /tmp/$VAULT_ZIP -d /tmp
  mv /tmp/vault /usr/local/bin/
  rm /tmp/$VAULT_ZIP
fi
export USER="root"
export LANG=C.UTF-8 LANGUAGE=C.UTF-8
echo "---- getting chef gem"
# export ARTIFACTORY_BUILDKITE_TOKEN_PIPELINE="${ARTIFACTORY_BUILDKITE_TOKEN}"
export ARTIFACTORY_ENDPOINT="https://artifactory-internal.ps.chef.co/artifactory"
export ARTIFACTORY_USERNAME="REDACTED@chef.io"
ARTIFACTORY_TOKEN=$(vault kv get -field token account/static/artifactory/buildkite)
echo "--- gem source before add"
gem source
echo "--- gem source after add"
gem source -a https://artifactory-internal.ps.chef.co/artifactory/omnibus-gems-local/gems
echo  "---- getting chef gem done"
echo "--- bundle install"
bundle config --local set --local deployment 'true'
bundle install --system --gemfile=Gemfile --path vendor/bundle --without development test integration
echo "--- bundle install done"

bundle config --local path vendor/bundle
bundle install --jobs=7 --retry=3

echo "+++ bundle exec task"
RUBYOPT="-W0" bundle exec $@
