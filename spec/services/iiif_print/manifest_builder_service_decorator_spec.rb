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

  describe '#sanitize_v3' do
    subject(:sanitized) { builder_service.send(:sanitize_v3, hash: hash, presenter: double('Presenter'), solr_doc_hits: []) }

    let(:builder_service) { Hyrax::ManifestBuilderService.new(version: 3).tap { |s| s.instance_variable_set(:@child_works, []) } }

    context 'with a manifest label' do
      let(:hash) { { 'label' => { 'none' => ['<script>alert(1)</script>My Work'] }, 'items' => [] } }

      it 'sanitizes it' do
        expect(sanitized['label']).to eq('none' => ['My Work'])
      end
    end

    context 'with labels in a language other than none' do
      let(:hash) do
        { 'label' => { 'en' => ['<script>alert(1)</script>My Work'] },
          'items' => [{ 'id' => 'http://example.com/canvas/fs1', 'label' => { 'en' => ['<script>alert(1)</script>Page 1'] } }] }
      end

      it 'sanitizes the manifest and canvas labels in that language' do
        expect(sanitized['label']).to eq('en' => ['My Work'])
        expect(sanitized['items'].first['label']).to eq('en' => ['Page 1'])
      end
    end

    context 'with a canvas that has no label' do
      let(:hash) { { 'items' => [{ 'id' => 'http://example.com/canvas/fs1' }] } }

      it 'leaves the canvas unchanged' do
        expect(sanitized['items']).to eq([{ 'id' => 'http://example.com/canvas/fs1' }])
      end
    end
  end
end
