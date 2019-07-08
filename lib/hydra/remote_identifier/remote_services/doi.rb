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
        url: "https://api.test.datacite.org/dois",
        resolver_url: 'http://dx.doi.org/'
      }

      attr_reader :username, :password, :shoulder, :url, :resolver_url
      def initialize(options = {})
        configuration = options.with_indifferent_access
        @username = configuration.fetch(:username)
        @password = configuration.fetch(:password)
        @shoulder = configuration.fetch(:shoulder).to_s
        @url = configuration.fetch(:url)
        @resolver_url = configuration.fetch(:resolver_url) { default_resolver_url }
      end

      def normalize_identifier(value)
        value.to_s.strip.
          sub(/\A#{resolver_url}/, '').
          sub(/\A\s*doi:\s+/, 'doi:').
          sub(/\Adoi:/, '')
      end

      def remote_uri_for(identifier)
        URI.parse(File.join(resolver_url, normalize_identifier(escaped identifier)))
      end

      REQUIRED_ATTRIBUTES = ['profile', 'target', 'creator', 'title', 'publisher', 'publicationyear', 'status', 'identifier_url', 'worktype' ].freeze
      def valid_attribute?(attribute_name)
        REQUIRED_ATTRIBUTES.include?(attribute_name.to_s)
      end

      def call(payload)
        request(data_for_request(payload.with_indifferent_access), payload)
      end

      private

      def uri_for_request(payload)
        unless payload.fetch(:identifier_url).nil?
          uri_for_request = URI.parse(payload.fetch(:identifier_url))
        else
          uri_for_request = URI.parse(File.join(url))
        end
        uri_for_request.user = username
        uri_for_request.password = password
        uri_for_request
      end

      def request(data, payload)
        if payload[:identifier_url].nil?
          # response = RestClient.post(@username + ":" + @url + "@", data, content_type: 'application/json', username: @username, password: @password)
          datacite_resource = RestClient::Resource.new @url, @username, @password
          
          response = datacite_resource.post data, content_type: 'application/json'
        else
          doi_id = JSON.parse(
              RestClient::Request.execute method: :get, url: payload.fetch(:identifier_url), user: @username, password: @password
            )["data"]["id"]

          datacite_resource = RestClient::Resource.new @url + "/" + doi_id, @username, @password
          response = datacite_resource.put data, content_type: 'application/json'
        end
        identifier = JSON.parse(response.body)["data"]["attributes"]["doi"]
        identifier_url = @url + "/" + JSON.parse(response.body)["data"]["id"]
        result = {"identifier": "doi:" + identifier,"identifier_url":identifier_url}

      rescue RestClient::Exception => e
        raise(RemoteServiceError.new(e, uri_for_request(payload), data))
      end

      def data_for_request(payload)
        # We need to take the work type in scholar and translate it to the datacite general types.
        translation_hash = {
          "Article": "Text",
          "Document": "Text",
          "Dataset": "Dataset",
          "Image": "Image",
          "Medium": "Audiovisual",
          "StudentWork": "Other",
          "GenericWork": "Other",
          "Etd": "Other",
        }

        if payload.fetch(:identifier_url).nil?
          payload_hash = {
            data: {
              type: "dois",
              attributes: {
                doi: JSON.parse(RestClient.get(@url + "/random?prefix=" + @shoulder))["dois"].first,
                event: payload.fetch(:status),
                creators: Array(payload.fetch(:creator)).map { |name| { "name": name } },
                titles: Array(payload.fetch(:title)).map { |title| { "title": title } },
                publisher: payload.fetch(:publisher),
                publicationYear: payload.fetch(:publicationyear),
                url: payload.fetch(:target),
                types: {
                  resourceTypeGeneral: translation_hash[payload.fetch(:work_type).to_sym],
                  resourceType: payload.fetch(:work_type)
                }
              }
            }
          }
        else
          payload_hash = {
            data: {
              type: "dois",
              attributes: {
                event: payload.fetch(:status)
              }
            }
          }
        end

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
