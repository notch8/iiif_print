require 'spec_helper'

RSpec.describe IiifPrint::Configuration do
  let(:config) { described_class.new }

  it { is_expected.to respond_to :ingest_queue_name }
  it { is_expected.to respond_to :ingest_queue_name= }

  describe '#persistence_adapter' do
    subject { config.persistence_adapter }

    it { is_expected.to eq(IiifPrint::PersistenceLayer::ActiveFedoraAdapter) }
  end

  describe '#ancestory_identifier_function' do
    subject(:function) { config.ancestory_identifier_function }
    it "is expected to be a lambda with an arity of one" do
      expect(function.arity).to eq(1)
    end

    it "is configurable" do
      expect do
        config.ancestory_identifier_function = ->(w) { w.object_id }
      end.to change { config.ancestory_identifier_function.object_id }
    end
  end

  describe '#unique_child_title_generator_function' do
    subject(:function) { config.unique_child_title_generator_function }

    it "is expected to be a lambda with keyword args" do
      expect(function.parameters).to eq([[:keyreq, :original_pdf_path],
                                         [:keyreq, :image_path],
                                         [:keyreq, :parent_work],
                                         [:keyreq, :page_number],
                                         [:keyreq, :page_padding]])
    end

    it 'works as originally designed' do
      work = double(title: ["My Title"], id: '1234')
      expect(function.call(
               original_pdf_path: "/hello/world/nice.pdf",
               image_path: __FILE__,
               parent_work: work,
               page_number: 23,
               page_padding: 5
             )).to eq("1234 - nice.pdf Page 00024")
    end

    it "is configurable" do
      expect do
        config.unique_child_title_generator_function = ->(**kwargs) { kwargs }
      end.to change { config.unique_child_title_generator_function.object_id }
    end
  end

  describe "#metadata_fields" do
    subject { config.metadata_fields }

    it { is_expected.to be_a Hash }
    it "allows for an override" do
      original = config.metadata_fields
      config.metadata_fields = { title: {} }
      expect(config.metadata_fields).not_to eq original
    end
  end

  describe "#handle_after_create_fileset" do
    let(:file_set) { double(FileSet) }
    let(:user) { double(User) }
    subject(:called_function) { config.handle_after_create_fileset(file_set, user) }

    context "without configuration" do
      it "calls IiifPrint::Data.handle_after_create_fileset" do
        expect(IiifPrint::Data).to receive(:handle_after_create_fileset).with(file_set, user)

        called_function
      end
    end

    context "with configuration" do
      let(:config_func) { ->(_file_set, _user) { :yup } }

      it "calls the given configured lambda" do
        config.after_create_fileset_handler = config_func
        expect(IiifPrint::Data).not_to receive(:handle_after_create_fileset)
        expect(config_func).to receive(:call).with(file_set, user)
        called_function
      end
    end
  end

  describe '#additional_tesseract_options' do
    context "by default" do
      subject { config.additional_tesseract_options }
      it { is_expected.not_to be_present }
    end

    it "can be configured" do
      expect do
        config.additional_tesseract_options = "-l esperanto"
      end.to change(config, :additional_tesseract_options)
        .from("")
        .to("-l esperanto")
    end
  end

  describe '#ocr_preprocess_options' do
    it "is nil by default and can be configured" do
      expect { config.ocr_preprocess_options = "-colorspace gray" }
        .to change(config, :ocr_preprocess_options).from(nil).to("-colorspace gray")
    end
  end

  describe '#default_iiif_manifest_version' do
    subject { config.default_iiif_manifest_version }

    context 'default' do
      it { is_expected.to eq 2 }
    end

    context 'when set to empty' do
      before { config.default_iiif_manifest_version = '' }
      it { is_expected.to eq 2 }
    end

    it 'can be set' do
      expect { config.default_iiif_manifest_version = 3 }
        .to change(config, :default_iiif_manifest_version)
        .from(2)
        .to(3)
    end
  end

  describe '#child_work_attributes_function' do
    subject(:function) { config.child_work_attributes_function }

    it "is expected to be a lambda with keyword args" do
      expect(function.parameters).to eq([[:keyreq, :parent_work],
                                         [:keyreq, :admin_set_id]])
    end
  end

  describe "#sort_iiif_manifest_canvases_by" do
    subject { config.sort_iiif_manifest_canvases_by }

    it { is_expected.to be_a NilClass }
    it "allows for an override" do
      original = config.sort_iiif_manifest_canvases_by
      config.sort_iiif_manifest_canvases_by = :title
      expect(config.metadata_fields).not_to eq original
    end
  end

  describe "#ocr_coords_from_json_function" do
    subject(:function) { config.ocr_coords_from_json_function }

    it "is expected to be a lambda with one keyword arg and optional args" do
      expect(function.parameters).to eq([[:keyreq, :file_set_id], [:keyrest]])
    end
  end

  describe "#all_text_generator_function" do
    subject(:function) { config.all_text_generator_function }

    it "is expected to be a lambda with one keyword arg" do
      expect(function.parameters).to eq([[:keyreq, :object]])
    end
  end

  describe "#iiif_metadata_field_presentation_order" do
    subject { config.iiif_metadata_field_presentation_order }

    it { is_expected.to be_a NilClass }
    it "allows for an override" do
      original = config.iiif_metadata_field_presentation_order
      config.iiif_metadata_field_presentation_order = :title
      expect(config.iiif_metadata_field_presentation_order).not_to eq original
    end
  end

  describe "#questioning_authority_fields" do
    subject { config.questioning_authority_fields }

    it { is_expected.to be_a Array }
    context "by default" do
      it { is_expected.to eq ['rights_statement', 'license'] }
    end

    it "allows for an override" do
      expect do
        config.questioning_authority_fields = ['rights_statement', 'license', 'subject']
      end.to change(config, :questioning_authority_fields).from(['rights_statement', 'license']).to(['rights_statement', 'license', 'subject'])
    end
  end

  describe '#skip_splitting_pdf_files_that_end_with_these_texts' do
    subject { config.skip_splitting_pdf_files_that_end_with_these_texts }
    context 'by default' do
      it { is_expected.to be_empty }
    end

    context 'is configurable' do
      before { config.skip_splitting_pdf_files_that_end_with_these_texts = ['.READER.pdf'] }

      it { is_expected.not_to be_empty }
    end
  end
end
