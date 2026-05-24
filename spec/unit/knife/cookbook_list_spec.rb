#
# Author:: Thomas Bishop (<bishop.thomas@gmail.com>)
# Copyright:: Copyright 2011-2016, Thomas Bishop
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

describe Chef::Knife::CookbookList do
  before do
    @knife = Chef::Knife::CookbookList.new
    @rest_mock = double("rest")
    allow(@knife).to receive(:rest).and_return(@rest_mock)
    @cookbook_names = %w{apache2 mysql}
    @base_url = "https://server.example.com/cookbooks"
    @cookbook_data = {}
    @cookbook_names.each do |item|
      @cookbook_data[item] = { "url" => "#{@base_url}/#{item}",
                               "versions" => [{ "version" => "1.0.1",
                                                "url" => "#{@base_url}/#{item}/1.0.1" }] }
    end
    @stdout = StringIO.new
    allow(@knife.ui).to receive(:stdout).and_return(@stdout)
  end

  describe "run" do
    it "should display the latest version of the cookbooks" do
      expect(@rest_mock).to receive(:get).with("/cookbooks?num_versions=1")
        .and_return(@cookbook_data)
      @knife.run
      @cookbook_names.each do |item|
        expect(@stdout.string).to match(/#{item}:\s+1\.0\.1/)
      end
    end

    it "should query cookbooks for the configured environment" do
      @knife.config[:environment] = "production"
      expect(@rest_mock).to receive(:get)
        .with("/environments/production/cookbooks?num_versions=1")
        .and_return(@cookbook_data)
      @knife.run
    end

    describe "with -w or --with-uri" do
      it "should display the cookbook uris" do
        @knife.config[:with_uri] = true
        allow(@rest_mock).to receive(:get).and_return(@cookbook_data)
        @knife.run
        @cookbook_names.each do |item|
          pattern = /#{Regexp.escape(@cookbook_data[item]["versions"].first["url"])}/
          expect(@stdout.string).to match pattern
        end
      end
    end

    describe "with -a or --all" do
      before do
        @cookbook_names.each do |item|
          @cookbook_data[item]["versions"] << { "version" => "1.0.0",
                                                "url" => "#{@base_url}/#{item}/1.0.0" }
        end
      end

      it "should display all versions of the cookbooks" do
        @knife.config[:all_versions] = true
        expect(@rest_mock).to receive(:get).with("/cookbooks?num_versions=all")
          .and_return(@cookbook_data)
        @knife.run
        @cookbook_names.each do |item|
          expect(@stdout.string).to match(/#{item}:\s+1\.0\.1\s+1\.0\.0/)
        end
      end

      it "should query all versions scoped to the configured environment" do
        @knife.config[:all_versions] = true
        @knife.config[:environment] = "staging"
        expect(@rest_mock).to receive(:get)
          .with("/environments/staging/cookbooks?num_versions=all")
          .and_return(@cookbook_data)
        @knife.run
      end
    end

    describe "resilience: retry-with-backoff" do
      before { allow(@knife).to receive(:sleep) } # suppress delays

      it "retries once on Net::OpenTimeout then succeeds" do
        call_count = 0
        allow(@rest_mock).to receive(:get) do
          call_count += 1
          raise Net::OpenTimeout if call_count < 2

          @cookbook_data
        end
        @knife.run
        expect(call_count).to eq(2)
      end

      it "retries on Errno::ECONNRESET then succeeds" do
        call_count = 0
        allow(@rest_mock).to receive(:get) do
          call_count += 1
          raise Errno::ECONNRESET if call_count < 3

          @cookbook_data
        end
        @knife.run
        expect(call_count).to eq(3)
      end

      it "re-raises after all retries are exhausted" do
        allow(@rest_mock).to receive(:get).and_raise(Net::ReadTimeout)
        expect { @knife.run }.to raise_error(Net::ReadTimeout)
      end

      it "does not retry on non-transient errors" do
        call_count = 0
        allow(@rest_mock).to receive(:get) do
          call_count += 1
          raise RuntimeError, "unexpected"
        end
        expect { @knife.run }.to raise_error(RuntimeError)
        expect(call_count).to eq(1)
      end
    end

  end
end
