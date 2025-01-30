require 'spec_helper'

RSpec.describe IiifPrint::IiifSearchDecorator do
  let(:iiif_config) { { object_relation_field: 'is_page_of_ssim' } }
  let(:parent_document) { double(SolrDocument, id: 'abc123') }
  let(:iiif_search) { BlacklightIiifSearch::IiifSearch.new(params, iiif_config, parent_document) }

  describe '#solr_params' do
    subject { iiif_search.solr_params }

    context 'when q is nil' do
      let(:params) { { q: nil } }

      it 'returns nil:nil' do
        expect(subject).to eq({ q: 'nil:nil' })
      end
    end

    context 'when q is not nil' do
      let(:params) { { q: 'catscan' } }

      it 'returns a query with the search term and filters for child or parent id' do
        expect(subject).to eq({ q: "catscan AND has_model_ssim:FileSet AND (is_page_of_ssim:\"abc123\" OR id:\"abc123\")", rows: 50, page: nil })
      end
    end
  end
end
