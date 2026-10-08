require 'spec_helper'

RSpec.describe IiifPrint::Metadata do
  let(:base_url) { "https://my.dev.test" }
  let(:solr_hit) { SolrHit.new(attributes) }
  let(:fields) { IiifPrint.default_fields(fields: metadata_fields) }
  let(:metadata_fields) do
    {
      title: {},
      description: {},
      date_modified: {}
    }
  end

  describe ".build_metadata_for" do
    subject(:manifest_metadata) do
      described_class.build_metadata_for(
        work: solr_hit,
        version: version,
        fields: fields,
        current_ability: double(Ability),
        base_url: base_url
      )
    end

    context "for version 2 of the IIIF spec" do
      let(:version) { 2 }

      context "with a field that has some plain text" do
        let(:attributes) { { "title_tesim" => ["My Awesome Title"] } }

        it "maps the metadata accordingly" do
          expect(manifest_metadata).to eq [
            { "label" => "Title", "value" => ["My Awesome Title"] }
          ]
        end
      end

      context "with a field that contains a url string" do
        let(:attributes) { { "description_tesim" => ["A url like https://www.example.com/, cool!"] } }

        it "creates a link for the url string" do
          expect(manifest_metadata).to eq [
            { "label" => "Description",
               "value" =>
                [
                  "A url like <a href='https://www.example.com/' target='_blank'>https://www.example.com/</a>, cool!"
                ] }
          ]
        end
      end

      context "with a date" do
        let(:attributes) { { "date_modified_dtsi" => "2011-11-11T11:11:11Z" } }

        it "displays it just the date" do
          expect(manifest_metadata).to eq [{ "label" => "Date modified", "value" => ["2011-11-11"] }]
        end
      end

      context "with a faceted option" do
        let(:metadata_fields) { { creator: { render_as: :faceted } } }
        let(:attributes) { { "creator_tesim" => ["McAuthor, Arthur"] } }

        it "adds a link to the faceted search" do
          expect(manifest_metadata).to eq [
            { "label" => "Creator",
              "value" =>
                ["<a href='#{base_url}/catalog?f%5Bcreator_sim%5D%5B%5D=McAuthor%2C+Arthur&locale=en'>McAuthor, Arthur</a>"] }
          ]
        end
      end

      context "with an authority option" do
        context "rights statement" do
          let(:metadata_fields) { { rights_statement: { render_as: :rights_statement } } }
          let(:attributes) { { "rights_statement_tesim" => ["http://rightsstatements.org/vocab/InC-OW-EU/1.0/"] } }

          it "renders a link and displays a term" do
            expect(manifest_metadata).to eq [
              { "label" => "Rights statement",
                "value" => ["<a href='http://rightsstatements.org/vocab/InC-OW-EU/1.0/'>In Copyright - EU Orphan Work</a>"] }
            ]
          end
        end

        context "license" do
          let(:metadata_fields) { { license: { render_as: :license } } }
          let(:attributes) { { "license_tesim" => ["https://creativecommons.org/licenses/by-sa/4.0/"] } }

          it "renders a link and displays a term" do
            expect(manifest_metadata).to eq [
              { "label" => "License",
                "value" => [
                  "<a href='https://creativecommons.org/licenses/by-sa/4.0/'>Creative Commons BY-SA Attribution-ShareAlike 4.0 International</a>"
                ] }
            ]
          end
        end
      end

      context "when the work is apart of a collection" do
        let(:metadata_fields) { { collection: {} } }
        let(:collection_attributes) { { "id" => "321cba", "title_tesim" => ["My Cool Collection"] } }
        let(:collection_solr_doc) { SolrDocument.new(collection_attributes) }
        let(:attributes) { { "member_of_collection_ids_ssim" => "321cba" } }

        it "renders a link to the collection" do
          allow(SolrDocument).to receive(:find)
          allow(Hyrax::CollectionMemberService).to receive(:run).and_return([collection_solr_doc])
          expect(manifest_metadata).to eq [
            { "label" => "Collection",
              "value" => ["<a href='#{base_url}/collections/321cba'>My Cool Collection</a>"] }
          ]
        end
      end

      context "when the value has an empty string" do
        let(:attributes) { { "title_tesim" => ["This is a title."], "description_tesim" => [""] } }

        it "does not map the field with an empty string" do
          expect(manifest_metadata.flat_map(&:values)).not_to include([""])
          expect(manifest_metadata).to eq [{ "label" => "Title", "value" => ["This is a title."] }]
        end
      end

      context "when the value is an empty string" do
        let(:attributes) { { "description_tesim" => [""] } }

        it "returns and empty array" do
          expect(manifest_metadata).to eq []
        end
      end
    end

    context "for version 3 of the IIIF spec" do
      let(:version) { 3 }

      context "with a field that has some plain text" do
        let(:attributes) { { "title_tesim" => ["My Awesome Title"] } }

        # NOTE: this assumes the I18n.locale is set as :en
        it "maps the metadata accordingly" do
          expect(manifest_metadata).to eq [{ "label" => { "en" => ["Title"] },
                                             "value" => { "none" => ["My Awesome Title"] } }]
        end
      end

      context "with a field that contains a url string" do
        let(:attributes) { { "description_tesim" => ["A url like https://www.example.com/, cool!"] } }

        it "creates a link for the url string" do
          expect(manifest_metadata).to eq [
            { "label" => { "en" => ["Description"] },
              "value" => { "none" =>
                ["A url like <a href='https://www.example.com/' target='_blank'>https://www.example.com/</a>, cool!"] } }
          ]
        end
      end

      context "with a date" do
        let(:attributes) { { "date_modified_dtsi" => "2011-11-11T11:11:11Z" } }

        it "displays it just the date" do
          expect(manifest_metadata).to eq [{ "label" => { "en" => ["Date modified"] },
                                             "value" => { "none" => ["2011-11-11"] } }]
        end
      end

      context "with a faceted option" do
        let(:metadata_fields) { { creator: { render_as: :faceted } } }
        let(:attributes) { { "creator_tesim" => ["McAuthor, Arthur"] } }

        it "adds a link to the faceted search" do
          expect(manifest_metadata). to eq [
            { "label" => { "en" => ["Creator"] },
              "value" => { "none" =>
                ["<a href='#{base_url}/catalog?f%5Bcreator_sim%5D%5B%5D=McAuthor%2C+Arthur&locale=en'>McAuthor, Arthur</a>"] } }
          ]
        end
      end

      context "with an authority option" do
        context "rights statement" do
          let(:metadata_fields) { { rights_statement: { render_as: :rights_statement } } }
          let(:attributes) { { "rights_statement_tesim" => ["http://rightsstatements.org/vocab/InC-OW-EU/1.0/"] } }

          it "renders a link and displays a term" do
            expect(manifest_metadata).to eq [
              { "label" => { "en" => ["Rights statement"] },
                "value" => { "none" => [
                  "<a href='http://rightsstatements.org/vocab/InC-OW-EU/1.0/'>In Copyright - EU Orphan Work</a>"
                ] } }
            ]
          end
        end

        context "license" do
          let(:metadata_fields) { { license: { render_as: :license } } }
          let(:attributes) { { "license_tesim" => ["https://creativecommons.org/licenses/by-sa/4.0/"] } }

          it "renders a link and displays a term" do
            expect(manifest_metadata).to eq [
              { "label" => { "en" => ["License"] },
                "value" => { "none" => [
                  "<a href='https://creativecommons.org/licenses/by-sa/4.0/'>Creative Commons BY-SA Attribution-ShareAlike 4.0 International</a>"
                ] } }
            ]
          end
        end
      end

      context "when the work is apart of a collection" do
        let(:metadata_fields) { { collection: {} } }
        let(:collection_attributes) { { "id" => "321cba", "title_tesim" => ["My Cool Collection"] } }
        let(:collection_solr_doc) { SolrDocument.new(collection_attributes) }
        let(:attributes) { { "member_of_collection_ids_ssim" => "321cba" } }

        it "renders a link to the collection" do
          allow(SolrDocument).to receive(:find)
          allow(Hyrax::CollectionMemberService).to receive(:run).and_return([collection_solr_doc])
          expect(manifest_metadata).to eq [
            { "label" => { "en" => ["Collection"] },
              "value" => { "none" => ["<a href='#{base_url}/collections/321cba'>My Cool Collection</a>"] } }
          ]
        end

        context "with markup in its title" do
          let(:collection_attributes) { { "id" => "321cba", "title_tesim" => ["<b>Cool</b> & Co"] } }

          it "escapes it" do
            allow(SolrDocument).to receive(:find)
            allow(Hyrax::CollectionMemberService).to receive(:run).and_return([collection_solr_doc])
            expect(manifest_metadata.first['value']['none']).to eq ["<a href='#{base_url}/collections/321cba'>&lt;b&gt;Cool&lt;/b&gt; &amp; Co</a>"]
          end
        end
      end

      context "when the value has an empty string" do
        let(:attributes) { { "title_tesim" => ["This is a title."], "description_tesim" => [""] } }

        it "does not map the field with an empty string" do
          expect(manifest_metadata.flat_map(&:values)).not_to include({ "none" => [""] })
          expect(manifest_metadata).to eq [
            { "label" => { "en" => ["Title"] }, "value" => { "none" => ["This is a title."] } }
          ]
        end
      end

      context "when the value is an empty string" do
        let(:attributes) { { "description_tesim" => [""] } }

        it "returns and empty array" do
          expect(manifest_metadata).to eq []
        end
      end
    end
  end

  describe "with flexible fields" do
    subject(:metadata) do
      described_class.build_metadata_for(work: solr_hit, version: 3, fields: fields, current_ability: double(Ability), base_url: base_url)
                     .map { |entry| [entry['label']['en'].first, entry['value']['none']] }.to_h
    end

    let(:attributes) { { "id" => "w1" } }
    let(:uri) { 'http://rightsstatements.org/vocab/InC/1.0/' }
    let(:values) do
      { rights_statement: [uri], subject: ['poetry'], form: ['zines'], note: ['see https://example.com'], redirects: ['/old'],
        abstract: ['<b>Bold</b><script>x()</script><img src=x onerror=y()>'] }
    end
    let(:render_as) do
      { rights_statement: 'external_link', subject: 'faceted', form: 'linked', redirects: 'redirects_label', abstract: 'html',
        creators: 'compound' }
    end
    let(:fields) do
      values.keys.map { |name| IiifPrint::Field.new(name: name, label: name.to_s, options: { render_as: render_as[name] }) }
    end
    let(:presenter) { double(Hyrax::WorkShowPresenter, **values) }

    before do
      allow(IiifPrint::Flexibility).to receive(:applies_to?).and_return(true)
      allow(IiifPrint::Flexibility).to receive(:presenter_for).and_return(presenter)
      allow(presenter).to receive(:display_values_for) { |name| name == :rights_statement ? ['In Copyright'] : values[name] }
    end

    it "links a controlled term to its URI under its label" do
      expect(metadata['rights_statement']).to eq [%(<a href="#{uri}">In Copyright</a>)]
    end

    context "with a collection field and no collections" do
      let(:values) { { subject: ['poetry'] } }
      let(:fields) do
        [IiifPrint::Field.new(name: :subject, label: 'subject', options: { render_as: 'faceted' }),
         IiifPrint::Field.new(name: :collection, label: 'Collection')]
      end

      it "leaves it out, even though the presenter has no collection method" do
        expect(metadata.keys).to eq ['subject']
      end
    end

    context "for version 2 of the IIIF spec" do
      subject(:metadata) do
        described_class.build_metadata_for(work: solr_hit, version: 2, fields: fields, current_ability: double(Ability), base_url: base_url)
      end

      let(:values) { { rights_statement: [uri], subject: ['poetry'] } }

      it "renders the same values under plain labels" do
        expect(metadata).to eq [
          { 'label' => 'rights_statement', 'value' => [%(<a href="#{uri}">In Copyright</a>)] },
          { 'label' => 'subject', 'value' => ["<a href=\"#{base_url}/catalog?f%5Bsubject_sim%5D%5B%5D=poetry&amp;locale=en\">poetry</a>"] }
        ]
      end
    end

    it "links a faceted value to its facet and a linked value to its search" do
      expect(metadata['subject']).to eq ["<a href=\"#{base_url}/catalog?f%5Bsubject_sim%5D%5B%5D=poetry&amp;locale=en\">poetry</a>"]
      expect(metadata['form']).to eq ["<a href=\"#{base_url}/catalog?locale=en&amp;q=zines&amp;search_field=form\">zines</a>"]
    end

    it "links URLs in plain text and keeps only the html the show page allows" do
      expect(metadata['note'].first).to match(%r{href=['"]https://example.com['"]})
      expect(metadata['abstract'].first).to start_with('<b>Bold</b>x()')
      expect(metadata['abstract'].first).not_to match(/script|onerror/)
    end

    context "on a child work's canvas" do
      let(:attributes) { { "id" => "w1", "is_child_bsi" => true } }

      it "searches child works too" do
        expect(metadata['subject'].first).to include('include_child_works=true')
      end
    end

    context "with a rights statement or license the index has no label for" do
      let(:values) { { rights_statement: [uri], license: ['https://creativecommons.org/licenses/by/4.0/'] } }
      let(:render_as) { { rights_statement: 'rights_statement', license: 'license' } }

      before do
        allow(presenter).to receive(:display_values_for) { |name| values[name] }
        allow(Hyrax.config).to receive(:rights_statement_service_class).and_return(double(new: double(label: 'In Copyright')))
        allow(Hyrax.config).to receive(:license_service_class).and_return(double(new: double(label: 'CC BY 4.0')))
      end

      it "labels it from its Hyrax service" do
        expect(metadata['rights_statement']).to eq [%(<a href="#{uri}">In Copyright</a>)]
        expect(metadata['license']).to eq ['<a href="https://creativecommons.org/licenses/by/4.0/">CC BY 4.0</a>']
      end
    end

    context "with a rights statement rendered as an external link, on a Hyrax without indexed labels" do
      let(:values) { { rights_statement: [uri] } }
      let(:render_as) { { rights_statement: 'external_link' } }

      before do
        allow(presenter).to receive(:display_values_for) { |name| values[name] }
        allow(Hyrax.config).to receive(:rights_statement_service_class).and_return(double(new: double(label: 'In Copyright')))
      end

      it "labels it from its Hyrax service" do
        expect(metadata['rights_statement']).to eq [%(<a href="#{uri}">In Copyright</a>)]
      end
    end

    context "with html that IIIF does not allow, and a relative link" do
      let(:values) { { abstract: ['<div><strong>Big</strong> <a href="/catalog?q=x" target="_blank">see</a></div>'] } }
      let(:render_as) { { abstract: 'html' } }

      it "keeps only the tags IIIF allows, with links made absolute" do
        expect(metadata['abstract']).to eq ["Big <a href=\"#{base_url}/catalog?q=x\">see</a>"]
      end
    end

    context "with a controlled term and a registered label facet" do
      let(:values) { { subject: ['http://id.loc.gov/subjects/1'], form: ['http://vocab.getty.edu/aat/1'] } }
      let(:render_as) { { subject: 'faceted', form: 'linked' } }

      before do
        allow(presenter).to receive(:display_values_for) { |name| [name == :subject ? 'Poetry' : 'Zines'] }
        allow(CatalogController).to receive(:blacklight_config).and_return(double(facet_fields: { 'subject_label_sim' => {} }))
      end

      it "links a faceted value through the label facet, as Hyrax does" do
        expect(metadata['subject']).to eq ["<a href=\"#{base_url}/catalog?f%5Bsubject_label_sim%5D%5B%5D=Poetry&amp;locale=en\">Poetry</a>"]
      end

      it "searches a linked value by its label" do
        expect(metadata['form']).to eq ["<a href=\"#{base_url}/catalog?locale=en&amp;q=Zines&amp;search_field=form\">Zines</a>"]
      end
    end

    context "with labels keyed by value" do
      let(:values) { { subject: ['http://id.loc.gov/subjects/2', 'http://id.loc.gov/subjects/1'] } }
      let(:render_as) { { subject: 'faceted' } }

      it "pairs each value with its own label, whatever order they come in" do
        allow(presenter).to receive(:controlled_labels_for).with(:subject, values[:subject])
                                                           .and_return('http://id.loc.gov/subjects/1' => 'Poetry', 'http://id.loc.gov/subjects/2' => 'Zines')
        expect(metadata['subject'].map { |link| link[/>([^<]+)</, 1] }).to eq %w[Zines Poetry]
      end

      it "uses no labels when the indexed ones do not line up with the values" do
        allow(presenter).to receive(:display_values_for).and_return(['Poetry'])
        expect(metadata['subject'].map { |link| link[/>([^<]+)</, 1] }).to eq values[:subject]
      end
    end

    context "with a rights statement rendered as one and an indexed label" do
      let(:values) { { rights_statement: [uri] } }
      let(:render_as) { { rights_statement: 'rights_statement' } }

      before do
        allow(presenter).to receive(:display_values_for) { ['Indexed label'] }
        allow(Hyrax.config).to receive(:rights_statement_service_class).and_return(double(new: double(label: 'In Copyright')))
      end

      it "takes its label from the Hyrax service, as the show page does" do
        expect(metadata['rights_statement']).to eq [%(<a href="#{uri}">In Copyright</a>)]
      end
    end

    context "with a date" do
      let(:values) { { date_created: ['2000-10-03'] } }
      let(:render_as) { { date_created: 'date' } }

      it "formats it as the show page does" do
        expect(metadata['date_created']).to eq [Date.new(2000, 10, 3).to_formatted_s(:standard)]
      end
    end

    it "shows a redirect as its full address" do
      expect(metadata['redirects']).to eq ["<a href=\"#{base_url}/old\">#{base_url}/old</a>"]
    end

    context "with Hyrax's compound renderer" do
      let(:values) { { creators: [{ 'name' => 'Smith', 'role' => 'Editor' }, { 'role' => 'artist' }] } }
      let(:compound_renderer) do
        Class.new do
          def initialize(_field, values, options)
            @entry = values.first
            @subproperties = options[:subproperties]
          end

          def render_value
            rows = @entry.map do |key, value|
              %(<div class="sub"><span class="label">#{@subproperties[key][:label]}:</span> ) +
                %(<a href="/authorities/#{value}" target="_blank">#{value}</a><script>x()</script></div>)
            end
            %(<div class="values"><div class="entry">#{rows.join}</div></div>)
          end
        end
      end

      let(:solr_document) { double('SolrDocument') }
      let(:compound_schema) do
        double('Hyrax::CompoundSchema', definition_for: { subproperties: { 'name' => { label: 'Name' }, 'role' => { label: 'Role' } } })
      end

      before do
        stub_const('Hyrax::Renderers::CompoundAttributeRenderer', compound_renderer)
        stub_const('Hyrax::CompoundSchema', double(for_solr_document: compound_schema))
        allow(presenter).to receive(:solr_document).and_return(solr_document)
      end

      it "puts each entry in its own paragraph, one profile-labeled sub-property per line, IIIF-safe" do
        expect(metadata['creators']).to eq [
          %(<p><span>Name:</span> <a href="#{base_url}/authorities/Smith">Smith</a>x()<br>) +
          %(<span>Role:</span> <a href="#{base_url}/authorities/Editor">Editor</a>x()</p>) +
          %(<p><span>Role:</span> <a href="#{base_url}/authorities/artist">artist</a>x()</p>)
        ]
      end

      it "reads the sub-property labels from the record's compound schema" do
        metadata
        expect(Hyrax::CompoundSchema).to have_received(:for_solr_document).with(solr_document)
        expect(compound_schema).to have_received(:definition_for).with(:creators)
      end

      context "with an entry whose values are all blank" do
        let(:values) { { creators: [{ 'name' => 'Smith' }, { 'name' => '', 'role' => nil }] } }

        it "leaves it out" do
          expect(metadata['creators']).to eq [%(<p><span>Name:</span> <a href="#{base_url}/authorities/Smith">Smith</a>x()</p>)]
        end
      end

      context "with only entries whose values are all blank" do
        let(:values) { { creators: [{ 'name' => '', 'role' => nil }] } }

        it "leaves the field out" do
          expect(metadata).not_to have_key('creators')
        end
      end
    end

    context "with a compound field on a Hyrax without the compound renderer" do
      let(:values) { { creators: [{ 'name' => 'Smith & Co', 'role' => 'Editor' }, { 'name' => 'Jones' }] } }

      before { hide_const('Hyrax::Renderers::CompoundAttributeRenderer') }

      it "lists each entry's values, one per line" do
        expect(metadata['creators']).to eq ['<p>Smith &amp; Co<br>Editor</p><p>Jones</p>']
      end
    end

    context "with a compound field on a Hyrax without the compound schema" do
      let(:values) { { creators: [{ 'name' => 'Smith' }] } }
      let(:compound_renderer) { double('CompoundAttributeRenderer', new: double(render_value: '<div>Smith</div>')) }

      before do
        hide_const('Hyrax::CompoundSchema')
        stub_const('Hyrax::Renderers::CompoundAttributeRenderer', compound_renderer)
        allow(presenter).to receive(:solr_document).and_return(double('SolrDocument'))
      end

      it "renders each entry without sub-property labels" do
        expect(metadata['creators']).to eq ['<p>Smith</p>']
        expect(compound_renderer).to have_received(:new).with(:creators, [{ 'name' => 'Smith' }], subproperties: nil)
      end
    end
  end
end
