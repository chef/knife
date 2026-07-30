unless ENV["APPBUNDLER_ALLOW_RVM"]
  ENV["APPBUNDLER_ALLOW_RVM"] = "true"
end

# Prepend the package vendor dir, the current user's gem dir, and the Chef gem dir to
# GEM_PATH so that:
#   1. Knife's vendored dependencies are always found.
#   2. Knife plugins installed via `gem install knife-<plugin>` are discoverable on both
#      Linux (~/.gem/ruby/VERSION) and Windows (%USERPROFILE%\.gem\ruby\VERSION).
#   3. Gems installed via `chef gem install` (~/.chef/gems) are immediately available.
#
# This block runs before appbundler's env_sanitizer (which calls Gem.clear_paths and
# re-reads GEM_PATH from ENV), so these additions are always picked up correctly.
knife_vendor = File.expand_path(File.join(__dir__, "..", "vendor"))
# chef-cli gem install places gems under ~/.chef/ruby/RUBY_API_VERSION/gems
# (e.g. ~/.chef/ruby/3.4.0/gems). RbConfig::CONFIG["ruby_version"] returns the same
# API version string that Ruby/Bundler use for the gem directory layout.
chef_gem_dir = File.join(Dir.home, ".chef", "ruby", RbConfig::CONFIG["ruby_version"], "gems")
existing_paths = ENV["GEM_PATH"]&.split(File::PATH_SEPARATOR) || []
ENV["GEM_PATH"] = ([knife_vendor, Gem.user_dir, chef_gem_dir] + existing_paths).uniq.join(File::PATH_SEPARATOR)
