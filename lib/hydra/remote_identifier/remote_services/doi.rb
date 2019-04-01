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
        shoulder: '10.23676',
        url: "https://CIN.TEST:ox6iQPX2tWcveNoUfM3qdf82aoeP@api.test.datacite.org/dois",
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
        URI.parse(File.join(resolver_url, normalize_identifier(escaped identifier)))
      end

      REQUIRED_ATTRIBUTES = ['target', 'creator', 'title', 'publisher', 'publicationyear', 'status', 'identifier_url' ].freeze
      def valid_attribute?(attribute_name)
        REQUIRED_ATTRIBUTES.include?(attribute_name.to_s)
      end

      def call(payload)
        request(data_for_request(payload.with_indifferent_access), payload)
      end

      private

      def uri_for_request(payload)
        puts payload
        unless payload.fetch(:identifier_url).nil?
          uri_for_request = URI.parse(payload.fetch(:identifier_url))
        else
          uri_for_request = URI.parse(File.join(url, 'shoulder', shoulder))
        end
        uri_for_request.user = username
        uri_for_request.password = password
        uri_for_request
      end

      def request(data, payload)
        response = RestClient.post(TEST_CONFIGURATION[:url], data, content_type: 'application/json')
        response.match('(?<="doi": )".*"')
        rescue RestClient::Exception => e
          raise(RemoteServiceError.new(e, uri_for_request(payload), data))
      end

      def data_for_request(payload)
        payload_hash = {
          data: {
            type: "dois",
            attributes: {
              doi: "10.23676/ucl-#{(0...8).map { (65 + rand(26)).chr }.join}",
              event: "public",
              creators: Array(payload.fetch(:creator)).map { |name| { "name": name } },
              titles: Array(payload.fetch(:title)).map { |title| { "title": title } },
              publisher: payload.fetch(:publisher),
              publicationYear: payload.fetch(:publicationyear)
            }
          }
        }
        payload_hash.to_json
  
      end

      def default_resolver_url
        'http://dx.doi.org/'
      end

      def doi_service_url(identifier)
        File.join(url, 'id', identifier)
      end

      def escaped(identifier)
        URI.escape(identifier).
          gsub("[","%5B").
          gsub("]","%5D").
          gsub("+","%2B").
          gsub("?","%3F")
      end
    end
  end
end
