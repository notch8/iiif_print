require 'spec_helper'
RSpec.describe SolrDocument do
  let(:solr_doc) { described_class.new(id: 'foo', descendent_member_ids_ssim: ['bar']) }

  describe 'file_set_ids' do
    it 'responds to #file_set_ids' do
      expect(solr_doc).to respond_to(:file_set_ids)
    end

    it 'returns the correct value' do
      expect(solr_doc.file_set_ids).to eq(['bar'])
    end
  end

  describe 'iiif_print decorator' do
    it 'has extra attributes' do
      expect(solr_doc).to respond_to(:is_child)
      expect(solr_doc).to respond_to(:split_from_pdf_id)
      expect(solr_doc).to respond_to(:digest)
    end

    it 'has extra class attributes' do
      expect(described_class.iiif_print_solr_field_names).to eq %w[alternative_title genre
                                                                   issn lccn oclcnum held_by text_direction
                                                                   page_number section author photographer
                                                                   volume issue_number geographic_coverage
                                                                   extent publication_date height width
                                                                   edition_number edition_name frequency preceded_by
                                                                   succeeded_by]
    end

    it 'has a method that returns itself' do
      expect(solr_doc.solr_document).to be solr_doc
    end
  end
end
