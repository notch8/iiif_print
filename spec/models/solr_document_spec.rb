require 'spec_helper'
RSpec.describe SolrDocument do
  let(:solr_doc) { described_class.new(id: 'foo', descendent_member_ids_ssim: ['bar']) }

  describe '#digest_hex' do
    subject(:hex) { described_class.new('digest_ssim' => [raw]).digest_hex }

    context 'with a urn:sha1 value (Wings/Fedora mode)' do
      let(:raw) { 'urn:sha1:620cae0e5cf89d9a788cb7d8e31fcbfa78340284' }

      it 'returns the hex portion' do
        expect(hex).to eq '620cae0e5cf89d9a788cb7d8e31fcbfa78340284'
      end
    end

    context 'with a urn:md5 value' do
      let(:raw) { 'urn:md5:542cd898c5be91687e6c6f2c4f53f2d5' }

      it 'returns the hex portion' do
        expect(hex).to eq '542cd898c5be91687e6c6f2c4f53f2d5'
      end
    end

    context 'with a plain hex string (Valkyrie mode)' do
      let(:raw) { '542cd898c5be91687e6c6f2c4f53f2d5' }

      it 'returns the hex string as-is' do
        expect(hex).to eq '542cd898c5be91687e6c6f2c4f53f2d5'
      end
    end

    context 'when digest_ssim is absent' do
      subject(:hex) { described_class.new({}).digest_hex }

      it { is_expected.to be_nil }
    end
  end

  describe '#digest_sha1' do
    it 'is deprecated and delegates to #digest_hex' do
      doc = described_class.new('digest_ssim' => ['urn:sha1:620cae0e5cf89d9a788cb7d8e31fcbfa78340284'])
      expect(Deprecation).to receive(:warn)
      expect(doc.digest_sha1).to eq doc.digest_hex
    end
  end

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
