require "spec_helper"

RSpec.describe IiifPrint::IiifManifestPresenterDecorator do
  let(:parent_fs_attributes) do
    { "id" => "parent_fs123",
      "title_tesim" => ["My Parent FileSet"],
      "has_model_ssim" => ["FileSet"] }
  end
  let(:child_work_attributes) do
    { "id" => "child_work123",
      "title_tesim" => ["My Child Image"],
      "has_model_ssim" => ["Image"],
      "descendent_member_ids_ssim" => ["child_image_fs123"] }
  end
  let(:child_fs_attributes) do
    { "id" => "child_fs123",
    "title_tesim" => ["My Child FileSet"],
    "has_model_ssim" => ["FileSet"] }
  end
  let(:parent_fs_solr_doc) { SolrDocument.new(parent_fs_attributes) }
  let(:child_work_solr_doc) { SolrDocument.new(child_work_attributes) }
  let(:child_fs_solr_doc) { SolrDocument.new(child_fs_attributes) }
  let(:ids) { [parent_fs_solr_doc.id, child_work_solr_doc.id] }
  let(:presenter_class) { Hyrax::IiifManifestPresenter }

  subject(:presenter_factory) do
    Hyrax::IiifManifestPresenter::Factory.new(
      ids: ids,
      presenter_class: presenter_class,
      presenter_args: []
    )
  end

  describe "#build" do
    it "returns an Array of DisplayImagePresenters" do
      allow_any_instance_of(Hyrax::IiifManifestPresenter::Factory)
        .to receive(:load_docs).and_return([parent_fs_solr_doc, child_work_solr_doc])
      allow_any_instance_of(IiifPrint::IiifManifestPresenterFactoryDecorator)
        .to receive(:load_file_set_docs).and_return([child_fs_solr_doc])
      allow(child_work_solr_doc).to receive(:hydra_model).and_return(MyWork)
      allow(Hyrax.config).to receive(:curation_concerns).and_return([MyWork])

      expect(subject.build).to be_an Array
      expect(subject.build.size).to eq ids.size
      expect(subject.build.map(&:class).uniq.size).to eq 1
      expect(subject.build.first.class).to eq Hyrax::IiifManifestPresenter::DisplayImagePresenter
    end
  end
end
