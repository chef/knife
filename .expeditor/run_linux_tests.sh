#!/bin/bash
#
# This script runs a passed in command, but first setups up the bundler caching on the repo

set -ue

export USER="root"
export LANG=C.UTF-8 LANGUAGE=C.UTF-8
echo "---- getting chef gem"
export ARTIFACTORY_BUILDKITE_TOKEN_PIPELINE="${ARTIFACTORY_BUILDKITE_TOKEN}"
export ARTIFACTORY_ENDPOINT="https://artifactory-internal.ps.chef.co/artifactory"
export ARTIFACTORY_USERNAME="buildkite"
ARTIFACTORY_TOKEN=$(vault kv get -field token account/static/artifactory/buildkite)
echo "--- gem source before add"
gem source
echo "--- gem source after add"
gem source -a https://buildkite:$ARTIFACTORY_TOKEN@artifactory-internal.ps.chef.co/artifactory/api/gems/omnibus-gems-local/
gem source
echo  "---- getting chef gem done"
echo "--- bundle install"

bundle config --local path vendor/bundle
bundle install --jobs=7 --retry=3

echo "+++ bundle exec task"
RUBYOPT="-W0" bundle exec $@
