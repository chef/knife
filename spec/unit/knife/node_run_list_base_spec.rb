#
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

require "knife_spec_helper"

describe Chef::Knife::NodeRunListBase do
  # Minimal test double that mixes in the module
  let(:host) do
    Class.new do
      include Chef::Knife::NodeRunListBase
      public :parse_run_list_entries
    end.new
  end

  describe "#parse_run_list_entries" do
    it "returns a single entry unchanged" do
      expect(host.parse_run_list_entries(["role[web]"])).to eq(["role[web]"])
    end

    it "splits a single comma-separated argument into multiple entries" do
      expect(host.parse_run_list_entries(["role[web],recipe[ntp]"])).to eq(%w{role[web] recipe[ntp]})
    end

    it "handles multiple space-separated arguments" do
      expect(host.parse_run_list_entries(["role[web]", "recipe[ntp]"])).to eq(%w{role[web] recipe[ntp]})
    end

    it "flattens mixed multi-arg and comma-separated values" do
      result = host.parse_run_list_entries(["role[web]", "recipe[ntp],role[db]"])
      expect(result).to eq(%w{role[web] recipe[ntp] role[db]})
    end

    it "strips surrounding whitespace from each entry" do
      expect(host.parse_run_list_entries(["role[web], recipe[ntp]"])).to eq(%w{role[web] recipe[ntp]})
    end

    it "returns an empty array for an empty input" do
      expect(host.parse_run_list_entries([])).to eq([])
    end

    it "ignores a trailing comma (Ruby split drops trailing empty tokens)" do
      result = host.parse_run_list_entries(["role[web],"])
      expect(result).to eq(["role[web]"])
    end
  end
end
