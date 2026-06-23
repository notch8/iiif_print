require 'spec_helper'

RSpec.describe IiifPrint::ExternalIiifDisplayImagePresenter do
  subject(:presenter) { described_class.new(solr_doc) }

  let(:solr_doc) { SolrDocument.new('digest_ssim' => [digest_value]) }
  let(:digest_value) { nil }

  before { allow(IiifPrint.config).to receive(:iiif_s3_folder_prefix).and_return(nil) }

  describe '#latest_file_id (private)' do
    context 'with a plain MD5 hex string (Valkyrie mode), no prefix' do
      let(:digest_value) { '542cd898c5be91687e6c6f2c4f53f2d5' }

      it 'CGI-escapes and returns the hex' do
        expect(presenter.send(:latest_file_id)).to eq '542cd898c5be91687e6c6f2c4f53f2d5'
      end
    end

    context 'with a plain MD5 hex string (Valkyrie mode), with prefix' do
      let(:digest_value) { '542cd898c5be91687e6c6f2c4f53f2d5' }

      before { allow(IiifPrint.config).to receive(:iiif_s3_folder_prefix).and_return('staging') }

      it 'percent-encodes the slash so the key is a single IIIF path segment' do
        expect(presenter.send(:latest_file_id)).to eq 'staging%2F542cd898c5be91687e6c6f2c4f53f2d5'
      end
    end

    context 'with a urn:sha1 value (Wings/Fedora mode), no prefix' do
      let(:digest_value) { 'urn:sha1:620cae0e5cf89d9a788cb7d8e31fcbfa78340284' }

      it 'strips the URN prefix and returns the hex' do
        expect(presenter.send(:latest_file_id)).to eq '620cae0e5cf89d9a788cb7d8e31fcbfa78340284'
      end
    end

    context 'when storage_file_identifier is present (Valkyrie storage)' do
      let(:solr_doc) { SolrDocument.new('storage_file_identifier_ss' => 'aabbccdd-1234/eeff9900-5678') }

      it 'returns the storage key with / encoded as %2F' do
        expect(presenter.send(:latest_file_id)).to eq 'aabbccdd-1234%2Feeff9900-5678'
      end
    end

    context 'when storage_file_identifier is present, digest_ssim is also present' do
      let(:solr_doc) do
        SolrDocument.new(
          'storage_file_identifier_ss' => 'aabbccdd-1234/eeff9900-5678',
          'digest_ssim' => ['542cd898c5be91687e6c6f2c4f53f2d5']
        )
      end

      it 'prefers the storage key over the digest' do
        expect(presenter.send(:latest_file_id)).to eq 'aabbccdd-1234%2Feeff9900-5678'
      end
    end

    context 'when no identifier is present' do
      let(:solr_doc) { SolrDocument.new({}) }

      it 'returns nil' do
        expect(presenter.send(:latest_file_id)).to be_nil
      end
    end
  end

  describe '#iiif_endpoint' do
    let(:url) { 'https://iiif.example.com/iiif/2' }

    before do
      allow(IiifPrint.config).to receive(:external_iiif_url).and_return(url)
      allow(presenter).to receive(:latest_file_id).and_return('abc%2Fdef')
    end

    it 'builds the endpoint from the external IIIF URL and file id' do
      expect(presenter.iiif_endpoint.url).to eq "#{url}/abc%2Fdef"
    end
  end
end

RSpec.describe IiifPrint::IiifManifestPresenterDecorator do
  let(:attributes) do
    { "id" => "abc123",
      "title_tesim" => ['Page the first'],
      "description_tesim" => ['A book or something'],
      "creator_tesim" => ['Arthur McAuthor'] }
  end
  let(:solr_document) { SolrDocument.new(attributes) }
  let(:presenter) { Hyrax::IiifManifestPresenter.new(solr_document) }

  describe '#search_service' do
    it 'returns the correct URL for the IIIF Search service' do
      expect(presenter.search_service).to include("#{solr_document.id}/iiif_search")
    end
  end

  describe '.for factory' do
    let(:file_set_doc) { SolrDocument.new('has_model_ssim' => ['FileSet']) }
    let(:work_doc) { SolrDocument.new('has_model_ssim' => ['GenericWork']) }

    before { allow(file_set_doc).to receive(:file_set?).and_return(true) }
    before { allow(work_doc).to receive(:file_set?).and_return(false) }

    context 'when external_iiif_url is configured' do
      before { allow(IiifPrint.config).to receive(:external_iiif_url).and_return('https://iiif.example.com') }

      it 'returns an ExternalIiifDisplayImagePresenter for FileSets' do
        expect(Hyrax::IiifManifestPresenter.for(file_set_doc)).to be_a(IiifPrint::ExternalIiifDisplayImagePresenter)
      end

      it 'returns a plain IiifManifestPresenter for works' do
        expect(Hyrax::IiifManifestPresenter.for(work_doc)).to be_a(Hyrax::IiifManifestPresenter)
      end
    end

    context 'when external_iiif_url is not configured' do
      before { allow(IiifPrint.config).to receive(:external_iiif_url).and_return(nil) }

      it 'returns a plain DisplayImagePresenter for FileSets' do
        expect(Hyrax::IiifManifestPresenter.for(file_set_doc)).to be_a(Hyrax::IiifManifestPresenter::DisplayImagePresenter)
        expect(Hyrax::IiifManifestPresenter.for(file_set_doc)).not_to be_a(IiifPrint::ExternalIiifDisplayImagePresenter)
      end
    end
  end
end
