# frozen_string_literal: true

require 'pharos-kube-client'

module Pharos
  module Kube
    RESOURCE_PATH = Pathname.new(File.expand_path(File.join(__dir__, 'resources'))).freeze

    def self.init_logging!
      if ENV['DEBUG']
        Pharos::Kube::Logging.debug!
        Pharos::Kube::Transport.verbose!
      end
    end

    class Stack
      def self.load(path, name: , **vars)
        path = Pathname.new(path).freeze
        files = Pathname.glob(path.join('*.{yml,yml.erb}')).sort_by(&:to_s)
        resources = files.map do |file|
          Pharos::Kube::Resource.new(Pharos::YamlFile.new(file).load(name: name, **vars))
        end

        new(name, resources)
      end
    end

    # @param host [String]
    # @return [Pharos::Kube::Client]
    def self.client(host)
      @kube_client ||= {}
      @kube_client[host] ||= Pharos::Kube::Client.config(host_config(host))
    end

    # @param host [String]
    # @return [Pharos::Kube::Config]
    def self.host_config(host)
      Pharos::Kube::Config.load_file(host_config_path(host))
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
