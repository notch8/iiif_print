# frozen_string_literal: true

require "iiif_print/flexibility/fields"
require "iiif_print/flexibility/values"

module IiifPrint
  ##
  # IIIF manifest metadata for records indexed under an M3 profile, built the way their show page is: which fields
  # from {IiifPrint::Flexibility::Fields}, and how each value renders from {IiifPrint::Flexibility::Values}.
  module Flexibility
    class << self
      ##
      # @return [Boolean] whether the record's metadata comes from its M3 profile
      def applies_to?(document)
        Hyrax.config.try(:flexible?) && document.try(:flexible?)
      end

      def presenter_for(document, ability)
        return Hyrax::FileSetPresenter.new(document, ability) if document.file_set?

        controller = "Hyrax::#{document.hydra_model.model_name.collection.camelize}Controller".safe_constantize
        (controller&.show_presenter || Hyrax::WorkShowPresenter).new(document, ability)
      end

      ##
      # The profile's view definitions for the record, plus its title, description and abstract when the profile
      # gives them no view block, since the show page shows those outside its field list.  Read once per request
      # for each tenant, schema, version and context; each tenant numbers its own profile versions.
      def view_definitions_for(document)
        cache = Current.view_definitions ||= {}
        version = document.try(:schema_version)
        contexts = document.try(:contexts)
        tenant = Apartment::Tenant.current if defined?(Apartment::Tenant)
        cache[[tenant, schema_name(document), version, contexts]] ||= begin
          definitions = Hyrax::Schema.m3_schema_loader.view_definitions_for(schema: schema_name(document), version: version, contexts: contexts)
          lead_definitions(document, definitions).merge(definitions.to_h.symbolize_keys)
        end
      end

      private

      LEAD_FIELDS = %i[title description abstract].freeze

      def lead_definitions(document, definitions)
        attributes = profile_attributes(document)
        (LEAD_FIELDS - definitions.to_h.keys.map(&:to_sym)).each_with_object({}) do |name, lead|
          config = attributes[name.to_s]
          lead[name] = Hyrax::SchemaLoader::AttributeDefinition.new(name.to_s, config).view_options if config
        end
      end

      def profile_attributes(document)
        schema = Hyrax::FlexibleSchema.find_by(id: document.try(:schema_version)) || Hyrax::FlexibleSchema.order(:created_at).last
        schema.try(:attributes_for, schema_name(document)) || {}
      end

      def schema_name(document)
        Valkyrie.config.resource_class_resolver.call(document.hydra_model_name).to_s
      rescue NameError
        document.hydra_model.to_s
      end
    end
  end
end
