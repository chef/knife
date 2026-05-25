# frozen_string_literal: true
#
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

autoload :FFI_Yajl, "ffi_yajl"
require "chef-config/path_helper" unless defined?(ChefConfig::PathHelper)
require "chef/data_bag_item" unless defined?(Chef::DataBagItem)
require "chef/log" unless defined?(Chef::Log)

class Chef
  class Knife
    module Core
      class ObjectLoader

        attr_reader :ui
        attr_reader :klass

        class ObjectType
          FILE = 1
          FOLDER = 2
        end

        def initialize(klass, ui)
          @klass = klass
          @ui = ui
        end

        def load_from(repo_location, *components)
          Chef::Log.trace("ObjectLoader: loading #{klass} from repo_location=#{repo_location} components=#{components.inspect}")
          unless (object_file = find_file(repo_location, *components))
            Chef::Log.trace("ObjectLoader: could not resolve '#{components.last}' under #{repo_location}")
            ui.error "Could not find or open file '#{components.last}' in current directory or in '#{repo_location}/#{components.join("/")}'"
            exit 1
          end
          object_from_file(object_file)
        end

        # When someone makes this awesome, please update the above error message.
        def find_file(repo_location, *components)
          absolute = File.expand_path(components.last)
          if file_exists_and_is_readable?(absolute)
            Chef::Log.trace("ObjectLoader: resolved '#{components.last}' as absolute path #{absolute}")
            absolute
          else
            relative_path = File.join(Dir.pwd, repo_location, *components)
            if file_exists_and_is_readable?(relative_path)
              Chef::Log.trace("ObjectLoader: resolved '#{components.last}' as relative path #{relative_path}")
              relative_path
            else
              nil
            end
          end
        end

        # Find all objects in the given location
        # If the object type is File it will look for all *.{json,rb}
        # files, otherwise it will lookup for folders only (useful for
        # data_bags)
        #
        # @param [String] path - base look up location
        #
        # @return [Array<String>] basenames of the found objects
        #
        # @api public
        def find_all_objects(path)
          path = File.join(ChefConfig::PathHelper.escape_glob_dir(File.expand_path(path)), "*")
          path << ".{json,rb}"
          objects = Dir.glob(path)
          objects.map { |o| File.basename(o) }
        end

        def find_all_object_dirs(path)
          path = File.join(ChefConfig::PathHelper.escape_glob_dir(File.expand_path(path)), "*")
          objects = Dir.glob(path)
          objects.delete_if { |o| !File.directory?(o) }
          objects.map { |o| File.basename(o) }
        end

        def object_from_file(filename)
          Chef::Log.trace("ObjectLoader: parsing #{filename}")
          case filename
          when /\.(js|json)$/
            Chef::Log.trace("ObjectLoader: using JSON parser for #{filename}")
            r = FFI_Yajl::Parser.parse(File.read(filename))

            # Chef::DataBagItem doesn't work well with the json_create method
            if @klass == Chef::DataBagItem
              r
            else
              @klass.from_hash(r)
            end
          when /\.rb$/
            Chef::Log.trace("ObjectLoader: using Ruby eval for #{filename}")
            r = klass.new
            r.from_file(filename)
            r
          else
            ui.fatal("File must end in .js, .json, or .rb")
            exit 30
          end
        end

        def file_exists_and_is_readable?(file)
          File.exist?(file) && File.readable?(file)
        end

      end
    end
  end
end
