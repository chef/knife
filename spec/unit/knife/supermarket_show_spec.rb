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

describe Chef::Knife::SupermarketShow do
  let(:knife) { described_class.new }
  let(:noauth_rest) { double("noauth_rest") }
  let(:cookbook_data) { { "name" => "apache2", "maintainer" => "sous-chefs" } }

  before do
    allow(knife).to receive(:noauth_rest).and_return(noauth_rest)
    allow(knife).to receive(:sleep)
    allow(knife).to receive(:output)
    allow(knife).to receive(:format_for_display).and_return(cookbook_data)
    knife.config[:supermarket_site] = "https://supermarket.chef.io"
    knife.name_args = ["apache2"]
  end

  describe "#get_cookbook_data" do
    context "with a single name argument" do
      it "fetches the cookbook from the supermarket API" do
        expect(noauth_rest).to receive(:get)
          .with("https://supermarket.chef.io/api/v1/cookbooks/apache2")
          .and_return(cookbook_data)
        knife.get_cookbook_data
      end
    end

    context "with name and version arguments" do
      before { knife.name_args = ["apache2", "5.0.0"] }

      it "fetches the versioned cookbook from the supermarket API" do
        expect(noauth_rest).to receive(:get)
          .with("https://supermarket.chef.io/api/v1/cookbooks/apache2/versions/5_0_0")
          .and_return(cookbook_data)
        knife.get_cookbook_data
      end
    end

    context "resilience: transient network errors" do
      it "retries on Net::OpenTimeout and succeeds" do
        call_count = 0
        allow(noauth_rest).to receive(:get) do
          call_count += 1
          raise Net::OpenTimeout if call_count < 3

          cookbook_data
        end
        result = knife.get_cookbook_data
        expect(result).to eq(cookbook_data)
        expect(call_count).to eq(3)
      end

      it "retries on Net::ReadTimeout and succeeds" do
        call_count = 0
        allow(noauth_rest).to receive(:get) do
          call_count += 1
          raise Net::ReadTimeout if call_count < 2

          cookbook_data
        end
        result = knife.get_cookbook_data
        expect(result).to eq(cookbook_data)
        expect(call_count).to eq(2)
      end

      it "re-raises after exhausting retries" do
        allow(noauth_rest).to receive(:get).and_raise(Errno::ECONNRESET)
        expect { knife.get_cookbook_data }.to raise_error(Errno::ECONNRESET)
      end

      it "does not retry on non-transient errors" do
        call_count = 0
        allow(noauth_rest).to receive(:get) do
          call_count += 1
          raise ArgumentError, "bad url"
        end
        expect { knife.get_cookbook_data }.to raise_error(ArgumentError)
        expect(call_count).to eq(1)
      end
    end
  end
end
