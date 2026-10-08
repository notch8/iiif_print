# frozen_string_literal: true

module IiifPrint
  module Flexibility
    ##
    # The fields a flexible record's show page lists, from its M3 profile: those an anonymous visitor may see and
    # its show presenter can render, labeled and ordered as the profile says, plus its collections.  Each carries
    # its view options, which {IiifPrint::Flexibility::Values} renders it by.
    class Fields
      # The show page leads with the title and description, then the work's collections.
      DEFAULT_ORDER = %i[title description abstract collection remaining].freeze

      # @param document [SolrDocument]
      # @param ability [Ability]
      # @param sort_order [Array<Symbol>] see {IiifPrint::Configuration#iiif_metadata_field_presentation_order};
      #   {DEFAULT_ORDER} when unset
      def initialize(document, ability, sort_order: IiifPrint.config.iiif_metadata_field_presentation_order)
        @document = document
        @ability = ability
        @sort_order = sort_order || DEFAULT_ORDER
      end

      # @return [Array<IiifPrint::Field>]
      def to_a
        presenter = Flexibility.presenter_for(@document, @ability)
        definitions = Flexibility.view_definitions_for(@document)
        fields = definitions.filter_map do |name, options|
          options = options.to_h.symbolize_keys
          term = (options[:render_term] || name).to_sym
          next unless public?(name, options) && (term == :collection || presenter.respond_to?(term))

          Field.new(name: term, label: label(term, options), options: options)
        end
        fields << collection_field unless collection_defined?(definitions)
        IiifPrint.sort_af_fields!(fields, sort_order: @sort_order)
      end

      private

      def collection_field
        Field.new(name: :collection, label: Hyrax::Renderers::AttributeRenderer.new(:collection, nil).label)
      end

      def collection_defined?(definitions)
        definitions.any? { |name, options| [name.to_s, options.to_h.symbolize_keys[:render_term].to_s].include?('collection') }
      end

      # The show page lists an admin note for editors only, whatever the profile says.
      def public?(name, options)
        return false if name.to_s == 'admin_note'

        !(options[:admin_only] || options[:editor_only] || options[:show_page] == false)
      end

      # Mirrors Hyrax's AttributesHelper#conform_options, so a field is labeled as its show page labels it.
      def label(name, options)
        labels = options[:display_label] || {}
        label = (labels[I18n.locale.to_s] || labels['default'] || name).to_s
        translated = I18n.t(label, default: label) if label.include?('.')
        return translated if translated && translated != label

        I18n.t(:"blacklight.search.fields.index.#{label}",
               default: [:"blacklight.search.fields.show.#{label}", :"blacklight.search.fields.#{label}", label.humanize])
      end
    end
  end
end
