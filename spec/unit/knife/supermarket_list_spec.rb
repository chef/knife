#
# Author:: Vivek Singh (<vivek.singh@msystechnologies.com>)
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

require "chef/knife/supermarket_list"
require "knife_spec_helper"

describe Chef::Knife::SupermarketList do
  let(:knife) { described_class.new }
  let(:noauth_rest) { double("no auth rest") }
  let(:stdout) { StringIO.new }
  let(:cookbooks_data) {
    [
    { "cookbook_name" => "1password", "cookbook_maintainer" => "jtimberman", "cookbook_description" => "Installs 1password", "cookbook" => "https://supermarket.chef.io/api/v1/cookbooks/1password" },
    { "cookbook_name" => "301", "cookbook_maintainer" => "markhuge", "cookbook_description" => "Installs/Configures 301", "cookbook" => "https://supermarket.chef.io/api/v1/cookbooks/301" },
    { "cookbook_name" => "3cx", "cookbook_maintainer" => "obay", "cookbook_description" => "Installs/Configures 3cx", "cookbook" => "https://supermarket.chef.io/api/v1/cookbooks/3cx" },
    { "cookbook_name" => "7dtd", "cookbook_maintainer" => "gregf", "cookbook_description" => "Installs/Configures the 7 Days To Die server", "cookbook" => "https://supermarket.chef.io/api/v1/cookbooks/7dtd" },
    { "cookbook_name" => "7-zip", "cookbook_maintainer" => "sneal", "cookbook_description" => "Installs/Configures the 7-zip file archiver", "cookbook" => "https://supermarket.chef.io/api/v1/cookbooks/7-zip" },
  ]
  }

  let(:response_text) {
    {
      "start" => 0,
      "total" => 5,
      "items" => cookbooks_data,
    }
  }

  describe "run" do
    before do
      allow(knife.ui).to receive(:stdout).and_return(stdout)
      allow(knife).to receive(:noauth_rest).and_return(noauth_rest)
      expect(noauth_rest).to receive(:get).and_return(response_text)
      knife.configure_chef
    end

    it "should display all supermarket cookbooks" do
      knife.run
      cookbooks_data.each do |item|
        expect(stdout.string).to match(/#{item["cookbook_name"]}\s/)
      end
    end

    describe "with -w or --with-uri" do
      it "should display the cookbook uris" do
        knife.config[:with_uri] = true
        knife.run
        cookbooks_data.each do |item|
          expect(stdout.string).to match(/#{item["cookbook_name"]}\s/)
          expect(stdout.string).to match(/#{item["cookbook"]}\s/)
        end
      end
    end
  end

  describe "pagination" do
    let(:first_page_data) {
      [
        { "cookbook_name" => "cookbook1", "cookbook_maintainer" => "user1", "cookbook_description" => "Test 1", "cookbook" => "https://supermarket.chef.io/api/v1/cookbooks/cookbook1" },
        { "cookbook_name" => "cookbook2", "cookbook_maintainer" => "user2", "cookbook_description" => "Test 2", "cookbook" => "https://supermarket.chef.io/api/v1/cookbooks/cookbook2" },
      ]
    }

    let(:second_page_data) {
      [
        { "cookbook_name" => "cookbook3", "cookbook_maintainer" => "user3", "cookbook_description" => "Test 3", "cookbook" => "https://supermarket.chef.io/api/v1/cookbooks/cookbook3" },
        { "cookbook_name" => "cookbook4", "cookbook_maintainer" => "user4", "cookbook_description" => "Test 4", "cookbook" => "https://supermarket.chef.io/api/v1/cookbooks/cookbook4" },
      ]
    }

    let(:third_page_data) {
      [
        { "cookbook_name" => "cookbook5", "cookbook_maintainer" => "user5", "cookbook_description" => "Test 5", "cookbook" => "https://supermarket.chef.io/api/v1/cookbooks/cookbook5" },
      ]
    }

    before do
      allow(knife.ui).to receive(:stdout).and_return(stdout)
      allow(knife).to receive(:noauth_rest).and_return(noauth_rest)
      knife.configure_chef
    end

    it "should handle pagination with multiple pages correctly" do
      # First page: 2 items, total is 5
      first_response = {
        "start" => 0,
        "total" => 5,
        "items" => first_page_data,
      }

      # Second page: 2 items, total is 5
      second_response = {
        "start" => 2,
        "total" => 5,
        "items" => second_page_data,
      }

      # Third page: 1 item, total is 5 (last page)
      third_response = {
        "start" => 4,
        "total" => 5,
        "items" => third_page_data,
      }

      # Verify that the API is called with correct parameters for each page
      expect(noauth_rest).to receive(:get)
        .with("https://supermarket.chef.io/api/v1/cookbooks?items=9999999&start=0")
        .and_return(first_response)
      expect(noauth_rest).to receive(:get)
        .with("https://supermarket.chef.io/api/v1/cookbooks?items=9999999&start=2")
        .and_return(second_response)
      expect(noauth_rest).to receive(:get)
        .with("https://supermarket.chef.io/api/v1/cookbooks?items=9999999&start=4")
        .and_return(third_response)

      result = knife.get_cookbook_list
      expect(result.keys).to eq(%w{cookbook1 cookbook2 cookbook3 cookbook4 cookbook5})
    end

    it "should calculate next_start correctly based on cr[\"items\"].length" do
      # When items returned is less than the items parameter, next_start should be based on actual items returned
      first_response = {
        "start" => 0,
        "total" => 3,
        "items" => first_page_data, # 2 items returned
      }

      second_response = {
        "start" => 2,
        "total" => 3,
        "items" => [third_page_data[0]], # 1 item in second page (last page)
      }

      expect(noauth_rest).to receive(:get)
        .with("https://supermarket.chef.io/api/v1/cookbooks?items=9999999&start=0")
        .and_return(first_response)
      expect(noauth_rest).to receive(:get)
        .with("https://supermarket.chef.io/api/v1/cookbooks?items=9999999&start=2")
        .and_return(second_response)

      result = knife.get_cookbook_list
      expect(result.length).to eq(3)
      expect(result.keys).to eq(%w{cookbook1 cookbook2 cookbook5})
    end

    it "should respect sort_by parameter across pages" do
      knife.config[:sort_by] = "recently_updated"

      first_response = {
        "start" => 0,
        "total" => 4,
        "items" => first_page_data,
      }

      second_response = {
        "start" => 2,
        "total" => 4,
        "items" => second_page_data[0..1], # Last 2 items
      }

      expect(noauth_rest).to receive(:get)
        .with("https://supermarket.chef.io/api/v1/cookbooks?items=9999999&start=0&order=recently_updated")
        .and_return(first_response)
      expect(noauth_rest).to receive(:get)
        .with("https://supermarket.chef.io/api/v1/cookbooks?items=9999999&start=2&order=recently_updated")
        .and_return(second_response)

      result = knife.get_cookbook_list
      expect(result.length).to eq(4)
    end

    it "should respect owned_by parameter across pages" do
      knife.config[:owned_by] = "testuser"

      first_response = {
        "start" => 0,
        "total" => 2,
        "items" => first_page_data,
      }

      expect(noauth_rest).to receive(:get)
        .with("https://supermarket.chef.io/api/v1/cookbooks?items=9999999&start=0&user=testuser")
        .and_return(first_response)

      result = knife.get_cookbook_list
      expect(result.length).to eq(2)
    end

    it "should handle single page result (no pagination needed)" do
      single_response = {
        "start" => 0,
        "total" => 2,
        "items" => first_page_data,
      }

      expect(noauth_rest).to receive(:get)
        .with("https://supermarket.chef.io/api/v1/cookbooks?items=9999999&start=0")
        .and_return(single_response)

      result = knife.get_cookbook_list
      expect(result.length).to eq(2)
    end

    it "should handle empty result" do
      empty_response = {
        "start" => 0,
        "total" => 0,
        "items" => [],
      }

      expect(noauth_rest).to receive(:get)
        .with("https://supermarket.chef.io/api/v1/cookbooks?items=9999999&start=0")
        .and_return(empty_response)

      result = knife.get_cookbook_list
      expect(result).to eq({})
    end

    it "should handle empty page in pagination (regression test for infinite loop)" do
      # This regression test ensures pagination stops when an empty page is returned,
      # preventing infinite recursion if the API returns empty items but total > start
      first_response = {
        "start" => 0,
        "total" => 4,
        "items" => first_page_data, # 2 items
      }

      # Second page returns empty items but total still indicates more results
      # This should NOT cause infinite recursion
      second_response = {
        "start" => 2,
        "total" => 4,
        "items" => [], # Empty array - the edge case
      }

      expect(noauth_rest).to receive(:get)
        .with("https://supermarket.chef.io/api/v1/cookbooks?items=9999999&start=0")
        .and_return(first_response)
      expect(noauth_rest).to receive(:get)
        .with("https://supermarket.chef.io/api/v1/cookbooks?items=9999999&start=2")
        .and_return(second_response)
      # Should only call the API twice, not infinitely

      result = knife.get_cookbook_list
      # Should return only the items from the first page
      expect(result.keys).to eq(%w{cookbook1 cookbook2})
      expect(result.length).to eq(2)
    end
  end
end
