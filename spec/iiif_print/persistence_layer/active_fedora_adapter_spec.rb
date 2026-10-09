# frozen_string_literal: true

require 'spec_helper'

RSpec.describe IiifPrint::PersistenceLayer::ActiveFedoraAdapter do
  describe '.solr_construct_query' do
    it 'still builds the query, with a deprecation warning' do
      builder = defined?(Hyrax::SolrQueryBuilderService) ? Hyrax::SolrQueryBuilderService : ActiveFedora::SolrQueryBuilder
      allow(Deprecation).to receive(:warn)
      expect(described_class.solr_construct_query(is_child_bsi: 'true'))
        .to eq builder.construct_query(is_child_bsi: 'true')
      expect(Deprecation).to have_received(:warn).with(described_class, /IiifPrint 4\.0/)
    end
  end
end
