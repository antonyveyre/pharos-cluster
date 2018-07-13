# frozen_string_literal: true

module Pharos
  module Phases
    class ConfigureWeave < Pharos::Phase
      title "Configure Weave network"

      WEAVE_VERSION = '2.3.0'

      register_component(
        name: 'weave-net', version: WEAVE_VERSION, license: 'Apache License 2.0',
        enabled: proc { |c| c.network.provider == 'weave' }
      )

      def call
        ensure_passwd
        ensure_resources
      end

      def ensure_passwd
        kube_client = Pharos::Kube.client(@master.api_address)
        kube_secrets = kube_client.api('v1').resource('secrets', namespace: 'kube-system')

        kube_secrets.get('weave-passwd')
      rescue Pharos::Kube::Error::NotFound
        logger.info { "Configuring overlay network shared secret ..." }
        weave_passwd = Pharos::Kube::Resource.new(
          metadata: {
            name: 'weave-passwd',
            namespace: 'kube-system'
          },
          data: {
            'weave-passwd': Base64.strict_encode64(generate_password)
          }
        )
        kube_secrets.create_resource(weave_passwd)
      end

      def ensure_resources
        trusted_subnets = @config.network.weave&.trusted_subnets || []
        logger.info { "Configuring overlay network ..." }
        Pharos::Kube.apply_stack(
          @master.api_address, 'weave',
          image_repository: @config.image_repository,
          trusted_subnets: trusted_subnets,
          ipalloc_range: @config.network.pod_network_cidr,
          arch: @host.cpu_arch,
          version: WEAVE_VERSION
        )
      end

      def generate_password
        SecureRandom.hex(24)
      end
    end
  end
end
