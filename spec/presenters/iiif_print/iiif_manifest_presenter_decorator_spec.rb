require 'spec_helper'

RSpec.describe IiifPrint::IiifManifestPresenter::DisplayImagePresenterDecorator do
  subject(:presenter) { Hyrax::IiifManifestPresenter::DisplayImagePresenter.new(solr_doc) }

  let(:solr_doc) { SolrDocument.new('digest_ssim' => [digest_value]) }

  before { allow(ENV).to receive(:[]).and_call_original }

  describe '#external_latest_file_id' do
    context 'with a plain MD5 hex string (Valkyrie mode), no prefix' do
      let(:digest_value) { '542cd898c5be91687e6c6f2c4f53f2d5' }

      before { allow(ENV).to receive(:[]).with('IIIF_S3_FOLDER_PREFIX').and_return(nil) }

      it 'returns the hex as-is' do
        expect(presenter.send(:external_latest_file_id)).to eq '542cd898c5be91687e6c6f2c4f53f2d5'
      end
    end

    context 'with a plain MD5 hex string (Valkyrie mode), with prefix' do
      let(:digest_value) { '542cd898c5be91687e6c6f2c4f53f2d5' }

      before { allow(ENV).to receive(:[]).with('IIIF_S3_FOLDER_PREFIX').and_return('staging') }

      it 'percent-encodes the slash so the key is a single IIIF path segment' do
        expect(presenter.send(:external_latest_file_id)).to eq 'staging%2F542cd898c5be91687e6c6f2c4f53f2d5'
      end
    end

    context 'with a urn:sha1 value (Wings/Fedora mode), no prefix' do
      let(:digest_value) { 'urn:sha1:620cae0e5cf89d9a788cb7d8e31fcbfa78340284' }

      before { allow(ENV).to receive(:[]).with('IIIF_S3_FOLDER_PREFIX').and_return(nil) }

      it 'strips the URN prefix and returns the hex' do
        expect(presenter.send(:external_latest_file_id)).to eq '620cae0e5cf89d9a788cb7d8e31fcbfa78340284'
      end
    end

    context 'when digest_ssim is absent' do
      let(:solr_doc) { SolrDocument.new({}) }
      let(:digest_value) { nil }

      it 'returns nil' do
        expect(presenter.send(:external_latest_file_id)).to be_nil
      end
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
  let(:test_request) { ActionDispatch::TestRequest.new({}) }

  describe '#search_service' do
    it 'returns the correct URL for the IIIF Search service' do
      expect(presenter.search_service).to include("#{solr_document.id}/iiif_search")
    end
  end

  context 'with IIIF external support' do
    let(:presenter) { Hyrax::IiifManifestPresenter::DisplayImagePresenter.new(solr_document) }
    let(:id) { 'abc123' }
    let(:url) { 'external_iiif_url' }
    let(:iiif_info_url_builder) { ->(file_id, base_url) { "#{base_url}/#{file_id}" } }

    before { allow(solr_document).to receive(:image?).and_return(true) }

    context 'when external iiif is enabled' do
      before do
        allow(ENV).to receive(:[])
        allow(ENV).to receive(:[]).with('EXTERNAL_IIIF_URL').and_return(url)
        allow(presenter).to receive(:latest_file_id).and_return(id)
      end

      describe '#display_image' do
        it 'renders a external url' do
          expect(presenter.display_image.iiif_endpoint.url).to eq "#{url}/#{id}"
          expect(presenter.display_image.iiif_endpoint.profile).to eq "http://iiif.io/api/image/2/level2.json"
        end
      end

      describe '#display_content' do
        it 'renders a external url' do
          expect(presenter.display_content.iiif_endpoint.url).to eq "#{url}/#{id}"
          expect(presenter.display_content.iiif_endpoint.profile).to eq "http://iiif.io/api/image/2/level2.json"
        end
      end
    end

    context 'when external iiif is not enabled' do
      before do
        allow(presenter).to receive(:latest_file_id).and_return(id)
        allow(Hyrax.config).to receive(:iiif_image_server?).and_return(true)
        allow(Hyrax.config).to receive(:iiif_info_url_builder).and_return(iiif_info_url_builder)
      end

      describe '#display_image' do
        it 'does not render a external url' do
          expect(presenter.display_image.iiif_endpoint.url).to eq "localhost/#{id}"
        end
      end

      describe '#display_content' do
        it 'does not render a external url' do
          expect(presenter.display_content.iiif_endpoint.url).to eq "localhost/#{id}"
        end
      end
    end
  end
end
