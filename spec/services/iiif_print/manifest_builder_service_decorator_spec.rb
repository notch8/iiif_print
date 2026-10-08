# frozen_string_literal: true
require 'spec_helper'

RSpec.describe IiifPrint::ManifestBuilderServiceDecorator do
  context '#initialize' do
    it 'uses defaults to set the version' do
      builder_service = Hyrax::ManifestBuilderService.new
      expect(builder_service.manifest_factory).to eq(::IIIFManifest::ManifestFactory)
      expect(builder_service.version).to eq(IiifPrint.config.default_iiif_manifest_version)
    end

    it 'allows version overrides' do
      # This in part verifies the expected interaction of the version as a parameter being picked up
      # by another parameter.
      builder_service = Hyrax::ManifestBuilderService.new(version: 3)
      expect(builder_service.manifest_factory).to eq(::IIIFManifest::V3::ManifestFactory)
      expect(builder_service.version).to eq(3)
    end
  end

  context '#sanitize_v3' do
    subject(:builder_service) { Hyrax::ManifestBuilderService.new(version: 3) }

    def sanitize(hash)
      builder_service.send(:sanitize_v3, hash: hash, presenter: nil, solr_doc_hits: nil)
    end

    it 'returns a manifest that has no canvases' do
      hash = { 'label' => { 'none' => ['Moomin'] } }

      expect(sanitize(hash)).to eq('label' => { 'none' => ['Moomin'] })
    end

    it 'unescapes the manifest label' do
      hash = { 'label' => { 'none' => ['Moomin &amp; Co'] } }

      expect(sanitize(hash)['label']['none']).to eq(['Moomin & Co'])
    end

    it 'leaves a manifest with no label alone' do
      expect { sanitize({}) }.not_to raise_error
    end
  end
end
