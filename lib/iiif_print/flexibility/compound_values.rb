# frozen_string_literal: true

module IiifPrint
  module Flexibility
    ##
    # A compound field's entries, one paragraph each, rendered the way its show page renders them.
    class CompoundValues
      # @return [Boolean] whether the entry has no value to show
      def self.blank_entry?(entry)
        Array(entry.try(:values) || entry).none?(&:present?)
      end

      # @param field_name [Symbol]
      # @param presenter [#solr_document] the record's show presenter
      # @param sanitize [#call] makes rendered html IIIF-safe
      def initialize(field_name, presenter:, sanitize:)
        @field_name = field_name
        @presenter = presenter
        @sanitize = sanitize
      end

      # @param entries [Array<Hash>]
      # @return [String] html
      def to_html(entries)
        subproperties = compound_subproperties
        entries.reject { |entry| self.class.blank_entry?(entry) }
               .map { |entry| "<p>#{entry_html(entry, subproperties)}</p>" }.join
      end

      private

      # As Hyrax's compound renderer, and any decorator the app gives it, renders the entry, with a line break where
      # each innermost block ended, since IIIF allows no blocks.
      def entry_html(entry, subproperties)
        return plain_html(entry) unless defined?(Hyrax::Renderers::CompoundAttributeRenderer)

        renderer = Hyrax::Renderers::CompoundAttributeRenderer.new(@field_name, [entry], subproperties: subproperties)
        fragment = Nokogiri::HTML.fragment(renderer.render_value)
        fragment.css('div').each { |div| div.add_next_sibling('<br>') unless div.at_css('div') }
        @sanitize.call(fragment.to_html).gsub(/\s*<br>\s*/, '<br>').sub(/(<br>)+\z/, '')
      end

      def plain_html(entry)
        Array(entry.try(:values) || entry).reject(&:blank?).map { |value| ERB::Util.h(value) }.join('<br>')
      end

      # The lookup Hyrax's PresentsAttributes#compound_subproperties_for makes, which is private.
      def compound_subproperties
        return unless defined?(Hyrax::CompoundSchema) && @presenter.respond_to?(:solr_document)

        Hyrax::CompoundSchema.for_solr_document(@presenter.solr_document).definition_for(@field_name)&.fetch(:subproperties, nil)
      rescue StandardError => e
        Rails.logger.debug("IiifPrint could not read #{@field_name}'s compound sub-properties: #{e.message}")
        nil
      end
    end
  end
end
