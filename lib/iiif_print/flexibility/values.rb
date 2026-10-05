# frozen_string_literal: true

module IiifPrint
  module Flexibility
    ##
    # A flexible field's values, read from the show presenter and rendered the way its profile's `render_as` renders
    # them on the show page.
    class Values
      # What IIIF Presentation 3.0 allows in a metadata value (section 4.5).
      IIIF_TAGS = %w[a b br i img p small span sub sup].freeze
      IIIF_ATTRIBUTES = %w[href src alt].freeze
      RIGHTS_SERVICES = %w[rights_statement license].freeze

      # @param work [SolrDocument, SolrHit]
      # @param presenter [#display_values_for] the record's show presenter
      # @param base_url [String]
      # @param autolink [#call] turns URLs in plain text into links
      def initialize(work:, presenter:, base_url:, autolink:)
        @work = work
        @presenter = presenter
        @base_url = base_url
        @autolink = autolink
      end

      # @return [Array] the field's values as stored, blanks dropped
      def raw(field_name)
        Array(@presenter.try(field_name)).reject(&:blank?)
      end

      # @return [Array<String>] the field's values as html
      def rendered(field_name, options)
        options ||= {}
        values = Array(@presenter.try(field_name)).reject(&:blank?)
        return [values.map { |entry| "<p>#{compound_value(field_name, entry)}</p>" }.join] if options[:render_as].to_s == 'compound'

        labels = labels_for(field_name, values)
        values.map { |value| value(field_name, value.to_s, labels[value.to_s], options) }
      end

      private

      # Keyed by value, as the show page's renderers get them in `options[:labels]`, and like them treating a blank
      # label, or one equal to its value, as none.
      def labels_for(field_name, values)
        labels = @presenter.try(:controlled_labels_for, field_name, values) || display_labels(field_name, values)
        labels.to_h.transform_keys(&:to_s).reject { |value, label| label.blank? || label.to_s == value }
      end

      # TODO: drop once Hyrax's PresentsAttributes#controlled_labels_for is public
      def display_labels(field_name, values)
        display = Array(@presenter.try(:display_values_for, field_name)).reject(&:blank?)
        return {} unless display.size == values.size

        values.map(&:to_s).zip(display.map(&:to_s)).to_h
      end

      def value(field_name, value, label, options)
        return search_value(options[:search_field] || field_name, value, label, options[:render_as].to_s) if %w[faceted linked].include?(options[:render_as].to_s)

        label = rights_label(field_name, options[:render_as].to_s, value, label)
        case options[:render_as].to_s
        when 'redirects_label' then link(File.join(@base_url, value), File.join(@base_url, value))
        when 'html' then sanitize_html(value)
        when 'date' then ERB::Util.h(formatted_date(value))
        else labeled_value(value, label)
        end
      end

      # Like Hyrax's faceted and linked renderers: a controlled term links by its label, through the label facet
      # when the catalog registers one.
      def search_value(field, value, label, render_as)
        return search_link({ search_field: field, q: label || value }, label || value) if render_as == 'linked'

        by_label = label.present? && label_facet?(field)
        search_link({ "f[#{field}#{'_label' if by_label}_sim][]": by_label ? label : value }, label || value)
      end

      def label_facet?(field)
        config = 'CatalogController'.safe_constantize.try(:blacklight_config)
        config.respond_to?(:facet_fields) && config.facet_fields.key?("#{field}_label_sim")
      end

      def search_link(params, text)
        params = params.merge(include_child_works: true) if @work["is_child_bsi"] == true
        link(File.join(@base_url, Rails.application.routes.url_helpers.search_catalog_path(**params, locale: I18n.locale)), text)
      end

      def labeled_value(value, label)
        return @autolink.call([ERB::Util.h(value)]).first if label.blank?
        return ERB::Util.h(label) unless value.match?(%r{\Ahttps?://\S+\z})

        link(value, label)
      end

      def formatted_date(value)
        Date.parse(value).to_formatted_s(:standard)
      rescue ArgumentError
        value
      end

      # A rights statement or license rendered as such takes its label from its Hyrax service, as the show page's
      # renderers do; one rendered otherwise falls back to the service only when no label was indexed.
      def rights_label(field_name, render_as, value, label)
        return service_label(render_as, value) || label if RIGHTS_SERVICES.include?(render_as)
        return label || service_label(field_name.to_s, value) if RIGHTS_SERVICES.include?(field_name.to_s)

        label
      end

      def service_label(service, value)
        Hyrax.config.try("#{service}_service_class")&.new&.label(value) { nil }
      end

      def sanitize_html(value)
        fragment = Nokogiri::HTML.fragment(value.to_s)
        { 'a' => 'href', 'img' => 'src' }.each do |tag, attribute|
          fragment.css("#{tag}[#{attribute}]").each { |node| node[attribute] = absolute_url(node[attribute]) }
        end
        Rails::Html::SafeListSanitizer.new.sanitize(fragment.to_html, tags: IIIF_TAGS, attributes: IIIF_ATTRIBUTES).strip
      end

      def absolute_url(url)
        return url if url.blank? || url.match?(/\A[a-z][a-z0-9+.-]*:/i)

        URI.join("#{@base_url.to_s.chomp('/')}/", url).to_s
      rescue URI::Error
        url
      end

      # One entry as Hyrax's compound renderer, and any decorator the app gives it, renders it on the show page, with
      # a line break where each innermost block ended, since IIIF allows no blocks.
      def compound_value(field_name, entry)
        renderer = Hyrax::Renderers::CompoundAttributeRenderer.new(field_name, [entry], subproperties: compound_subproperties(field_name))
        fragment = Nokogiri::HTML.fragment(renderer.render_value)
        fragment.css('div').each { |div| div.add_next_sibling('<br>') unless div.at_css('div') }
        sanitize_html(fragment.to_html).gsub(/\s*<br>\s*/, '<br>').sub(/(<br>)+\z/, '')
      end

      def compound_subproperties(field_name)
        @presenter.send(:compound_subproperties_for, field_name) if @presenter.respond_to?(:compound_subproperties_for, true)
      end

      def link(href, text)
        %(<a href="#{ERB::Util.h(href)}">#{ERB::Util.h(text)}</a>)
      end
    end
  end
end
