#!/bin/bash
#
# This script runs a passed in command, but first setups up the bundler caching on the repo

set -ue

echo "--- Current gem sources"
gem source

export USER="root"
export LANG=C.UTF-8 LANGUAGE=C.UTF-8

export ARTIFACTORY_ENDPOINT="https://artifactory-internal.ps.chef.co/artifactory"
export ARTIFACTORY_USERNAME="REDACTED@chef.io"

echo "--- Adding Artifactory gem source"
gem source -a "${ARTIFACTORY_ENDPOINT}/api/gems/omnibus-gems-local" || true

echo "--- Installing dependencies"
bundle config --local path vendor/bundle
bundle install --jobs=7 --retry=3

echo "+++ Running bundle exec task"
bundle exec $@
