require_relative "licensing_config"

class Chef
  class Utils
    class LicensingHandler
      # Omnitruck URLs are no longer used. Updated to new download URLs.
      DOWNLOAD_URLS = {
        "free" => "https://chefdownload-trial.chef.io",
        "trial" => "https://chefdownload-trial.chef.io",
        "commercial" => "https://chefdownload-commercial.chef.io",
      }.freeze

      attr_reader :license_key, :license_type

      def initialize(key, type)
        @license_key = key
        @license_type = type
      end

      def omnitruck_url
        url = DOWNLOAD_URLS[license_type]

        "#{url}/%s?license_id=#{license_key}"
      end

      def install_sh_url
        format(omnitruck_url, "install.sh")
      end

      def install_ps1_url
        format(omnitruck_url, "install.ps1")
      end

      class << self
        def validate!
          license_keys = begin
                           ChefLicensing.fetch_and_persist
                         # If the env is airgapped or the local licensing service is unreachable,
                         # the licensing gem will raise ChefLicensing::RestfulClientConnectionError.
                         # In such cases, we are assuming the license is not available.
                         rescue ChefLicensing::RestfulClientConnectionError
                           []
                         end

          return new(nil, nil) if license_keys&.empty?

          licenses_metadata = ChefLicensing::Api::Describe.list({
            license_keys: license_keys,
          })

          new(licenses_metadata.last.id, licenses_metadata.last.license_type)
        end

        def check_software_entitlement!(ui)
          ChefLicensing.check_software_entitlement!
        rescue ChefLicensing::SoftwareNotEntitled
          ui.error "License is not entitled to use Workstation."
          exit 1
        rescue ChefLicensing::Error => e
          ui.error e.message
          exit 1
        end
      end
    end
  end
end
