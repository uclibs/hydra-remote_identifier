require 'uri'
require 'rest_client'
require 'hydra/remote_identifier/remote_service'
require 'hydra/remote_identifier/exceptions'
require 'active_support/core_ext/hash/indifferent_access'

module Hydra::RemoteIdentifier
  module RemoteServices
    class Doi < Hydra::RemoteIdentifier::RemoteService
      TEST_CONFIGURATION =
      {
        username: 'apitest',
        password: 'apitest',
        shoulder: 'doi:10.5072/FK2',
        url: "https://ezid.lib.purdue.edu/",
        resolver_url: 'http://dx.doi.org/'
      }

      attr_reader :username, :password, :shoulder, :url, :resolver_url
      def initialize(options = {})
        configuration = options.with_indifferent_access
        @username = configuration.fetch(:username)
        @password = configuration.fetch(:password)
        @shoulder = configuration.fetch(:shoulder)
        @url = configuration.fetch(:url)
        @resolver_url = configuration.fetch(:resolver_url) { default_resolver_url }
      end

      def normalize_identifier(value)
        value.to_s.strip.
          sub(/\A#{resolver_url}/, '').
          sub(/\A\s*doi:\s+/, 'doi:').
          sub(/\A(\d)/, 'doi:\1')
      end

      def remote_uri_for(identifier)
        URI.parse(File.join(resolver_url, normalize_identifier(identifier)))
      end

      REQUIRED_ATTRIBUTES = ['target', 'creator', 'title', 'publisher', 'publicationyear', 'status' ].freeze
      def valid_attribute?(attribute_name)
        REQUIRED_ATTRIBUTES.include?(attribute_name.to_s)
      end

      def call(payload)
        request(data_for_create(payload.with_indifferent_access))
      end

      private

      def uri_for_create
        uri_for_create = URI.parse(File.join(url, 'shoulder', shoulder))
        uri_for_create.user = username
        uri_for_create.password = password
        uri_for_create
      end

      def request(data)
        response = RestClient.post(uri_for_create.to_s, data, content_type: 'text/plain')
        matched_data = /\Asuccess:(.*)(?<doi>doi:[^\|]*)(.*)\Z/.match(response.body)
        matched_data[:doi].strip
      rescue RestClient::Exception => e
        raise(RemoteServiceError.new(e, uri_for_create, data))
      end

      def data_for_create(payload)
        data = []
        data << "_target: #{payload.fetch(:target)}"
        data << "_status: #{payload.fetch(:status)}"
        data << "datacite.creator: #{Array(payload.fetch(:creator)).join(', ')}"
        data << "datacite.title: #{Array(payload.fetch(:title)).join('; ')}"
        data << "datacite.publisher: #{Array(payload.fetch(:publisher)).join(', ')}"
        data << "datacite.publicationyear: #{payload.fetch(:publicationyear)}"
        data.join("\n")
      end

      def default_resolver_url
        'http://dx.doi.org/'
      end
    end
  end
end
