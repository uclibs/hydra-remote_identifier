require File.expand_path('../../../../../lib/hydra/remote_identifier/minter', __FILE__)

module Hydra::RemoteIdentifier

  describe Minter do
    let(:payload) { 'abc' }
    let(:identifier) { { identifier: '123', identifier_url: '456' } }
    let(:target) { double(extract_payload: payload) }
    let(:service) { double }
    describe '.call' do
      it 'initializes the minter and calls it' do

      end
    end
    describe '#call' do
      subject { Minter.new(service, target) }
      it "extracts the target's payload to send to the remote service then updates the target's identifier" do
        expect(service).to receive(:call).with(payload).and_return(identifier)
        expect(target).to receive(:set_identifier).with(identifier)
        expect(subject.call).to eq(identifier.fetch(:identifier))
      end
    end

  end
end
