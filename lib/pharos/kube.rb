# frozen_string_literal: true

require 'k8s-client'

module Pharos
  module Kube
    RESOURCE_PATH = Pathname.new(File.expand_path(File.join(__dir__, 'resources'))).freeze

    def self.init_logging!
      # rubocop:disable Style/GuardClause
      if ENV['DEBUG']
        K8s::Logging.debug!
        K8s::Transport.verbose!
      end
      # rubocop:enable Style/GuardClause
    end

    class Stack < K8s::Stack
      LABEL = 'pharos.kontena.io/stack'
      CHECKSUM_ANNOTATION = 'pharos.kontena.io/stack-checksum'

      def self.load(path, name:, **vars)
        path = Pathname.new(path).freeze
        files = Pathname.glob(path.join('*.{yml,yml.erb}')).sort_by(&:to_s)
        resources = files.map do |file|
          K8s::Resource.new(Pharos::YamlFile.new(file).load(name: name, **vars))
        end

        new(name, resources)
      end
    end

    # @param host [String]
    # @return [K8s::Client]
    def self.client(host)
      @kube_client ||= {}
      @kube_client[host] ||= K8s::Client.config(host_config(host))
    end

    # @param host [String]
    # @return [K8s::Config]
    def self.host_config(host)
      K8s::Config.load_file(host_config_path(host))
    end

    # @param host [String]
    # @return [String]
    def self.host_config_path(host)
      File.join(Dir.home, ".pharos/#{host}")
    end

    # @param host [String]
    # @return [Boolean]
    def self.config_exists?(host)
      File.exist?(host_config_path(host))
    end

    # Shortcuts / compatibility:

    # @param host [String]
    # @param name [String]
    # @param vars [Hash]
    def self.apply_stack(host, name, **vars)
      stack = Pharos::Kube::Stack.load(File.join(RESOURCE_PATH, name), name: name, **vars)
      stack.apply(client(host))
    end

    # @param host [String]
    # @param name [String]
    def self.remove_stack(host, name)
      stack = Pharos::Kube::Stack.load(File.join(RESOURCE_PATH, name), name: name)
      stack.delete(client(host))
    end
  end
end
