# frozen_string_literal: true
require 'cgi'

module IiifPrint
  # Presenter for FileSets when an external IIIF server is configured.
  # Returned by IiifManifestPresenter.for when IiifPrint.config.external_iiif_url is set.
  # Overrides only the three methods that control URL construction.
  class ExternalIiifDisplayImagePresenter < Hyrax::IiifManifestPresenter::DisplayImagePresenter
    def display_image_url(_base_url = nil)
      url_builder = Hyrax.config.iiif_image_url_builder
      args = [latest_file_id, IiifPrint.config.external_iiif_url, Hyrax.config.iiif_image_size_default]
      args << image_format(alpha_channels) if url_builder.arity == 4
      url_builder.call(*args).gsub(%r{images/}, '')
    end

    def iiif_endpoint(_file_id = nil, _base_url: nil)
      IIIFManifest::IIIFEndpoint.new(
        File.join(IiifPrint.config.external_iiif_url, latest_file_id),
        profile: Hyrax.config.iiif_image_compliance_level_uri
      )
    end

    private

    def latest_file_id
      @latest_file_id ||= begin
        hex = model.shrine_file_identifier || digest_hex
        return nil if hex.blank?

        prefix = IiifPrint.config.iiif_s3_folder_prefix.presence
        prefix ? CGI.escape("#{prefix}/#{hex}") : CGI.escape(hex)
      end
    end
  end
end
