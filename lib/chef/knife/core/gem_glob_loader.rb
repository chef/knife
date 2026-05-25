# frozen_string_literal: true
# Author:: Christopher Brown (<cb@chef.io>)
# Author:: Daniel DeLeo (<dan@chef.io>)
# Copyright:: Copyright (c) 2009-2026 Progress Software Corporation and/or its subsidiaries or affiliates. All Rights Reserved.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require_relative "../version"
require "chef-config/path_helper" unless defined?(ChefConfig::PathHelper)
require "chef/log" unless defined?(Chef::Log)
class Chef
  class Knife
    class SubcommandLoader
      class GemGlobLoader < Chef::Knife::SubcommandLoader
        MATCHES_CHEF_GEM ||= %r{/chef-\d+\.\d+\.\d+}
        MATCHES_THIS_CHEF_GEM ||= %r{/chef-#{Chef::VERSION}(-\w+)?(-\w+)?/}

        def subcommand_files
          @subcommand_files ||= (gem_and_builtin_subcommands.values + site_subcommands).flatten.uniq
        end

        # Returns a Hash of paths to knife commands built-in to chef, or installed via gem.
        # If rubygems is not installed, falls back to globbing the knife directory.
        # The Hash is of the form {"relative/path" => "/absolute/path"}
        #--
        # Note: the "right" way to load the plugins is to require the relative path, i.e.,
        #   require 'chef/knife/command'
        # but we're getting frustrated by bugs at every turn, and it's slow besides. So
        # subcommand loader has been modified to load the plugins by using Kernel.load
        # with the absolute path.
        def gem_and_builtin_subcommands
          require "rubygems" unless defined?(Gem)
          Chef::Log.trace("GemGlobLoader: discovering subcommands via RubyGems")
          find_subcommands_via_rubygems
        rescue LoadError
          Chef::Log.trace("GemGlobLoader: RubyGems unavailable, falling back to dirglob")
          result = find_subcommands_via_dirglob
          if loader_summary_enabled?
            Chef::Log.info("op=knife_loader_summary source=dirglob subcommands=#{result.size}")
          end
          result
        end

        def find_subcommands_via_rubygems
          files = find_files_latest_gems "chef/knife/*.rb"
          Chef::Log.trace("GemGlobLoader: found #{files.size} candidate subcommand file(s) via RubyGems")
          Chef::Log.trace("GemGlobLoader: KNIFE_LOADER_SUMMARY=#{ENV["KNIFE_LOADER_SUMMARY"].inspect}")
          version_file_match = /#{Regexp.escape(File.join("chef", "knife", "version"))}$/
          subcommand_files = {}
          skipped_count = 0
          files.each do |file|

            rel_path = file[/(.*)(#{Regexp.escape File.join("chef", "knife", "")}.*)\.rb/, 2]

            # When not installed as a gem (ChefDK/appbundler in particular), AND
            # a different version of Chef is installed via gems, `files` will
            # include some files from the 'other' Chef install. If this contains
            # a knife command that doesn't exist in this version of Chef, we will
            # get a LoadError later when we try to require it.
            if from_different_chef_version?(file)
              Chef::Log.trace("GemGlobLoader: skipping #{file} (different Chef version)")
              skipped_count += 1
              next
            end

            # Exclude knife/chef/version. It's not a knife command, and  force-loading
            # when we load all of these files will emit constant-already-defined warnings
            next if rel_path&.match?(version_file_match)

            subcommand_files[rel_path] = file
          end

          result = subcommand_files.merge(find_subcommands_via_dirglob)
          if loader_summary_enabled?
            Chef::Log.info("op=knife_loader_summary source=rubygems subcommands=#{result.size} skipped=#{skipped_count}")
          end
          result
        end

        private

        # Returns true when the KNIFE_LOADER_SUMMARY environment variable is set
        # to any non-empty value. When enabled, a structured Chef::Log.info line
        # is emitted after subcommand discovery with source, count, and skipped totals.
        #
        # Toggle: export KNIFE_LOADER_SUMMARY=1
        # Default: OFF (unset) — silent, current behavior preserved.
        def loader_summary_enabled?
          ENV["KNIFE_LOADER_SUMMARY"].to_s != ""
        end

        def find_files_latest_gems(glob, check_load_path = true)
          files = []

          if check_load_path
            files = $LOAD_PATH.map do |load_path|
              Dir["#{File.expand_path glob, ChefConfig::PathHelper.escape_glob_dir(load_path)}#{Gem.suffix_pattern}"]
            end.flatten.select { |file| File.file? file }

          end

          gem_files = latest_gem_specs.map do |spec|
            # Gem::Specification#matches_for_glob wasn't added until RubyGems 1.8
            if spec.respond_to? :matches_for_glob
              spec.matches_for_glob("#{glob}#{Gem.suffix_pattern}")
            else
              check_spec_for_glob(spec, glob)
            end
          end.flatten

          files.concat gem_files
          files.uniq! if check_load_path

          files
        end

        def latest_gem_specs
          @latest_gem_specs ||= if Gem::Specification.respond_to? :latest_specs
                                  Gem::Specification.latest_specs(true) # find prerelease gems
                                else
                                  Gem.source_index.latest_specs(true)
                                end
        end

        def check_spec_for_glob(spec, glob)
          dirs = if spec.require_paths.size > 1
                   "{#{spec.require_paths.join(",")}}"
                 else
                   spec.require_paths.first
                 end

          glob = File.join(ChefConfig::PathHelper.escape_glob_dir(spec.full_gem_path, dirs), glob)

          Dir[glob]
        end

        def from_different_chef_version?(path)
          matches_any_chef_gem?(path) && !matches_this_chef_gem?(path)
        end

        def matches_any_chef_gem?(path)
          path =~ MATCHES_CHEF_GEM
        end

        def matches_this_chef_gem?(path)
          path =~ MATCHES_THIS_CHEF_GEM
        end
      end
    end
  end
end
