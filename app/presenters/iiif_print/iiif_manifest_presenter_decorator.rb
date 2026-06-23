# mixin to provide URL for IIIF Content Search service
module IiifPrint
  module IiifManifestPresenterDecorator
    extend ActiveSupport::Concern

    # Extending the presenter to the base url which includes the protocol.
    # We need the base url to render the facet links and normalize the interface.
    attr_accessor :base_url

    def manifest_metadata
      # ensure we are using a SolrDocument
      @manifest_metadata ||= IiifPrint.manifest_metadata_from(work: model.solr_document, presenter: self)
    end

    def search_service
      Rails.application.routes.url_helpers.solr_document_iiif_search_url(id, host: hostname)
    end

    # OVERRIDE: Hyrax 3x, avoid nil returning to IIIF Manifest gem
    # @see https://github.com/samvera/iiif_manifest/blob/c408f90eba11bef908796c7236ba6bcf8d687acc/lib/iiif_manifest/v3/manifest_builder/record_property_builder.rb#L28
    ##
    # @return [Array<Hash{String => String}>]
    def sequence_rendering
      Array(try(:rendering_ids)).map do |file_set_id|
        rendering = file_set_presenters.find { |p| p.id == file_set_id }
        return [] unless rendering

        { '@id' => Hyrax::Engine.routes.url_helpers.download_url(rendering.id, host: hostname),
          'format' => rendering.mime_type.presence || I18n.t("hyrax.manifest.unknown_mime_text"),
          'label' => I18n.t("hyrax.manifest.download_text") + (rendering.label || '') }
      end.flatten
    end
  end
end

module IiifPrint
  # Overrides the .for factory to return ExternalIiifDisplayImagePresenter for FileSets
  # when an external IIIF server is configured, instead of the default DisplayImagePresenter.
  module IiifManifestPresenterFactoryDecorator
    def for(model)
      return super unless model.file_set? && IiifPrint.config.external_iiif_url.present?

      IiifPrint::ExternalIiifDisplayImagePresenter.new(model)
    end
  end
end

Hyrax::IiifManifestPresenter.prepend(IiifPrint::IiifManifestPresenterDecorator)
Hyrax::IiifManifestPresenter.singleton_class.prepend(IiifPrint::IiifManifestPresenterFactoryDecorator)
