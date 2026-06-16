require 'cgi'

# mixin to provide URL for IIIF Content Search service
module IiifPrint
  module IiifManifestPresenter
    # OVERRIDE: Hyrax v3.x
    module DisplayImagePresenterDecorator
      extend ActiveSupport::Concern
      # Extending the presenter to the base url which includes the protocol.
      # We need the base url to render the facet links and normalize the interface.
      attr_accessor :base_url

      # Extending this class because there is an #ability= but not #ability and this definition
      # mirrors the Hyrax::IiifManifestPresenter#ability.
      def ability
        @ability ||= NullAbility.new
      end

      def display_image
        return nil unless latest_file_id
        return nil unless model.image?
        return nil unless IiifPrint.config.default_iiif_manifest_version == 2

        IIIFManifest::DisplayImage
          .new(display_image_url(hostname),
            format: image_format(alpha_channels),
            width: width,
            height: height,
            iiif_endpoint: iiif_endpoint(latest_file_id, base_url: hostname))
      end

      # OVERRIDE: IIIF Hyrax AV v0.2 #display_content for prez 3 manifests
      def display_content
        return nil unless latest_file_id
        return super unless model.image?

        IIIFManifest::V3::DisplayContent
          .new(display_image_url(hostname),
            format: image_format(alpha_channels),
            width: width,
            height: height,
            type: 'Image',
            iiif_endpoint: iiif_endpoint(latest_file_id, base_url: hostname))
      end

      def display_image_url(base_url)
        if ENV['EXTERNAL_IIIF_URL'].present?
          # At the moment we are only concerned about Hyrax's default image url builder
          iiif_image_url_builder(url_builder: Hyrax.config.iiif_image_url_builder)
        else
          super
        end
      end

      def iiif_endpoint(file_id, base_url: request.base_url)
        if ENV['EXTERNAL_IIIF_URL'].present?
          IIIFManifest::IIIFEndpoint.new(
            File.join(ENV['EXTERNAL_IIIF_URL'], file_id),
            profile: Hyrax.config.iiif_image_compliance_level_uri
          )
        else
          super
        end
      end

      def hostname
        @hostname || 'localhost'
      end

      ##
      # @return [Boolean] false
      def work?
        false
      end

      private

      def latest_file_id
        if ENV['EXTERNAL_IIIF_URL'].present?
          external_latest_file_id
        else
          super
        end
      end

      def external_latest_file_id
        hex = digest_hex
        return nil if hex.blank?

        prefix = ENV['IIIF_S3_FOLDER_PREFIX'].presence
        return hex unless prefix

        CGI.escape("#{prefix}/#{hex}")
      end

      def iiif_image_url_builder(url_builder:)
        args = [
          latest_file_id,
          ENV['EXTERNAL_IIIF_URL'],
          Hyrax.config.iiif_image_size_default
        ]
        # In Hyrax 3, Hyrax.config.iiif_image_url_builder takes an additional argument
        args << image_format(alpha_channels) if url_builder.arity == 4

        url_builder.call(*args).gsub(%r{images/}, '')
      end
    end
  end
end
Hyrax::IiifManifestPresenter::DisplayImagePresenter.prepend(IiifPrint::IiifManifestPresenter::DisplayImagePresenterDecorator)
