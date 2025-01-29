# frozen_string_literal: true

require 'spec_helper'

RSpec.describe IiifPrint::DerivativeRodeoService do
  let(:work) { double("Work", { :id => 'work-5678', described_class.parent_work_identifier_property_name => 'hello-1234-id' }) }
  let(:file_set) { FileSet.new.tap { |fs| fs.save!(validate: false) } }
  let(:generator) { DerivativeRodeo::Generators::CopyGenerator }
  let(:output_extension) { "rb" }

  before do
    allow(file_set).to receive(:parent).and_return(work)

    # TODO: This is a hack that leverages the internals oof Hydra::Works; not excited about it but
    # this part is only one piece of the over all integration.
    allow(file_set).to receive(:original_file).and_return(double(original_filename: __FILE__))
  end

  let(:instance) { described_class.new(file_set) }

  subject(:klass) { described_class }

  describe '.preprocessed_location_adapter_name' do
    subject { described_class.preprocessed_location_adapter_name }
    it { is_expected.to eq 's3' }
  end

  describe '.parent_work_identifier_property_name' do
    subject { described_class.parent_work_identifier_property_name }
    it { is_expected.to be_a String }
  end

  describe '.named_derivatives_and_generators_by_type' do
    subject { described_class.named_derivatives_and_generators_by_type }
    it { is_expected.to be_a Hash }
  end

  describe '.derivative_rodeo_uri' do
    subject { described_class.derivative_rodeo_uri(file_set: file_set, filename: __FILE__) }

    context 'when the file_set does not have a parent' do
      xit 'is expected to raise an error' do
        expect { subject }.to raise_error(IiifPrint::DataError)
      end
    end

    context 'when the file_set has a parent' do
      it { is_expected.to start_with("#{described_class.preprocessed_location_adapter_name}://") }
      it { is_expected.to end_with(File.basename(__FILE__)) }
    end

    context 'for a thumbnail based on a PDF' do
      let(:extension) { DerivativeRodeo::Generators::ThumbnailGenerator.output_extension }
      let(:filename) { "/tmp/d20230714-1897-1wgmauo/#{work.aark_id}.ARCHIVAL.pdf" }
      it 'has the correct filename' do
        expect(described_class.derivative_rodeo_uri(file_set: file_set, filename: filename, extension: extension,
adapter_name: 'file')).to eq("file://#{work.aark_id}/#{work.aark_id}.ARCHIVAL.#{extension}")
      end
    end

    context 'for the original file' do
      let(:extension) { nil }
      let(:filename) { "/tmp/d20230714-1897-1wgmauo/#{work.aark_id}.ARCHIVAL.pdf" }
      it 'has the correct filename' do
        expect(described_class.derivative_rodeo_uri(file_set: file_set, filename: filename, extension: extension, adapter_name: 'file')).to eq("file://#{work.aark_id}/#{work.aark_id}.ARCHIVAL.pdf")
      end
    end
  end

  # TODO: Need Faux Bucket for Derivative Rodeo
  xdescribe '#valid?' do
    subject { instance.valid? }

    before do
      allow(file_set).to receive(:mime_type).and_return(mime_type)
      allow(file_set).to receive(:parent).and_return(work)
    end

    context 'when the mime_type of the file is not supported' do
      let(:mime_type) { "text/plain" }
      it { is_expected.to be_falsey }
    end

    context 'when derivative rodeo has not pre-processed the file set' do
      before { instance.preprocessed_location_adapter_name = "file" }

      let(:mime_type) { "application/pdf" }
      it { is_expected.to be_falsey }
    end

    context 'when the mime type is supported and the derivative rodeo has pre-processed the file set' do
      before do
        # TODO: write to the rodeo; consider using AWS's spec support; I want to be able to "fake" S3
        # with a "fake" bucket.
        #
        # Dependent on https://github.com/notch8/derivative_rodeo/pull/37
      end

      let(:mime_type) { "application/pdf" }
      it { is_expected.to be_truthy }
    end
  end
end
