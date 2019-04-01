require 'spec_helper'
require 'hydra/remote_identifier/remote_services/doi'
require "uri"
require "net/http"
require 'byebug'

module Hydra::RemoteIdentifier
  module RemoteServices

    describe Doi do
      let(:configuration) { RemoteServices::Doi::TEST_CONFIGURATION }
      let(:payload) {
        {
          type: "dois",
          attributes: {
            doi: "10.7052/uclibs-200a",
          }
        }
      }

      let(:expected_doi) {
        # From the 
        'doi:10.7052/uclibs-200a'
      }
      
#      subject { RemoteServices::Doi.new(configuration) }
   
      context '.call' do
        it 'should post to DATACITE remote service' do
          url = URI("https://api.test.datacite.org/dois")
          https = Net::HTTP.new(url.host, url.port)
          https.use_ssl = true
  
          request = Net::HTTP::Post.new(url)
          request["Content-Type"] = 'application/json'
          request["Authorization"] = 'Basic Q0lOLlRFU1Q6b3g2aVFQWDJ0V2N2ZU5vVWZNM3FkZjgyYW9lUA=='
          request["cache-control"] = 'no-cache'
          request["Postman-Token"] = '42bca710-2454-45e0-bb95-9ec59ee3d81d'
          request.body = "{\n  \"data\": {\n    \"type\": \"dois\",\n    \"attributes\": {\n      \"doi\": \"10.23676/uclibs-234asd\"\n    }\n  }\n}"        
          response = https.request(request)
          puts response.read_body

        end

        it 'should raise RemoteServiceError when request was invalid' do
          expect(RestClient).to receive(:post).and_raise(RestClient::Exception.new)
          expect {
            subject.call(payload)
          }.to raise_error(RemoteServiceError)
        end
      end

    end
  end
end
   
