# Package metadata
export HAB_BLDR_CHANNEL="base-2025"
export HAB_REFRESH_CHANNEL="base-2025"
ruby_pkg="core/ruby3_4"

# Ruby version for gem directory structure
# NOTE: Bundler normalizes Ruby versions to major.minor.0 format for gem compatibility.
# Even if running Ruby 3.4.2, Bundler creates ruby/3.4.0 directory structure.
# This is standard behavior - gems built for 3.4.0 are compatible with 3.4.x patch versions.
ruby_gem_version="3.4.0"

pkg_name="knife"
pkg_origin="chef"
pkg_description="knife is a command-line tool that provides an interface between a local chef-repo and the Chef Infra Server."
pkg_upstream_url=https://www.chef.io/
pkg_maintainer="The Habitat Maintainers <humans@habitat.sh>"
pkg_license=('Apache-2.0')

# Package dependencies
pkg_deps=(
  ${ruby_pkg}
  core/coreutils
  core/bash
)

# Build dependencies
pkg_build_deps=(
  core/gcc
  core/make
  core/git
)

pkg_version() {
  cat "../VERSION"
}

do_before() {
  update_pkg_version
}

# Directories that contain executable binaries
pkg_bin_dirs=(bin)
pkg_svc_user=root

# Setup environment variables required for building the package
do_setup_environment() {
  # vendor/ is where gem install places gems; vendor/ruby/$VERSION/ is where bundler places them
  push_runtime_env GEM_PATH "${pkg_prefix}/vendor"
  push_runtime_env GEM_PATH "${pkg_prefix}/vendor/ruby/${ruby_gem_version}"

  set_runtime_env APPBUNDLER_ALLOW_RVM "true" # prevent appbundler from clearing out the carefully constructed runtime GEM_PATH
  set_runtime_env LANG "en_US.UTF-8"
  set_runtime_env LC_CTYPE "en_US.UTF-8"
}

do_prepare() {
  if [[ ! -f /usr/bin/env ]]; then
    ln -s "$(pkg_interpreter_for core/coreutils bin/env)" /usr/bin/env
  fi
}

# Unpack the source code into the Habitat cache path
do_unpack() {
  mkdir -pv "$HAB_CACHE_SRC_PATH/$pkg_dirname"
  cp -RT "$PLAN_CONTEXT"/.. "$HAB_CACHE_SRC_PATH/$pkg_dirname/"
}

# Build the Knife gem from its specification file
do_build() {
  export GEM_HOME="$pkg_prefix/vendor"
  export GEM_PATH="$GEM_HOME"
  build_line "Building the Knife gem from the gemspec with GEM_HOME=$GEM_HOME and GEM_PATH=$GEM_PATH"
  pushd "$HAB_CACHE_SRC_PATH/$pkg_dirname"
    bundle config set --local path "$GEM_HOME"
    bundle config --local without integration deploy maintenance development omnibus_package test
    bundle config --local jobs 4
    bundle config --local retry 5
    bundle config --local silence_root_warning 1
    bundle install

    gem build knife.gemspec

    # Set GEM_HOME to ruby version directory for cleanup script to find lint_roller gem
    export GEM_HOME="$pkg_prefix/vendor/ruby/${ruby_gem_version}"
    export GEM_PATH="$pkg_prefix/vendor"
    ruby ./scripts/cleanup_lint_roller.rb

  popd
}

# Install the built gem into the package directory
do_install() {

  # Copy NOTICE to the package directory
  if [[ -f "$PLAN_CONTEXT/../NOTICE" ]]; then
    build_line "Copying NOTICE to package directory"
    cp "$PLAN_CONTEXT/../NOTICE" "$pkg_prefix/"
  else
    build_line "Warning: NOTICE not found at $PLAN_CONTEXT/../NOTICE"
  fi

  export GEM_HOME="$pkg_prefix/vendor"

  build_line "Setting GEM_PATH=$GEM_HOME"
  export GEM_PATH="$GEM_HOME"

  build_line "Installing the Knife gem"
  pushd "$HAB_CACHE_SRC_PATH/$pkg_dirname"
    # Install the specific knife gem version that was just built to avoid conflicts
    # Use the VERSION file from the source directory since pkg_version() uses relative path
    local knife_version=$(cat VERSION)
    # Use --ignore-dependencies: bundler already installed all runtime deps to
    # vendor/ruby/${ruby_gem_version}/ at Gemfile.lock-pinned versions. Installing
    # deps again here would create a second gem store with potentially different
    # versions, causing appbundler's "ambiguous specs" warning.
    gem install "knife-${knife_version}.gem" --no-document --ignore-dependencies

    make_pkg_official_distrib

    build_line "** installing appbundler"
    gem install appbundler --no-document

    build_line "** generating binstubs for knife with precise version pins"
    # Expose both gem stores to appbundler: knife lives in vendor/ (gem install),
    # all its deps live in vendor/ruby/${ruby_gem_version}/ (bundler Gemfile.lock).
    # Each gem appears in exactly ONE store, so no version ambiguity.
    GEM_HOME="$pkg_prefix/vendor" \
    GEM_PATH="$pkg_prefix/vendor:$pkg_prefix/vendor/ruby/${ruby_gem_version}" \
    "${pkg_prefix}/vendor/bin/appbundler" . "$pkg_prefix/bin" knife
  popd

  build_line "** patching binstubs to allow running directly"
  for binstub in ${pkg_prefix}/bin/*; do
    sed -i "/require \"rubygems\"/r ${PLAN_CONTEXT}/../binstub_patch.rb" "$binstub"
  done

  build_line "** creating wrapper for runtime environment"
  mkdir -p "$pkg_prefix/libexec"
  mv "$pkg_prefix/bin/knife" "$pkg_prefix/libexec/knife"
  cat <<EOF > "$pkg_prefix/bin/knife"
#!$(pkg_path_for core/bash)/bin/bash
set -e
# GEM_HOME points to the bundler-managed gem tree (where 'chef' and Gemfile deps live)
export GEM_HOME="$pkg_prefix/vendor/ruby/${ruby_gem_version}"
# GEM_PATH also includes the flat vendor tree (where gem install puts knife runtime deps)
export GEM_PATH="$pkg_prefix/vendor"
exec $(pkg_path_for ${ruby_pkg})/bin/ruby $pkg_prefix/libexec/knife "\$@"
EOF
  chmod -v 755 "$pkg_prefix/bin/knife"

  build_line "** fixing binstub shebangs"
  fix_interpreter "${pkg_prefix}/libexec/*" "$ruby_pkg" bin/ruby

  rm -rf $GEM_PATH/cache/
  rm -rf $GEM_PATH/bundler
  rm -rf $GEM_PATH/doc
  # Also clean the bundler-managed gem tree
  rm -rf "$pkg_prefix/vendor/ruby/${ruby_gem_version}/cache/"
  rm -rf "$pkg_prefix/vendor/ruby/${ruby_gem_version}/bundler/"
}

make_pkg_official_distrib() {
  # Test if artifactory-internal.ps.chef.co is reachable
  build_line "Testing connectivity to artifactory-internal.ps.chef.co..."
  artifactory_url="https://artifactory-internal.ps.chef.co/artifactory/omnibus-gems-local/"
  if wget --spider --timeout=30 --tries=1 --quiet "$artifactory_url" > /dev/null 2>&1; then
    build_line "Artifactory is reachable, proceeding with chef-official-distribution installation"
    # Install to the Bundler-created ruby gem directory structure
    local install_dir="$GEM_HOME/ruby/${ruby_gem_version}"
    gem sources --add "$artifactory_url"
    gem install chef-official-distribution --no-document --install-dir "$install_dir"
    gem sources -r "$artifactory_url"

    build_line "Verifying chef-official-distribution installation"
    if ! GEM_HOME="$install_dir" GEM_PATH="$install_dir" gem list -i chef-official-distribution; then
      build_line "Error: chef-official-distribution installation failed"
      exit 1
    fi
  else
    build_line "Artifactory is not reachable, skipping chef-official-distribution installation"
  fi
}

do_after() {
  build_line "Removing .github directories from vendored gems..."
  # Search the full vendor tree: bundler places gems under vendor/ruby/$VERSION/gems/
  # (not vendor/gems/ which was the pre-Appbundler layout)
  find "$pkg_prefix/vendor" -type d -name ".github" -exec rm -rf {} + 2>/dev/null || true
}

do_strip() {
  return 0
}

do_end() {
  if [[ "$(readlink /usr/bin/env)" = "$(pkg_interpreter_for core/coreutils bin/env)" ]]; then
    build_line "Removing the symlink we created for '/usr/bin/env'"
    rm /usr/bin/env
  fi
}
