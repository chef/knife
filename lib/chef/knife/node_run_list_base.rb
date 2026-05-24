#
# Author:: Nikhil Gupta
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

require_relative "../knife"

class Chef
  class Knife
    module NodeRunListBase

      private

      # Normalises an array of run-list arguments into a flat list of entries.
      # Handles both space-separated arguments and comma-separated values within
      # a single argument, stripping surrounding whitespace from each entry.
      #
      # Examples:
      #   parse_run_list_entries(["role[web]"])            # => ["role[web]"]
      #   parse_run_list_entries(["role[web],recipe[ntp]"]) # => ["role[web]", "recipe[ntp]"]
      #   parse_run_list_entries(["role[web]", "recipe[ntp]"]) # => ["role[web]", "recipe[ntp]"]
      def parse_run_list_entries(args)
        args.flat_map { |entry| entry.split(",").map(&:strip) }
      end

    end
  end
end
