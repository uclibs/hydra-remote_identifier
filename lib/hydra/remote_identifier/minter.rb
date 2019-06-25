module Hydra
  module RemoteIdentifier

    # The Minter is responsible for passing the target's payload to the
    # RemoteService then setting the target's identifier based on the response
    # from the remote_service
    class Minter

      def self.call(coordinator, target)
        new(coordinator, target).call
      end

      attr_reader :service, :target

      def initialize(service, target)
        @service, @target = service, target
      end

      def call
        update_target(service.call(payload))
      end

      private

      def payload
        payload = target.extract_payload
        if target.respond_to?(:target)
          payload["work_type"] = target.target.class.to_s
        end
        payload
      end

      def update_target(response)
        target.set_identifier({ identifier: response.fetch(:identifier), identifier_url: response.fetch(:identifier_url) })
        response.fetch(:identifier)
      end

    end

  end
end
