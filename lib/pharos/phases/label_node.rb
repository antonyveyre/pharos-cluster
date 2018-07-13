# frozen_string_literal: true

module Pharos
  module Phases
    class LabelNode < Pharos::Phase
      title "Label nodes"

      def call
        unless @host.labels || @host.taints
          logger.info { "No labels or taints set ... " }
          return
        end

        node = find_node
        raise Pharos::Error, "Cannot set labels, node not found" if node.nil?

        logger.info { "Configuring node labels and taints ... " }
        patch_node(node)
      end

      # @return [Array{Hash}]
      def taints
        return [] unless @host.taints

        @host.taints.map(&:to_h)
      end

      # @param node [Pharos::Kube::Resource]
      def patch_node(node)
        kube_nodes.update_resource(node.merge(
          metadata: {
            labels: @host.labels || {}
          },
          spec: {
            taints: taints
          }
        ))
      end

      def find_node
        node = nil
        retries = 0
        while node.nil? && retries < 10
          begin
            node = kube_nodes.get(@host.hostname)
          rescue Pharos::Kube::Error::NotFound
            retries += 1
            sleep 2
          else
            break
          end
        end

        node
      end

      def kube_client
        @kube_client ||= Pharos::Kube.client(@master.api_address)
      end

      def kube_nodes
        kube_client.api('v1').resource('nodes')
      end
    end
  end
end
