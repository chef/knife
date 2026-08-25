export HAB_BLDR_CHANNEL="base-2025"
export HAB_REFRESH_CHANNEL="base-2025"

pkg_name=knife
pkg_origin=chef
ruby_pkg="core/ruby3_4"

# ruby_gem_version is set in do_before() once pkg_path_for is available.
# Declared here so it is in scope for all build functions.
ruby_gem_version=""

pkg_description="knife is a command-line tool that provides an interface between a local chef-repo and the Chef Infra Server."
pkg_deps=(${ruby_pkg} core/coreutils core/libarchive core/cacerts)
pkg_build_deps=(
  core/make
  core/sed
  core/clang
  core/cmake
)
pkg_bin_dirs=(bin)

do_setup_environment() {
  # vendor/ is where gem install places gems; vendor/ruby/$VERSION/ is where bundler places them
  push_runtime_env GEM_PATH "${pkg_prefix}/vendor"
  push_runtime_env GEM_PATH "${pkg_prefix}/vendor/ruby/${ruby_gem_version}"

  set_runtime_env APPBUNDLER_ALLOW_RVM "true"
  set_runtime_env LANG "en_US.UTF-8"
  set_runtime_env LC_CTYPE "en_US.UTF-8"
}

do_prepare() {
  build_line "Setting up build environment for native extensions"
  export PATH="$(pkg_path_for core/cmake)/bin:$(pkg_path_for core/make)/bin:$(pkg_path_for core/clang)/bin:$PATH"
  export CC="$(pkg_path_for core/clang)/bin/clang"
  export CXX="$(pkg_path_for core/clang)/bin/clang++"
}

pkg_version() {
  cat "$PLAN_CONTEXT/../../VERSION"
}

do_before() {
  update_pkg_version
  # Resolve the Ruby API version (e.g. 3.4.0) from the actual Habitat ruby binary.
  # Must be done here rather than at plan top-level because pkg_path_for is not
  # available until after package dependencies have been resolved.
  ruby_gem_version="$($(pkg_path_for ${ruby_pkg})/bin/ruby -e 'print RbConfig::CONFIG["ruby_version"]')"
  build_line "Resolved ruby_gem_version=${ruby_gem_version}"
}

do_unpack() {
  mkdir -pv "$HAB_CACHE_SRC_PATH/$pkg_dirname"
  cp -RT "$PLAN_CONTEXT"/../.. "$HAB_CACHE_SRC_PATH/$pkg_dirname/"
}

do_build() {
  cd "$HAB_CACHE_SRC_PATH/$pkg_dirname" || exit_with "unable to cd to source directory" 1

  export GEM_HOME="$pkg_prefix/vendor"
  export GEM_PATH="$GEM_HOME"
  export HOME="$HAB_CACHE_SRC_PATH/$pkg_dirname"
  export GEM_SPEC_CACHE="$HAB_CACHE_SRC_PATH/$pkg_dirname/.gem/specs"
  mkdir -p "$GEM_SPEC_CACHE"
  export PATH="$(pkg_path_for core/cmake)/bin:$(pkg_path_for core/make)/bin:$(pkg_path_for core/clang)/bin:$PATH"
  export CC="$(pkg_path_for core/clang)/bin/clang"
  export CXX="$(pkg_path_for core/clang)/bin/clang++"

  build_line "Building the Knife gem from the gemspec with GEM_HOME=$GEM_HOME and GEM_PATH=$GEM_PATH"
  bundle config set --local path "$GEM_HOME"
  bundle config --local without integration deploy maintenance development omnibus_package test
  bundle config --local with habitat
  bundle config --local jobs 4
  bundle config --local retry 5
  bundle config --local silence_root_warning 1
  bundle install

  gem build knife.gemspec

  # Set GEM_HOME to ruby version directory for cleanup script to find lint_roller gem
  export GEM_HOME="$pkg_prefix/vendor/ruby/${ruby_gem_version}"
  export GEM_PATH="$pkg_prefix/vendor"
  ruby ./scripts/cleanup_gem_lockfiles.rb
}

do_install() {
  cd "$HAB_CACHE_SRC_PATH/$pkg_dirname" || exit_with "unable to cd to source directory" 1

  # Copy NOTICE to the package directory
  if [[ -f "NOTICE" ]]; then
    build_line "Copying NOTICE to package directory"
    cp "NOTICE" "$pkg_prefix/"
  else
    build_line "Warning: NOTICE not found in source directory"
  fi

  export GEM_HOME="$pkg_prefix/vendor"
  export HOME="$HAB_CACHE_SRC_PATH/$pkg_dirname"
  export GEM_SPEC_CACHE="$HAB_CACHE_SRC_PATH/$pkg_dirname/.gem/specs"
  mkdir -p "$GEM_SPEC_CACHE"

  build_line "Setting GEM_PATH=$GEM_HOME"
  export GEM_PATH="$GEM_HOME"

  build_line "Installing the Knife gem"
  local knife_version=$(cat VERSION)
  # Use --ignore-dependencies: bundler already installed all runtime deps to
  # vendor/ruby/${ruby_gem_version}/ at Gemfile.lock-pinned versions.
  gem install "knife-${knife_version}.gem" --no-document --ignore-dependencies

  make_pkg_official_distrib

  build_line "** installing appbundler"
  gem install appbundler --no-document

  build_line "** generating binstubs for knife with precise version pins"
  # Expose both gem stores to appbundler: knife lives in vendor/ (gem install),
  # all its deps live in vendor/ruby/${ruby_gem_version}/ (bundler Gemfile.lock).
  GEM_HOME="$pkg_prefix/vendor" \
  GEM_PATH="$pkg_prefix/vendor:$pkg_prefix/vendor/ruby/${ruby_gem_version}" \
  "${pkg_prefix}/vendor/bin/appbundler" . "$pkg_prefix/bin" knife

  build_line "** patching binstubs to allow running directly"
  local patch_content
  patch_content=$(cat "${HAB_CACHE_SRC_PATH}/${pkg_dirname}/binstub_patch.rb")
  for binstub in ${pkg_prefix}/bin/*; do
    # Use awk to insert patch content after 'require "rubygems"' line
    awk -v patch="$patch_content" '/require "rubygems"/{print; print patch; next}1' "$binstub" > "${binstub}.tmp"
    mv "${binstub}.tmp" "$binstub"
  done

  if ! grep -q 'APPBUNDLER_ALLOW_RVM' "${pkg_prefix}/bin/knife"; then
    build_line "ERROR: binstub patch injection failed for ${pkg_prefix}/bin/knife"
    return 1
  fi

  build_line "** creating wrapper for runtime environment"
  mkdir -p "$pkg_prefix/libexec"
  mv "$pkg_prefix/bin/knife" "$pkg_prefix/libexec/knife"
  cat <<EOF > "$pkg_prefix/bin/knife"
#!/bin/bash
set -e
# GEM_HOME points to the bundler-managed gem tree (where 'chef' and Gemfile deps live)
export GEM_HOME="$pkg_prefix/vendor/ruby/${ruby_gem_version}"
# GEM_PATH includes the flat vendor tree (knife runtime deps), the standard user gem dir
# (~/.gem/ruby/VERSION), and the Chef gem dir (~/.chef/gems) so that plugins installed
# via 'gem install knife-<plugin>' or 'chef gem install knife-<plugin>' are found at
# runtime without any additional configuration.
# vendor/ruby/VERSION — bundler-managed gem tree (train-core and all runtime deps)
# vendor           — flat gem install tree (knife gem itself)
# ~/.gem/ruby/VERSION and ~/.chef/ruby/VERSION/gems — user-installed plugins
export GEM_PATH="$pkg_prefix/vendor:$pkg_prefix/vendor/ruby/${ruby_gem_version}:\${HOME}/.gem/ruby/${ruby_gem_version}:\${HOME}/.chef/ruby/${ruby_gem_version}/gems"
export DYLD_LIBRARY_PATH="$(pkg_path_for core/libarchive)/lib:\$DYLD_LIBRARY_PATH"
# SSL certificate verification - point OpenSSL to CA certificates
export SSL_CERT_FILE="$(pkg_path_for core/cacerts)/ssl/certs/cacert.pem"
export SSL_CERT_DIR="$(pkg_path_for core/cacerts)/ssl/certs"
exec $(pkg_path_for ${ruby_pkg})/bin/ruby $pkg_prefix/libexec/knife "\$@"
EOF
  chmod -v 755 "$pkg_prefix/bin/knife"

  build_line "** fixing binstub shebangs"
  fix_interpreter "${pkg_prefix}/libexec/*" "$ruby_pkg" bin/ruby

  rm -rf "$GEM_PATH/cache"
  rm -rf "$GEM_PATH/bundler"
  rm -rf "$GEM_PATH/doc"
  # Also clean the bundler-managed gem tree
  rm -rf "$pkg_prefix/vendor/ruby/${ruby_gem_version}/cache/"
  rm -rf "$pkg_prefix/vendor/ruby/${ruby_gem_version}/bundler/"
}

make_pkg_official_distrib() {
  # Test if artifactory-internal.ps.chef.co is reachable
  build_line "Testing connectivity to artifactory-internal.ps.chef.co..."
  artifactory_url="https://artifactory-internal.ps.chef.co/artifactory/omnibus-gems-local/"
  if curl --head --silent --fail --connect-timeout 30 "$artifactory_url" > /dev/null 2>&1; then
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
  find "$pkg_prefix/vendor" -type d -name ".github" -exec rm -rf {} + 2>/dev/null || true
}

do_strip() {
  return 0
}
