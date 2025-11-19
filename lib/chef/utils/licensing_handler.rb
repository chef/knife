require_relative "licensing_config"

class Chef
  class Utils
    class LicensingHandler
      OMNITRUCK_URLS = {
        "free"       => "https://omnitruck.chef.io",
        "trial"      => "https://omnitruck.chef.io",
        "commercial" => "https://chefdownload-commercial.chef.io",
      }.freeze

      attr_reader :license_key, :license_type

      def initialize(key, type)
        @license_key = key
        @license_type = type
      end

      def omnitruck_url
        url = OMNITRUCK_URLS[license_type]

        "#{url}/%s?license_id=#{license_key}"
      end

      def install_sh_url
        format(omnitruck_url, "install.sh")
      end

      def install_ps1_url
        format(omnitruck_url, "install.ps1")
      end

      class << self
        def validate!(config)
          license_keys = ChefLicensing.fetch_and_persist

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
