# frozen_string_literal: true
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

require "knife_spec_helper"

describe Chef::Knife::Core::TextFormatter do
  let(:ui) { double("ui", color: nil) }
  subject(:formatter) { described_class.new(data, ui) }

  before do
    allow(ui).to receive(:color) { |text, *_| text }
  end

  describe "#initialize data normalization" do
    context "when data responds to display_hash" do
      let(:obj) { double("displayable", display_hash: { "key" => "val" }) }
      let(:data) { obj }

      it "uses display_hash" do
        expect(formatter.data).to eq({ "key" => "val" })
      end
    end

    context "when data is an Array" do
      let(:data) { %w{a b c} }

      it "keeps the array as-is" do
        expect(formatter.data).to eq(%w{a b c})
      end
    end

    context "when data responds to to_hash" do
      let(:data) { { "x" => 1 } }

      it "converts via to_hash" do
        expect(formatter.data).to eq({ "x" => 1 })
      end
    end

    context "when data is a plain scalar" do
      let(:data) { "hello" }

      it "stores scalar directly" do
        expect(formatter.data).to eq("hello")
      end
    end
  end

  describe "#scalar?" do
    let(:data) { {} }

    it "returns true for a String" do
      expect(formatter.scalar?("word")).to be true
    end

    it "returns true for an Integer" do
      expect(formatter.scalar?(42)).to be true
    end

    it "returns true for nil" do
      expect(formatter.scalar?(nil)).to be true
    end

    it "returns false for an Array" do
      expect(formatter.scalar?([1, 2])).to be false
    end

    it "returns false for a Hash" do
      expect(formatter.scalar?({ "a" => "b" })).to be false
    end
  end

  describe "#is_singleton backward-compat alias" do
    let(:data) { {} }

    it "delegates to scalar?" do
      expect(formatter.is_singleton("x")).to eq(formatter.scalar?("x"))
      expect(formatter.is_singleton([1])).to eq(formatter.scalar?([1]))
    end
  end

  describe "#text_format" do
    context "with a Hash" do
      let(:data) { { "b" => "two", "a" => "one" } }

      it "sorts keys and formats as key: value lines" do
        result = formatter.text_format(data)
        expect(result).to include("a:")
        expect(result).to include("one")
        expect(result.index("a:")).to be < result.index("b:")
      end
    end

    context "with a Hash containing a single-element Array value" do
      let(:data) { { "key" => %w{only} } }

      it "unwraps the single-element array to a scalar" do
        result = formatter.text_format(data)
        expect(result).to include("only")
        expect(result).not_to include("[")
      end
    end

    context "with a Hash containing a nested Hash" do
      let(:data) { { "outer" => { "inner" => "val" } } }

      it "indents nested data" do
        result = formatter.text_format(data)
        expect(result).to match(/inner.*val/m)
        expect(result).to include("  ")
      end
    end

    context "with a flat Array of strings" do
      let(:data) { %w{alpha beta gamma} }

      it "formats each element on its own line" do
        result = formatter.text_format(data)
        expect(result).to include("alpha\n")
        expect(result).to include("beta\n")
        expect(result).to include("gamma\n")
      end
    end

    context "with an Array of Hashes" do
      let(:data) { [{ "a" => "1" }, { "b" => "2" }] }

      it "separates complex elements with blank lines" do
        result = formatter.text_format(data)
        expect(result).to include("\n\n")
      end
    end

    context "with a scalar" do
      let(:data) { "just a string" }

      it "appends a newline" do
        expect(formatter.text_format(data)).to eq("just a string\n")
      end
    end

    context "with an empty Hash" do
      let(:data) { {} }

      it "returns an empty string" do
        expect(formatter.text_format(data)).to eq("")
      end
    end
  end

  describe "#formatted_data" do
    let(:data) { { "name" => "web-01" } }

    it "memoizes the result" do
      result1 = formatter.formatted_data
      result2 = formatter.formatted_data
      expect(result1.object_id).to eq(result2.object_id)
    end

    it "returns a non-empty string for Hash data" do
      expect(formatter.formatted_data).to include("name")
    end
  end
end
