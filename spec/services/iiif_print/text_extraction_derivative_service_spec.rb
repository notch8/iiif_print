require 'nokogiri'
require 'spec_helper'
require 'misc_shared'

RSpec.describe IiifPrint::TextExtractionDerivativeService do
  include_context "shared setup"

  let(:valid_file_set) do
    file_set = FileSet.new
    file_set.save!(validate: false)
    file_set
  end

  let(:work) do
    work = NewspaperPage.create(title: ["Hello"])
    work.members << valid_file_set
    work.save!
  end

  let(:minimal_alto) do
    File.join(fixture_path, 'minimal-alto.xml')
  end

  let(:altoxsd) do
    xsdpath = File.join(fixture_path, 'alto-2-0.xsd')
    Nokogiri::XML::Schema(File.read(xsdpath))
  end

  describe "Creates ALTO derivative" do
    def source_image(name)
      File.join(fixture_path, name)
    end

    def expected_path(file_set, ext)
      Hyrax::DerivativePath.derivative_path_for_reference(file_set, ext)
    end

    def validate_alto(filename)
      altoxsd.validate(filename)
    end

    def derivative_exists(ext)
      path = expected_path(valid_file_set, ext)
      expect(File.exist?(path)).to be true
      expect(File.size(path)).to be > 0
    end

    xit "creates, stores valid ALTO and plain-text derivatives" do
      # these are in same test to avoid duplicate OCR operation
      service = described_class.new(valid_file_set)
      service.create_derivatives(source_image('ocr_mono.tiff'))
      # ALTO derivative file exists at expected path and validates:
      altoxsd.validate(expected_path(valid_file_set, 'xml'))
      # Plain text exists as non-empty file:
      derivative_exists('txt')
      derivative_exists('json')
      json_path = expected_path(valid_file_set, 'json')
      loaded_result = JSON.parse(File.read(json_path))
      expect(loaded_result['coords'].length).to be > 1
    end

    xit "usually uses OCR, when no existing text" do
      service = described_class.new(valid_file_set)
      # here, service will delegate create_derivatives to OCR impl method:
      expect(service).to receive(:create_derivatives_from_ocr)
      service.create_derivatives(source_image('ocr_mono.tiff'))
    end

    xit "defers to existing ALTO sources, when present" do
      # Attach some ALTO to a work
      derivatives = IiifPrint::Data::WorkDerivatives.of(
        work,
        valid_file_set
      )
      derivatives.attach(minimal_alto, 'xml')
      # In this case, service will not call the OCR implementation method:
      service = described_class.new(valid_file_set)
      expect(service).not_to receive(:create_derivatives_from_ocr)
      service.create_derivatives(source_image('ocr_mono.tiff'))
    end
  end

  describe "Error handling" do
    let(:user) { create(:user) }
    let(:file_set_with_depositor) do
      file_set = FileSet.new
      file_set.depositor = user.user_key
      file_set.save!(validate: false)
      file_set
    end

    def source_image(name)
      File.join(fixture_path, name)
    end

    it "logs error and continues when OCR creation fails" do
      service = described_class.new(file_set_with_depositor)

      # Mock the alto service to return nil path, forcing OCR path
      alto_service = instance_double(IiifPrint::TextFormatsFromALTOService, alto_path: nil)
      allow(IiifPrint::TextFormatsFromALTOService).to receive(:new).and_return(alto_service)

      # Mock OCR creation to raise an error
      expect(service).to receive(:create_derivatives_from_ocr).and_raise(StandardError.new("OCR processing failed"))

      # Expect error logging job to be called
      expect(ContentDepositErrorEventJob).to receive(:perform_later).with(
        file_set_with_depositor,
        user,
        reason: "OCR processing failed"
      )

      # The method should not re-raise the exception
      expect { service.create_derivatives(source_image('ocr_mono.tiff')) }.not_to raise_error
    end

    it "logs error when user cannot be found" do
      file_set_without_user = FileSet.new
      file_set_without_user.depositor = 'nonexistent@example.com'
      file_set_without_user.save!(validate: false)

      service = described_class.new(file_set_without_user)

      # Mock the alto service to return nil path
      alto_service = instance_double(IiifPrint::TextFormatsFromALTOService, alto_path: nil)
      allow(IiifPrint::TextFormatsFromALTOService).to receive(:new).and_return(alto_service)

      # Mock OCR creation to raise an error
      expect(service).to receive(:create_derivatives_from_ocr).and_raise(StandardError.new("OCR failed"))

      # User.find_by_user_key should return nil for nonexistent user
      allow(User).to receive(:find_by_user_key).with('nonexistent@example.com').and_return(nil)

      # Expect error logging job to still be called with nil user
      expect(ContentDepositErrorEventJob).to receive(:perform_later).with(
        file_set_without_user,
        nil,
        reason: "OCR failed"
      )

      expect { service.create_derivatives(source_image('ocr_mono.tiff')) }.not_to raise_error
    end

    it "continues normal processing when no errors occur" do
      service = described_class.new(file_set_with_depositor)

      # Mock successful ALTO processing
      alto_service = instance_double(IiifPrint::TextFormatsFromALTOService, alto_path: '/some/path')
      allow(IiifPrint::TextFormatsFromALTOService).to receive(:new).and_return(alto_service)
      expect(alto_service).to receive(:create_derivatives).with(source_image('ocr_mono.tiff'))

      # Should not call error logging
      expect(ContentDepositErrorEventJob).not_to receive(:perform_later)

      service.create_derivatives(source_image('ocr_mono.tiff'))
    end
  end
end
