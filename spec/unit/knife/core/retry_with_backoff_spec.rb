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
#

require "knife_spec_helper"
require "chef/knife/core/retry_with_backoff"

# Test double that includes the module under test
class TestCaller
  include Chef::Knife::RetryWithBackoff
end

describe Chef::Knife::RetryWithBackoff do
  subject(:caller) { TestCaller.new }

  # Speed up tests: replace sleep with a no-op
  before { allow(caller).to receive(:sleep) }

  describe "#with_retries" do
    context "when the block succeeds on the first attempt" do
      it "returns the block value without retrying" do
        result = caller.with_retries { 42 }
        expect(result).to eq(42)
        expect(caller).not_to have_received(:sleep)
      end
    end

    context "when the block raises a retryable error then succeeds" do
      it "retries and returns the eventual success value" do
        attempts = 0
        result = caller.with_retries(base_delay: 0.0) do
          attempts += 1
          raise Net::OpenTimeout if attempts < 3

          "ok"
        end
        expect(result).to eq("ok")
        expect(attempts).to eq(3)
      end

      it "sleeps with exponential backoff between retries" do
        attempts = 0
        caller.with_retries(retries: 2, base_delay: 1.0) do
          attempts += 1
          raise Net::ReadTimeout if attempts < 3

          "done"
        end
        # attempt 1 failed → sleep 1.0s; attempt 2 failed → sleep 2.0s
        expect(caller).to have_received(:sleep).with(1.0).ordered
        expect(caller).to have_received(:sleep).with(2.0).ordered
      end
    end

    context "when retries are exhausted" do
      it "re-raises the last exception" do
        expect do
          caller.with_retries(retries: 2, base_delay: 0.0) { raise Errno::ECONNRESET }
        end.to raise_error(Errno::ECONNRESET)
      end

      it "attempts exactly retries+1 times" do
        attempts = 0
        begin
          caller.with_retries(retries: 3, base_delay: 0.0) do
            attempts += 1
            raise Errno::ECONNREFUSED
          end
        rescue Errno::ECONNREFUSED
          nil
        end
        expect(attempts).to eq(4) # 1 original + 3 retries
      end
    end

    context "when the block raises a non-retryable error" do
      it "re-raises immediately without retrying" do
        attempts = 0
        expect do
          caller.with_retries(retries: 3, base_delay: 0.0) do
            attempts += 1
            raise ArgumentError, "bad input"
          end
        end.to raise_error(ArgumentError, "bad input")
        expect(attempts).to eq(1)
        expect(caller).not_to have_received(:sleep)
      end
    end

    context "logging" do
      it "emits a Chef::Log.warn for each retry" do
        allow(Chef::Log).to receive(:warn)
        attempts = 0
        caller.with_retries(retries: 2, base_delay: 0.0) do
          attempts += 1
          raise Net::OpenTimeout if attempts < 3

          "done"
        end
        expect(Chef::Log).to have_received(:warn).twice
      end
    end

    context "with retries: 0" do
      it "does not retry and raises on the first failure" do
        attempts = 0
        expect do
          caller.with_retries(retries: 0, base_delay: 0.0) do
            attempts += 1
            raise Net::ReadTimeout
          end
        end.to raise_error(Net::ReadTimeout)
        expect(attempts).to eq(1)
      end
    end
  end
end
