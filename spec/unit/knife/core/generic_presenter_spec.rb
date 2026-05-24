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

# Contract tests for Chef::Knife::Core::GenericPresenter
#
# These tests define the stable output contracts for the two most-used methods:
#   - format_list_for_display  (used by all knife *_list commands)
#   - format_for_display       (used by all knife *_show commands)
#
# If you intentionally change a contract, update the relevant example AND add a
# "Contract Change" section to the PR description. See ai-track-docs/contract-test.md.
#
# Rationale for each boundary tested is documented inline.
describe Chef::Knife::Core::GenericPresenter do
  let(:ui)        { double("UI") }
  let(:config)    { {} }
  let(:presenter) { described_class.new(ui, config) }

  # =========================================================================
  # Boundary A — format_list_for_display
  #
  # Contract: consumers of knife *_list commands expect a sorted array of
  # string keys by default. Passing --with-uri returns the original hash so
  # scripts can access URIs without a second API call.
  # =========================================================================
  describe "contract: format_list_for_display" do
    let(:sample_list) { { "zebra" => "http://z", "apple" => "http://a", "mango" => "http://m" } }

    context "default (no --with-uri)" do
      it "returns an array of keys sorted alphabetically" do
        # Rationale: all knife *_list commands pipe this into ui.output; scripts
        # that parse the output rely on alphabetical ordering being stable.
        expect(presenter.format_list_for_display(sample_list)).to eq(%w{apple mango zebra})
      end

      it "returns an empty array for an empty list" do
        # Rationale: no-data case must not raise — callers do not guard against nil.
        expect(presenter.format_list_for_display({})).to eq([])
      end
    end

    context "with config[:with_uri] = true" do
      let(:config) { { with_uri: true } }

      it "returns the raw hash unchanged" do
        # Rationale: scripts using --with-uri need the URI values; the hash
        # must not be transformed or sorted.
        expect(presenter.format_list_for_display(sample_list)).to eq(sample_list)
      end
    end
  end

  # =========================================================================
  # Boundary B — format_for_display
  #
  # Contract: the output shape depends on the combination of config flags.
  # Each branch is tested independently so any flag interaction regression
  # is immediately visible.
  # =========================================================================
  describe "contract: format_for_display" do
    let(:node_double) do
      double("node",
        name: "test-node",
        chef_environment: "production",
        run_list: double("run_list", run_list: ["role[web]"])
      )
    end

    context "no flags set (passthrough)" do
      it "returns the data object unchanged" do
        # Rationale: the default path must be zero-cost; callers pass the raw
        # API object and expect it back so ui.output can format it.
        data = { "id" => "x", "value" => 42 }
        expect(presenter.format_for_display(data)).to eq(data)
      end
    end

    context "config[:id_only] = true" do
      let(:config) { { id_only: true } }

      it "returns the name of an object that responds to :name" do
        # Rationale: --id-only mode is used for scripted enumeration;
        # consumers get a bare string, not a hash.
        expect(presenter.format_for_display(node_double)).to eq("test-node")
      end

      it "returns data['id'] for plain hashes" do
        data = { "id" => "hash-id", "extra" => "ignored" }
        expect(presenter.format_for_display(data)).to eq("hash-id")
      end
    end

    context "config[:environment] = true with an object that has chef_environment" do
      let(:config) { { environment: true } }

      it "returns {\"chef_environment\" => value}" do
        # Rationale: --environment flag filters output to just the env field;
        # the key name is part of the stable API contract (scripts parse it).
        expect(presenter.format_for_display(node_double)).to eq({ "chef_environment" => "production" })
      end
    end

    context "config[:attribute] set (subset extraction)" do
      let(:node_with_attrs) do
        double("node",
          name: "attr-node",
          respond_to?: true,
          public_send: nil
        ).tap do |n|
          allow(n).to receive(:respond_to?).with(:name).and_return(true)
          allow(n).to receive(:name).and_return("attr-node")
          allow(n).to receive(:respond_to?).with(:[], false).and_return(true)
          allow(n).to receive(:respond_to?).with(:key?).and_return(true)
          allow(n).to receive(:key?).with("platform").and_return(true)
          allow(n).to receive(:[]).with("platform").and_return("ubuntu")
          allow(n).to receive(:respond_to?).with(:to_hash).and_return(false)
        end
      end

      it "returns {name => {attr => value}} subset" do
        # Rationale: --attribute flag is used for scripted extraction of a
        # single field; the returned shape {name => {attr => val}} is stable.
        config[:attribute] = ["platform"]
        result = presenter.format_for_display(node_with_attrs)
        expect(result).to eq({ "attr-node" => { "platform" => "ubuntu" } })
      end
    end

    context "config[:run_list] set" do
      let(:config) { { run_list: true } }

      it "returns {name => {\"run_list\" => [...]}} subset" do
        # Rationale: --run-list flag has a stable output shape used by automation
        # that reads run lists programmatically.
        result = presenter.format_for_display(node_double)
        expect(result).to eq({ "test-node" => { "run_list" => ["role[web]"] } })
      end
    end
  end

  # =========================================================================
  # Boundary C — format_data_subset_for_display edge cases
  #
  # Rationale: the method raises ArgumentError when called with no valid flag.
  # This is an explicit contract — callers must set at least one of :attribute,
  # :run_list, or :id_only before calling format_for_display with complex data.
  # =========================================================================
  describe "contract: format_data_subset_for_display raises on bad config" do
    let(:config) { { attribute: nil, run_list: nil } }

    it "raises ArgumentError when neither :attribute nor :run_list is set" do
      # Rationale: silent nil returns here would produce empty output with no
      # error, which is harder to diagnose than a clear ArgumentError.
      data = double("data", name: "n", respond_to?: true)
      allow(data).to receive(:respond_to?).with(:name).and_return(true)
      allow(data).to receive(:name).and_return("n")
      expect { presenter.send(:format_data_subset_for_display, data) }
        .to raise_error(ArgumentError, /requires attribute, run_list, or id_only/)
    end
  end

  # =========================================================================
  # Boundary D — extract_nested_value edge cases
  #
  # Rationale: dot-separated attribute paths are parsed at runtime; a nil
  # intermediate value must return nil (not raise NoMethodError).
  # =========================================================================
  describe "contract: extract_nested_value" do
    let(:data) { { "a" => { "b" => "deep" }, "arr" => ["zero", "one"] } }

    it "returns a deeply nested value for a dot-separated path" do
      expect(presenter.send(:extract_nested_value, data, "a.b")).to eq("deep")
    end

    it "returns nil when an intermediate key is missing" do
      # Rationale: users typo attribute paths; nil return is preferable to crash.
      expect(presenter.send(:extract_nested_value, data, "a.missing.leaf")).to be_nil
    end

    it "returns the element at a numeric index for arrays" do
      expect(presenter.send(:extract_nested_value, data, "arr.1")).to eq("one")
    end
  end
end
