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
		if [ -r /etc/os-release ]; then
			. /etc/os-release
		fi

		DNF_OPTS="-y"
		if [ "${ID:-}" = "rocky" ] && dnf repolist all 2>/dev/null | grep -q '^devel'; then
			DNF_OPTS="$DNF_OPTS --enablerepo=devel"
		fi

		dnf install $DNF_OPTS \
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

setup_ruby_path() {
	if command -v ruby >/dev/null 2>&1 && command -v bundle >/dev/null 2>&1; then
		echo "--- ruby and bundle already available"
		return
	fi

	echo "--- setting up ruby path"
	
	# omnibus-toolchain images use rbenv; add shims early
	if [ -d "$HOME/.rbenv/shims" ]; then
		export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH"
		echo "--- added rbenv to PATH: $PATH"
	fi

	# Try to find and activate a ruby version
	if [ -d "$HOME/.rbenv" ] && command -v rbenv >/dev/null 2>&1; then
		# List available versions and select one if ruby still not found
		if ! command -v ruby >/dev/null 2>&1; then
			local latest_ruby
			latest_ruby=$(rbenv versions --bare 2>/dev/null | tail -n 1)
			if [ -n "$latest_ruby" ]; then
				echo "--- setting rbenv global to $latest_ruby"
				rbenv global "$latest_ruby" || true
			fi
		fi
	fi

	# Fallback to omnibus paths if rbenv didn't work
	if ! command -v ruby >/dev/null 2>&1; then
		for candidate in /opt/chef/bin /opt/chef/embedded/bin /opt/chef-workstation/embedded/bin; do
			if [ -x "$candidate/ruby" ]; then
				echo "--- found ruby at $candidate/ruby"
				export PATH="$candidate:$PATH"
				break
			fi
		done
	fi
}

install_dependencies
setup_ruby_path

echo "--- ruby version"
if ! command -v ruby >/dev/null 2>&1; then
	echo "ruby not found after setup; PATH=$PATH"
	exit 1
fi
ruby --version

if ! command -v bundle >/dev/null 2>&1; then
	echo "bundle not found after setup; PATH=$PATH"
	exit 1
fi

echo "--- bundle install"

bundle config --local path vendor/bundle
bundle install --jobs=7 --retry=3

echo "+++ bundle exec task"
bundle exec $@
