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

require "net/http" unless defined?(Net::HTTP)

class Chef
  class Knife
    # Lightweight retry-with-exponential-backoff helper.
    #
    # Include this module in any Knife command that makes external HTTP calls
    # and wrap the call site with +with_retries+.
    #
    # Tuning parameters (passed as keyword arguments):
    #   retries:    number of additional attempts after the first (default 3)
    #   base_delay: initial sleep in seconds; doubles each attempt (default 1.0)
    #   retryable:  array of exception classes to retry (default: transient network errors)
    #
    # Rollback: set retries: 0 to disable retry behavior without removing the wrapper,
    # or remove the include + with_retries call to revert entirely.
    module RetryWithBackoff
      RETRYABLE_ERRORS = [
        Net::OpenTimeout,
        Net::ReadTimeout,
        Errno::ECONNRESET,
        Errno::ECONNREFUSED,
      ].freeze

      # Execute +block+, retrying up to +retries+ times on transient errors.
      #
      # @param retries [Integer] maximum number of additional attempts (total = retries + 1)
      # @param base_delay [Float] seconds to sleep before the first retry; doubles each time
      # @param retryable [Array<Class>] exception classes that trigger a retry
      # @yield the operation to protect
      # @return the block's return value
      # @raise the last exception after all retries are exhausted
      def with_retries(retries: 3, base_delay: 1.0, retryable: RETRYABLE_ERRORS, &block)
        attempt = 0
        begin
          attempt += 1
          yield
        rescue *retryable => e
          raise unless attempt <= retries

          delay = base_delay * (2**(attempt - 1))
          Chef::Log.warn("#{self.class}##{__method__}: attempt #{attempt}/#{retries + 1} failed (#{e.class}: #{e.message}); retrying in #{delay}s")
          sleep(delay)
          retry
        end
      end
    end
  end
end
