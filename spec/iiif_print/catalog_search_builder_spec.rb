require 'spec_helper'
require 'support/show_parents_only_examples'

RSpec.describe IiifPrint::CatalogSearchBuilder do
  it_behaves_like 'a search builder that shows parent works only'

  # specs for IiifPrint::HighlightSearchParams
  describe 'highlight_search_params' do
    let(:solr_parameters) { { q: 'abolition' } }
    subject { described_class.new(solr_parameters) }

    it 'is included in the default_processor_chain' do
      expect(described_class.default_processor_chain).to include(:highlight_search_params)
    end

    before { subject.highlight_search_params(solr_parameters) }
    it 'adds the highlight fields to solr_parameters' do
      expect(solr_parameters[:hl]).to be_truthy
      expect(solr_parameters[:'hl.fl']).to eq('*')
    end
  end

  # specs for IiifPrint::ExcludeModels
  describe 'exclude_models' do
    let(:solr_parameters) { { all_fields: 'prohibition' } }
    subject { described_class.new(solr_parameters) }

    it 'is included in the default_processor_chain' do
      expect(described_class.default_processor_chain).to include(:exclude_models)
    end

    context 'with configured model name solr field values' do
      before do
        config = IiifPrint::Configuration.new.tap { |c| c.excluded_model_name_solr_field_values = ['Excluded Model', 'Another Excluded Model'] }
        subject.exclude_models(solr_parameters, config: config)
      end

      it 'adds the facet fields to solr_parameters with default key' do
        expect(solr_parameters[:fq]).to be_truthy
        expect(solr_parameters[:fq]).to(
          include("-human_readable_type_sim:\"Excluded Model\"", "-human_readable_type_sim:\"Another Excluded Model\"")
        )
      end

      context 'with configured model name solr field key' do
        before do
          config = IiifPrint::Configuration.new.tap do |c|
            c.excluded_model_name_solr_field_values = ['ExcludedModel', 'AnotherExcludedModel']
            c.excluded_model_name_solr_field_key = 'has_model_ssim'
          end
          subject.exclude_models(solr_parameters, config: config)
        end

        it 'adds the facet fields to solr_parameters with configured key' do
          expect(solr_parameters[:fq]).to be_truthy
          expect(solr_parameters[:fq]).to(
            include("-has_model_ssim:\"ExcludedModel\"", "-has_model_ssim:\"AnotherExcludedModel\"")
          )
        end
      end
    end
  end
end
