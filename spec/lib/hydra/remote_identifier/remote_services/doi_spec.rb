require 'spec_helper'
require 'hydra/remote_identifier/remote_services/doi'

module Hydra::RemoteIdentifier
  module RemoteServices

    describe Doi do
      let(:configuration) { RemoteServices::Doi::TEST_CONFIGURATION }
      let(:create_payload) {
        {
          target: 'http://google.com',
          creator: ['Jeremy Friesen', 'Rajesh Balekai'],
          title: 'My Article',
          publisher: 'Me Myself and I',
          publicationyear: "2013",
          status: "public",
          profile: "datacite",
          identifier_url: nil,
          work_type: "Document"
        }
      }

      # Sometimes we will want to hide a work and remove it
      # from the datacite index.
      let(:update_payload) {
        {
          status: "hide",
          identifier_url: "https://api.test.datacite.org/dois/10.23676/z8b5-t823"
        }
      }

      let(:expected_doi) {
        # From the doi-create cassette
        {
          identifier: "doi:10.23676/z8b5-t823",
          identifier_url: "https://api.test.datacite.org/dois/10.23676/z8b5-t823"
        }
      }

      subject { RemoteServices::Doi.new(configuration) }

      context '#normalize_identifier' do
        [
          ['doi: 10.6017/ital.v28i2.3177', '10.6017/ital.v28i2.3177'],
          ['doi:  10.6017/ital.v28i2.3177', '10.6017/ital.v28i2.3177'],
          ["doi:\t10.6017/ital.v28i2.3177", '10.6017/ital.v28i2.3177'],
          ['10.6017/ital.v28i2.3177', '10.6017/ital.v28i2.3177'],
          ['doi:10.6017/ital.v28i2.3177', '10.6017/ital.v28i2.3177'],
          [ RemoteServices::Doi::TEST_CONFIGURATION.fetch(:resolver_url) + '10.6017/ital.v28i2.3177', '10.6017/ital.v28i2.3177'],
          [ File.join(RemoteServices::Doi::TEST_CONFIGURATION.fetch(:resolver_url),'10.6017/ital.v28i2.3177'), '10.6017/ital.v28i2.3177']
        ].each_with_index do |(input, expected), index|
          it "scenario ##{index}" do
            expect(subject.normalize_identifier(input)).to eq(expected)
          end
        end
      end

      context '.call', VCR::SpecSupport(cassette_name: 'doi-create') do
        it 'should post to remote service' do
          expect(subject.call(create_payload)).to eq(expected_doi)
        end

        it 'should update the remote DOI' do
          # The doi should be the same as returned with create.
          expect(subject.call(update_payload)).to eq(expected_doi)
        end

        it 'should raise RemoteServiceError when request was invalid' do
          expect(RestClient::Resource).to receive(:new).and_raise(RestClient::Exception.new)
          expect {
            subject.call(create_payload)
          }.to raise_error(RemoteServiceError)
        end
      end

      context '.remote_uri_for' do
        let(:expected_uri) { URI.parse(File.join(subject.resolver_url, expected_doi.fetch(:identifier).gsub(/doi:/, '')))}
        it 'should be based on configuration' do
          expect(subject.remote_uri_for(expected_doi.fetch(:identifier))).to eq(expected_uri)
        end

        it 'should handle charaters that need to be escaped' do
          expect(subject.remote_uri_for("[test]{me}+")).to eq(URI.parse("http://dx.doi.org/%5Btest%5D%7Bme%7D%2B"))
        end
      end
    end
  end
end
