# frozen_string_literal: true

require 'spec_helper'

RSpec.describe IiifPrint::FileSetIndexerDecorator do
  let(:test_class) do
    Class.new { prepend IiifPrint::FileSetIndexerDecorator }
  end
  let(:instance) { test_class.new }

  describe '#find_checksum (private)' do
    let(:object) { instance_double('FileSet') }
    let(:file)   { instance_double(Hyrax::FileMetadata) }

    before { allow(object).to receive(:original_file).and_return(file) }

    context 'when file is Hyrax::FileMetadata and checksum is an Array' do
      before { allow(file).to receive(:is_a?).with(Hyrax::FileMetadata).and_return(true) }

      it 'returns the first element rather than the array inspect string' do
        allow(file).to receive(:checksum).and_return(['urn:sha1:abc123'])
        expect(instance.send(:find_checksum, object)).to eq 'urn:sha1:abc123'
      end
    end

    context 'when file is Hyrax::FileMetadata and checksum is a scalar' do
      before { allow(file).to receive(:is_a?).with(Hyrax::FileMetadata).and_return(true) }

      it 'returns the scalar value' do
        allow(file).to receive(:checksum).and_return('urn:sha1:abc123')
        expect(instance.send(:find_checksum, object)).to eq 'urn:sha1:abc123'
      end
    end

    context 'when file is not Hyrax::FileMetadata (ActiveFedora path)' do
      let(:file) { double(Hydra::PCDM::File) }
      before { allow(file).to receive(:is_a?).with(Hyrax::FileMetadata).and_return(false) }

      it 'returns the first digest' do
        digest = instance_double('RDF::URI', to_s: 'urn:sha1:def456')
        allow(file).to receive(:digest).and_return([digest])
        expect(instance.send(:find_checksum, object)).to eq 'urn:sha1:def456'
      end
    end

    context 'when original_file is nil' do
      before { allow(object).to receive(:original_file).and_return(nil) }

      it 'returns nil' do
        expect(instance.send(:find_checksum, object)).to be_nil
      end
    end
  end
end
