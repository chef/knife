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

describe Chef::Knife::Core::StatusPresenter do
  describe "#summarize_json" do
    let(:presenter) { Chef::Knife::Core::StatusPresenter.new(double(:ui), double(:config, :[] => "")) }

    let(:node) do
      Chef::Node.new.tap do |n|
        n.automatic_attrs["name"] = "my_node"
        n.automatic_attrs["ipaddress"] = "127.0.0.1"
      end
    end

    let(:result) { JSON.parse(presenter.summarize_json([node])).first }

    it "uses the first of public_ipv4_addrs when present" do
      node.automatic_attrs["cloud"] = { "public_ipv4_addrs" => ["2.2.2.2"] }

      expect(result["ip"]).to eq("2.2.2.2")
    end

    it "falls back to ipaddress when public_ipv4_addrs is empty" do
      node.automatic_attrs["cloud"] = { "public_ipv4_addrs" => [] }

      expect(result["ip"]).to eq("127.0.0.1")
    end

    it "falls back to ipaddress when cloud attributes are empty" do
      node.automatic_attrs["cloud"] = {}

      expect(result["ip"]).to eq("127.0.0.1")
    end

    it "falls back to ipaddress when cloud attributes is not present" do
      expect(result["ip"]).to eq("127.0.0.1")
    end

    # ------------------------------------------------------------------
    # Contract tests — validate the guaranteed JSON shape of summarize_json.
    # These tests define the public API contract for consumers of
    # `knife status --format json`. If any of these fail after a code change,
    # update the golden file and this describe block intentionally and
    # document the breaking change in the PR. See ai-track-docs/contract-test.md.
    # ------------------------------------------------------------------
    describe "contract: summarize_json output schema" do
      # Controlled config: run_list and long_output explicitly off so the
      # contract tests cover the stable default output shape only.
      let(:contract_config) do
        cfg = double(:config)
        allow(cfg).to receive(:[]).and_return(nil)
        allow(cfg).to receive(:[]).with("run_list").and_return(false)
        allow(cfg).to receive(:[]).with(:run_list).and_return(false)
        allow(cfg).to receive(:[]).with(:long_output).and_return(false)
        cfg
      end
      let(:contract_presenter) { Chef::Knife::Core::StatusPresenter.new(double(:ui), contract_config) }

      let(:full_node) do
        Chef::Node.new.tap do |n|
          n.automatic_attrs["name"]             = "contract-node"
          n.automatic_attrs["chef_environment"] = "production"
          n.automatic_attrs["ohai_time"]        = 0
          n.automatic_attrs["ipaddress"]        = "10.0.0.1"
          n.automatic_attrs["fqdn"]             = "contract-node.example.com"
          n.automatic_attrs["platform"]         = "ubuntu"
          n.automatic_attrs["platform_version"] = "22.04"
        end
      end

      let(:full_result) { JSON.parse(contract_presenter.summarize_json([full_node])).first }

      it "returns valid JSON that parses to an Array" do
        raw = contract_presenter.summarize_json([full_node])
        parsed = JSON.parse(raw)
        expect(parsed).to be_a(Array)
      end

      it "always includes the required field: name (String)" do
        expect(full_result).to have_key("name")
        expect(full_result["name"]).to be_a(String)
      end

      it "always includes the required field: chef_environment" do
        expect(full_result).to have_key("chef_environment")
      end

      it "always includes the required field: ohai_time (Numeric)" do
        expect(full_result).to have_key("ohai_time")
        expect(full_result["ohai_time"]).to be_a(Numeric)
      end

      it "includes ip when ipaddress is present, using key 'ip' not 'ipaddress'" do
        expect(full_result).to have_key("ip")
        expect(full_result).not_to have_key("ipaddress")
      end

      it "includes fqdn when fqdn attribute is present, using key 'fqdn'" do
        expect(full_result).to have_key("fqdn")
      end

      it "includes platform when present" do
        expect(full_result).to have_key("platform")
        expect(full_result["platform"]).to eq("ubuntu")
      end

      it "includes platform_version when present" do
        expect(full_result).to have_key("platform_version")
        expect(full_result["platform_version"]).to eq("22.04")
      end

      it "omits ip when no ipaddress and no cloud data" do
        bare_node = Chef::Node.new.tap { |n| n.automatic_attrs["name"] = "bare" }
        result = JSON.parse(contract_presenter.summarize_json([bare_node])).first
        expect(result).not_to have_key("ip")
      end

      it "omits platform when not set" do
        bare_node = Chef::Node.new.tap { |n| n.automatic_attrs["name"] = "bare" }
        result = JSON.parse(contract_presenter.summarize_json([bare_node])).first
        expect(result).not_to have_key("platform")
      end

      it "matches the golden file snapshot" do
        golden_path = File.expand_path("../../../data/status_presenter_contract.json", __dir__)
        golden = JSON.parse(File.read(golden_path))
        actual = JSON.parse(contract_presenter.summarize_json([full_node]))
        expect(actual).to eq(golden)
      end
    end
  end
end
