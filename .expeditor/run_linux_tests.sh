#!/bin/bash
#
# This script runs a passed in command, but first setups up the bundler caching on the repo

set -ue

export USER="root"
export LANG=C.UTF-8 LANGUAGE=C.UTF-8

install_dependencies() {
	if command -v apt-get >/dev/null 2>&1; then
		echo "--- installing native dependencies via apt-get"
		apt-get update -y
		DEBIAN_FRONTEND=noninteractive apt-get install -y \
			build-essential \
			git \
			libarchive-dev \
			libffi-dev \
			libssl-dev \
			libyaml-dev \
			pkg-config \
			zlib1g-dev
	elif command -v dnf >/dev/null 2>&1; then
		echo "--- installing native dependencies via dnf"
		dnf clean metadata
		dnf install -y --enablerepo=devel \
			gcc \
			gcc-c++ \
			git \
			libarchive-devel \
			libffi-devel \
			libyaml-devel \
			make \
			openssl-devel \
			readline-devel \
			zlib-devel
	elif command -v yum >/dev/null 2>&1; then
		echo "--- installing native dependencies via yum"
		yum install -y \
			gcc \
			gcc-c++ \
			git \
			libarchive-devel \
			libffi-devel \
			libyaml-devel \
			make \
			openssl-devel \
			readline-devel \
			zlib-devel
	else
		echo "--- no supported package manager found; continuing without dependency installation"
	fi
}

install_dependencies

echo "--- bundle install"

bundle config --local path vendor/bundle
bundle install --jobs=7 --retry=3

echo "+++ bundle exec task"
bundle exec $@
