module IiifPrint
  class Configuration
    attr_writer :excluded_model_name_solr_field_values
    # By default, this uses an array of human readable types
    #   ex: ['Generic Work', 'Image']
    # @return [Array<String>]
    def excluded_model_name_solr_field_values
      return @excluded_model_name_solr_field_values unless @excluded_model_name_solr_field_values.nil?
      @excluded_model_name_solr_field_values = []
    end

    attr_writer :excluded_model_name_solr_field_key
    # A string of a solr field key
    # @return [String]
    def excluded_model_name_solr_field_key
      return "human_readable_type_sim" unless defined?(@excluded_model_name_solr_field_key)
      @excluded_model_name_solr_field_key
    end

    attr_writer :default_iiif_manifest_version
    def default_iiif_manifest_version
      @default_iiif_manifest_version || 2
    end

    attr_writer :metadata_fields
    # rubocop:disable Metrics/MethodLength
    # @api private
    # @todo To move this to an `@api public` state, we need to consider what a proper configuration looks like.
    def metadata_fields
      @metadata_fields ||= {
        title: {},
        description: {},
        abstract: {},
        date_modified: {},
        creator: { render_as: :faceted },
        contributor: { render_as: :faceted },
        subject: { render_as: :faceted },
        publisher: { render_as: :faceted },
        language: { render_as: :faceted },
        identifier: { render_as: :linked },
        keyword: { render_as: :faceted },
        date_created: { render_as: :linked },
        based_near_label: {},
        related_url: { render_as: :external_link },
        resource_type: { render_as: :faceted },
        source: {},
        extent: {},
        rights_statement: { render_as: :rights_statement },
        rights_notes: {},
        access_right: {},
        license: { render_as: :license },
        searchable_text: {}
      }
    end
    # rubocop:enable Metrics/MethodLength
  end
end
