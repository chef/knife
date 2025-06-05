#!/bin/bash
#
# This script runs a passed in command, but first setups up the bundler caching on the repo

set -ue


echo "--- gem source before add"
gem source

export USER="root"
export LANG=C.UTF-8 LANGUAGE=C.UTF-8
echo "---- getting chef gem"
# export ARTIFACTORY_BUILDKITE_TOKEN_PIPELINE="${ARTIFACTORY_BUILDKITE_TOKEN}"
export ARTIFACTORY_ENDPOINT="https://artifactory-internal.ps.chef.co/artifactory"
export ARTIFACTORY_USERNAME="REDACTED@chef.io"
#ARTIFACTORY_TOKEN=$ARTIFACTORY_TOKEN
echo "--- gem source before add"
# List gem sources and remove trailing colons
gem source | sed 's/:$//'
echo "--- gem source after add"
gem source -a https://artifactory-internal.ps.chef.co/artifactory/api/gems/omnibus-gems-local
echo  "---- getting chef gem done"
echo "--- bundle install"
bundle config --local path vendor/bundle
bundle install --jobs=7 --retry=3
gem update --system --no-document
echo "--- bundle install done"

echo "+++ bundle exec task"
RUBYOPT="-W0" bundle exec $@
