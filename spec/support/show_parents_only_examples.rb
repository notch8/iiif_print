# frozen_string_literal: true

RSpec.shared_examples 'a search builder that shows parent works only' do
  describe '#show_parents_only' do
    let(:builder) { described_class.new(double('scope', blacklight_config: CatalogController.blacklight_config)) }
    let(:documents) do
      [{ id: 'show-parents-unflagged', has_model_ssim: ['ShowParentsOnlyProbe'] },
       { id: 'show-parents-not-child', has_model_ssim: ['ShowParentsOnlyProbe'], is_child_bsi: false },
       { id: 'show-parents-child', has_model_ssim: ['ShowParentsOnlyProbe'], is_child_bsi: true }]
    end

    before { Hyrax::SolrService.add(documents, commit: true) }
    after { Hyrax::SolrService.delete_by_query('has_model_ssim:ShowParentsOnlyProbe', commit: true) }

    def ids_found(params)
      solr_parameters = { fq: [] }
      builder.with(params).show_parents_only(solr_parameters)
      Hyrax::SolrService.query('has_model_ssim:ShowParentsOnlyProbe', fq: solr_parameters[:fq], fl: 'id', rows: 10)
                        .map { |document| document['id'] }.sort
    end

    it 'finds every work that is not a child, whether or not it is flagged' do
      expect(ids_found({})).to eq %w[show-parents-not-child show-parents-unflagged]
    end

    it 'finds child works when asked to include them' do
      expect(ids_found('include_child_works' => 'true')).to eq %w[show-parents-child]
    end
  end
end
