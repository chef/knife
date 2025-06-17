#!/bin/bash
#
# This script sets up bundler caching and runs a provided command using `bundle exec`.

set -ue

echo "--- Current gem sources"
gem source

export USER="root"
export LANG="C.UTF-8"
export LANGUAGE="C.UTF-8"

export ARTIFACTORY_ENDPOINT="https://artifactory-internal.ps.chef.co/artifactory"
export ARTIFACTORY_USERNAME="REDACTED@chef.io"

echo "--- Adding Artifactory gem source"
gem source -a "${ARTIFACTORY_ENDPOINT}/api/gems/omnibus-gems-local" || true

echo "--- Installing dependencies"
bundle config set --local path vendor/bundle
bundle install --jobs=7 --retry=3
gem update --system

echo "+++ Running bundle exec task"
RUBYOPT="-W0" bundle exec "$@"
