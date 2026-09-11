#!/bin/bash
#
# This script runs a passed in command, but first setups up the bundler caching on the repo

set -ue

export USER="root"
export LANG=C.UTF-8 LANGUAGE=C.UTF-8

install_dependencies() {
	if command -v apt-get >/dev/null 2>&1; then
		echo "--- installing native dependencies via apt-get"

		# Debian 11 (bullseye) reached EOL on 2026-08-31. Its live
		# deb.debian.org / security.debian.org repos no longer publish
		# fresh Release files (causing "Release file ... is expired") and
		# their package indexes have drifted out of sync with each other,
		# leading to 404s and unmet-dependency version conflicts on
		# install. Scope a workaround to Debian 11 only: disable every
		# live repo definition (classic sources.list *and* deb822
		# sources.list.d/*.sources, regardless of host) and replace them
		# with an explicit, pinned, internally-consistent
		# snapshot.debian.org mirror. Other apt-based platforms (e.g.
		# Ubuntu) are untouched.
		local os_id="" os_version_id=""
		if [ -r /etc/os-release ]; then
			# shellcheck disable=SC1091
			. /etc/os-release
			os_id="${ID:-}"
			os_version_id="${VERSION_ID:-}"
		fi

		if [ "$os_id" = "debian" ] && [ "$os_version_id" = "11" ]; then
			echo "--- detected Debian 11 (bullseye, EOL); switching to snapshot.debian.org"

			# Pin to a snapshot taken shortly before bullseye's EOL date
			# so all three components (main/security/updates) are
			# guaranteed to be internally consistent with each other.
			local snapshot_ts="20260824T000000Z"

			# Disable any live repo definitions, in whatever form/location
			# they exist, instead of relying on a specific commented-out
			# line being present.
			if [ -f /etc/apt/sources.list ]; then
				sed -i -E \
					's~^deb(-src)? https?://(deb|security)\.debian\.org/.*~# &~' \
					/etc/apt/sources.list
			fi
			if [ -d /etc/apt/sources.list.d ]; then
				for f in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
					[ -e "$f" ] || continue
					if grep -Eq 'https?://(deb|security)\.debian\.org' "$f" 2>/dev/null; then
						mv "$f" "$f.disabled"
					fi
				done
			fi

			# Write an explicit, known-good snapshot source rather than
			# assuming the image already ships one to uncomment.
			cat >/etc/apt/sources.list.d/debian-11-eol-snapshot.list <<-EOF
			deb http://snapshot.debian.org/archive/debian/${snapshot_ts} bullseye main
			deb http://snapshot.debian.org/archive/debian-security/${snapshot_ts} bullseye-security main
			deb http://snapshot.debian.org/archive/debian/${snapshot_ts} bullseye-updates main
			EOF

			apt-get update -y -o Acquire::Check-Valid-Until=false
		else
			apt-get update -y
		fi

		DEBIAN_FRONTEND=noninteractive apt-get install -y \
			build-essential \
			curl \
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

		# Try default repos first to avoid Rocky devel conflicts.
		if ! dnf install -y \
			gcc \
			gcc-c++ \
			git \
			libarchive-devel \
			libffi-devel \
			libyaml-devel \
			make \
			openssl-devel \
			readline-devel \
			zlib-devel; then
			if [ "${ID:-}" = "rocky" ] && dnf repolist all 2>/dev/null | grep -q '^devel'; then
				echo "--- retrying dnf install with rocky devel repo enabled"
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
			else
				echo "dnf dependency installation failed and no safe fallback repo was available"
				exit 1
			fi
		fi
	elif command -v yum >/dev/null 2>&1; then
		echo "--- installing native dependencies via yum"
		yum install -y \
			curl-minimal \
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

bootstrap_ruby_if_missing() {
	if command -v ruby >/dev/null 2>&1 && command -v bundle >/dev/null 2>&1; then
		return
	fi

	echo "--- bootstrapping ruby via rbenv"
	export HOME="${HOME:-/root}"

	if [ ! -d "$HOME/.rbenv" ]; then
		if ! command -v curl >/dev/null 2>&1; then
			echo "curl is required to install rbenv"
			exit 1
		fi
		curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash
	fi

	export RBENV_ROOT="$HOME/.rbenv"
	export PATH="$RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH"

	if ! command -v rbenv >/dev/null 2>&1; then
		echo "rbenv not found after installer; PATH=$PATH"
		exit 1
	fi

	set +e
	eval "$(rbenv init - bash)"
	set -e

	local ruby_version="${RUBY_VERSION:-3.4.8}"
	rbenv install -s "$ruby_version"
	rbenv global "$ruby_version"

	if ! command -v bundle >/dev/null 2>&1; then
		gem install bundler
		rbenv rehash || true
	fi
}

install_dependencies
setup_ruby_path
bootstrap_ruby_if_missing

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

# The "habitat" group (knife-ec2, knife-google, knife-windows, knife-vcenter)
# is only needed for Habitat packaging, which is validated by a separate
# pipeline (.expeditor/build.habitat.yml / habitat-test.pipeline.yml) and
# never runs through this script. `rake spec` does not exercise those gems.
# Installing them here unnecessarily pulls in knife-vcenter's rbvmomi ->
# nokogiri dependency chain, whose precompiled native gem requires a newer
# glibc than Rocky Linux 8 / RHEL 8 (glibc 2.28) ships, causing:
#   GLIBC_2.29' not found (required by .../nokogiri.so)
# Skipping the group avoids installing nokogiri at all for spec runs.
bundle config --local path vendor/bundle
bundle config --local without habitat
bundle install --jobs=7 --retry=3

echo "+++ bundle exec task"
bundle exec $@
