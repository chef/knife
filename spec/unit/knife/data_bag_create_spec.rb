#
# Author:: Daniel DeLeo (<dan@chef.io>)
# Author:: Seth Falcon (<seth@chef.io>)
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
require "tempfile"

describe Chef::Knife::DataBagCreate do
  let(:knife) do
    k = Chef::Knife::DataBagCreate.new
    allow(k).to receive(:rest).and_return(rest)
    allow(k.ui).to receive(:stdout).and_return(stdout)
    k
  end

  let(:rest) { double("Chef::ServerAPI") }
  let(:stdout) { StringIO.new }

  let(:bag_name) { "sudoing_admins" }
  let(:item_name) { "ME" }

  let(:secret) { "abc123SECRET" }

  let(:raw_hash) { { "login_name" => "alphaomega", "id" => item_name } }

  let(:config) { {} }

  before do
    Chef::Config[:node_name] = "webmonkey.example.com"
    knife.name_args = [bag_name, item_name]
    allow(knife).to receive(:config).and_return(config)
  end

  context "when data_bag already exists" do
    it "doesn't create a data bag" do
      expect(knife).to receive(:create_object).and_yield(raw_hash)
      expect(rest).to receive(:get).with("data/#{bag_name}")
      expect(rest).to_not receive(:post).with("data", { "name" => bag_name })
      expect(knife.ui).to receive(:info).with("Data bag #{bag_name} already exists")

      knife.run
    end
  end

  context "when data_bag doesn't exist" do
    before do
      # Data bag doesn't exist by default so we mock the GET request to return 404
      exception = double("404 error", code: "404")
      allow(rest).to receive(:get)
        .with("data/#{bag_name}")
        .and_raise(Net::HTTPClientException.new("404", exception))
    end

    it "tries to create a data bag with an invalid name when given one argument" do
      knife.name_args = ["invalid&char"]
      expect(Chef::DataBag).to receive(:validate_name!).with(knife.name_args[0]).and_raise(Chef::Exceptions::InvalidDataBagName)
      expect { knife.run }.to exit_with_code(1)
    end

    it "won't create a data bag with a reserved name for search" do
      %w{node role client environment}.each do |name|
        knife.name_args = [name]
        expect(Chef::DataBag).to receive(:validate_name!).with(knife.name_args[0]).and_raise(Chef::Exceptions::InvalidDataBagName)
        expect { knife.run }.to exit_with_code(1)
      end
    end

    context "when part of the name is a reserved name" do
      before do
        exception = double("404 error", code: "404")
        %w{node role client environment}.each do |name|
          allow(rest).to receive(:get)
            .with("data/sudoing_#{name}_admins")
            .and_raise(Net::HTTPClientException.new("404", exception))
        end
      end

      it "will create a data bag containing a reserved word" do
        %w{node role client environment}.each do |name|
          knife.name_args = ["sudoing_#{name}_admins"]
          expect(rest).to receive(:post).with("data", { "name" => knife.name_args[0] })
          expect(knife.ui).to receive(:info).with("Created data_bag[#{knife.name_args[0]}]")

          knife.run
        end
      end
    end

    context "when given one argument" do
      before do
        knife.name_args = [bag_name]
      end

      it "creates a data bag" do
        expect(rest).to receive(:post).with("data", { "name" => bag_name })
        expect(knife.ui).to receive(:info).with("Created data_bag[#{bag_name}]")

        knife.run
      end
    end

    context "when given a data bag name partially matching a reserved name for search" do
      %w{xnode rolex xenvironmentx xclientx}.each do |name|
        let(:bag_name) { name }

        before do
          knife.name_args = [bag_name]
        end

        it "creates a data bag named '#{name}'" do
          expect(rest).to receive(:post).with("data", { "name" => bag_name })
          expect(knife.ui).to receive(:info).with("Created data_bag[#{bag_name}]")

          knife.run
        end
      end
    end

    context "no secret is specified for encryption" do
      let(:item) do
        item = Chef::DataBagItem.from_hash(raw_hash)
        item.data_bag(bag_name)
        item
      end

      it "creates a data bag item" do
        expect(knife).to receive(:create_object).and_yield(raw_hash)
        expect(knife).to receive(:encryption_secret_provided?).and_return(false)
        expect(rest).to receive(:post).with("data", { "name" => bag_name }).ordered
        expect(rest).to receive(:post).with("data/#{bag_name}", item).ordered

        knife.run
      end
    end

    context "a secret is specified for encryption" do
      let(:encoded_data) { Chef::EncryptedDataBagItem.encrypt_data_bag_item(raw_hash, secret) }

      let(:item) do
        item = Chef::DataBagItem.from_hash(encoded_data)
        item.data_bag(bag_name)
        item
      end

      it "creates an encrypted data bag item" do
        expect(knife).to receive(:create_object).and_yield(raw_hash)
        expect(knife).to receive(:encryption_secret_provided?).and_return(true)
        expect(knife).to receive(:read_secret).and_return(secret)
        expect(Chef::EncryptedDataBagItem)
          .to receive(:encrypt_data_bag_item)
          .with(raw_hash, secret)
          .and_return(encoded_data)
        expect(rest).to receive(:post).with("data", { "name" => bag_name }).ordered
        expect(rest).to receive(:post).with("data/#{bag_name}", item).ordered

        knife.run
      end
    end
  end

  describe "resilience: RetryWithBackoff" do
    let(:retrying_knife) do
      k = Chef::Knife::DataBagCreate.new
      allow(k).to receive(:rest).and_return(rest)
      allow(k.ui).to receive(:stdout).and_return(stdout)
      allow(k.ui).to receive(:info)
      allow(k).to receive(:sleep)
      k.name_args = [bag_name]
      k
    end

    context "when rest.get raises Errno::ECONNRESET then succeeds" do
      it "retries and continues without error" do
        calls = 0
        allow(rest).to receive(:get) do
          calls += 1
          raise Errno::ECONNRESET if calls < 2

          {}
        end
        expect { retrying_knife.run }.not_to raise_error
        expect(calls).to eq(2)
      end
    end

    context "when rest.get exhausts all retries" do
      it "re-raises Errno::ECONNREFUSED" do
        allow(rest).to receive(:get).and_raise(Errno::ECONNREFUSED)
        expect { retrying_knife.run }.to raise_error(Errno::ECONNREFUSED)
      end
    end

    context "when rest.post raises Net::ReadTimeout then succeeds" do
      it "retries the create call" do
        not_found = Net::HTTPClientException.new("404 Not Found", Net::HTTPNotFound.new("1.1", "404", "Not Found"))
        allow(rest).to receive(:get).and_raise(not_found)
        calls = 0
        allow(rest).to receive(:post).with("data", { "name" => bag_name }) do
          calls += 1
          raise Net::ReadTimeout if calls < 2

          {}
        end
        expect { retrying_knife.run }.not_to raise_error
        expect(calls).to eq(2)
      end
    end
  end
end
