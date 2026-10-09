require 'spec_helper'

RSpec.describe IiifPrint::Flexibility do
  describe ".presenter_for" do
    subject(:presenter) { described_class.presenter_for(document, double(Ability)) }

    context "with a file set" do
      let(:document) { SolrDocument.new(id: 'fs1', has_model_ssim: ['FileSet']) }

      it { is_expected.to be_a Hyrax::FileSetPresenter }
    end

    context "with a work type that has no works controller" do
      let(:document) { SolrDocument.new(id: 'w1', has_model_ssim: ['Widget']) }

      before { allow(document).to receive(:hydra_model).and_return(double(model_name: double(collection: 'widgets'))) }

      it { is_expected.to be_a Hyrax::WorkShowPresenter }
    end
  end

  describe ".view_definitions_for" do
    subject(:definitions) { described_class.view_definitions_for(document) }

    let(:document) { SolrDocument.new(id: 'w1', has_model_ssim: ['GenericWork'], schema_version_ssi: '1') }
    let(:loader) { double(view_definitions_for: { 'subject' => { 'render_as' => 'faceted' } }) }
    let(:attributes) { { 'title' => { 'display_label' => { 'default' => 'Name' } }, 'subject' => {} } }
    let(:attribute_definition) do
      Class.new(Struct.new(:name, :config)) do
        def view_options
          { display_label: config['display_label'] }
        end
      end
    end

    before do
      stub_const('Hyrax::Schema', double(m3_schema_loader: loader))
      stub_const('Hyrax::FlexibleSchema', double(find_by: double(attributes_for: attributes)))
      stub_const('Hyrax::SchemaLoader::AttributeDefinition', attribute_definition)
      allow(described_class).to receive(:schema_name).and_return('GenericWork')
    end

    it "adds the title from the profile when it has no view block, ahead of the profile's view definitions" do
      expect(definitions.keys).to eq [:title, :subject]
      expect(definitions[:title]).to eq(display_label: { 'default' => 'Name' })
    end

    context "with a description and an abstract that have no view block" do
      let(:attributes) do
        { 'description' => { 'display_label' => { 'default' => 'Description' } },
          'abstract' => { 'display_label' => { 'default' => 'Abstract' } } }
      end

      it "adds both, in the show page's order" do
        expect(definitions.keys).to eq [:description, :abstract, :subject]
      end
    end

    context "with a lead field the profile limits to a context" do
      let(:attributes) { { 'description' => { 'context' => ['special'] } } }
      let(:document) { double('SolrDocument', schema_version: '1', contexts: contexts) }

      context "and a record in no context" do
        let(:contexts) { nil }

        it "leaves it out, as the show page does" do
          expect(definitions.keys).to eq [:subject]
        end
      end

      context "and a record in another context" do
        let(:contexts) { ['other'] }

        it "leaves it out, as the show page does" do
          expect(definitions.keys).to eq [:subject]
        end
      end

      context "and a record in that context" do
        let(:contexts) { ['special'] }

        it "adds it" do
          expect(definitions.keys).to eq [:description, :subject]
        end
      end
    end

    it "reads them once per request" do
      2.times { described_class.view_definitions_for(document) }
      expect(loader).to have_received(:view_definitions_for).once
    end

    it "reads them again for another tenant, which numbers its own profile versions" do
      tenant = double(current: 'tenant-a')
      stub_const('Apartment::Tenant', tenant)
      described_class.view_definitions_for(document)
      allow(tenant).to receive(:current).and_return('tenant-b')
      described_class.view_definitions_for(document)
      expect(loader).to have_received(:view_definitions_for).twice
    end
  end
end
