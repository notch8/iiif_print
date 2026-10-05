require 'spec_helper'

RSpec.describe IiifPrint::Flexibility::Fields do
  describe "#to_a" do
    subject(:fields) { described_class.new(document, ability, sort_order: sort_order).to_a }

    let(:document) { SolrDocument.new(id: 'w1', has_model_ssim: ['GenericWork'], schema_version_ssi: '1') }
    let(:ability) { double(Ability) }
    let(:presenter) { double(Hyrax::WorkShowPresenter) }
    let(:sort_order) { nil }
    let(:definitions) do
      { rights_statement: { render_as: 'external_link' },
        date_created: { display_label: { 'default' => 'Date Created' } },
        title: { display_label: { 'default' => 'iiif_print_spec.title' } },
        notes: { show_page: false },
        hidden: { admin_only: true },
        editors: { editor_only: true },
        featured: { position: 'featured' },
        admin_note: {},
        unrendered: {},
        based_near: { render_term: 'based_near_label' } }
    end

    before do
      I18n.backend.store_translations(:en, iiif_print_spec: { title: 'Name' })
      allow(IiifPrint::Flexibility).to receive(:view_definitions_for).with(document).and_return(definitions)
      allow(IiifPrint::Flexibility).to receive(:presenter_for).with(document, ability).and_return(presenter)
      allow(presenter).to receive(:respond_to?) { |name| ![:unrendered, :based_near].include?(name.to_sym) }
    end

    it "lists the public fields the show page renders, leading with title and collections, then profile order" do
      expect(fields.map(&:name)).to eq [:title, :collection, :rights_statement, :date_created, :featured, :based_near_label]
    end

    it "leaves out the admin note, which the show page shows editors only" do
      expect(fields.map(&:name)).not_to include(:admin_note)
    end

    it "labels them as the show page does" do
      expect(fields.map { |field| [field.name, field.label] }.to_h)
        .to include(rights_statement: 'Rights statement', date_created: 'Date created', title: 'Name',
                    based_near_label: I18n.t('blacklight.search.fields.show.based_near_label', default: 'Based near label'))
    end

    it "keeps their view options for the flexible renderer" do
      expect(fields.find { |field| field.name == :rights_statement }.options).to include(render_as: 'external_link')
    end

    context "when the profile defines collection itself" do
      let(:definitions) { { title: {}, collection: { display_label: { 'default' => 'Part of' } } } }

      it "lists it once, as the profile labels it" do
        expect(fields.map { |field| [field.name, field.label] }).to eq [[:title, 'Title'], [:collection, 'Part of']]
      end
    end

    context "when the profile shows collection and the presenter has no collection method" do
      let(:definitions) { { title: {}, collection: { display_label: { 'default' => 'Part of' } } } }

      before { allow(presenter).to receive(:respond_to?) { |name| name.to_sym != :collection } }

      it "still lists it, since collections render from their membership" do
        expect(fields.map { |field| [field.name, field.label] }).to eq [[:title, 'Title'], [:collection, 'Part of']]
      end
    end

    context "when the profile hides collection" do
      let(:definitions) { { title: {}, collection: { show_page: false } } }

      it "leaves collections out" do
        expect(fields.map(&:name)).to eq [:title]
      end
    end

    context "with a presentation order" do
      let(:sort_order) { [:title, :collection, :remaining, :rights_statement] }

      it "orders them by it" do
        expect(fields.map(&:name)).to eq [:title, :collection, :date_created, :featured, :based_near_label, :rights_statement]
      end
    end
  end
end
