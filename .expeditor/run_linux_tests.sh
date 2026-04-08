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
	echo "--- activating ruby/rbenv"

	local rbenv_root=""
	local home_dir="${HOME:-}"

	# Buildkite docker jobs sometimes do not set HOME to /root.
	if [ -n "$home_dir" ] && [ -d "$home_dir/.rbenv" ]; then
		rbenv_root="$home_dir/.rbenv"
	elif [ -d "/root/.rbenv" ]; then
		rbenv_root="/root/.rbenv"
	fi

	if [ -n "$rbenv_root" ]; then
		export RBENV_ROOT="$rbenv_root"
		export PATH="$RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH"

		if command -v rbenv >/dev/null 2>&1; then
			set +e
			eval "$(rbenv init - bash)"
			set -e
		fi
	fi
}

install_dependencies
setup_ruby_path

echo "--- ruby version"
if ! command -v ruby >/dev/null 2>&1; then
	echo "ruby not found after setup; PATH=$PATH"
	echo "HOME=${HOME:-<unset>}"
	echo "RBENV_ROOT=${RBENV_ROOT:-<unset>}"
	if [ -d "/root/.rbenv" ]; then echo "/root/.rbenv exists"; fi
	if [ -n "${HOME:-}" ] && [ -d "${HOME}/.rbenv" ]; then echo "${HOME}/.rbenv exists"; fi
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
