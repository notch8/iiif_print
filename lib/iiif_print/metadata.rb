module IiifPrint
  # rubocop:disable Metrics/ClassLength
  class Metadata
    def self.build_metadata_for(work:, version:, fields:, current_ability:, base_url:)
      new(work: work,
          version: version,
          fields: fields,
          current_ability: current_ability,
          base_url: base_url).build_metadata
    end

    def initialize(work:, version:, fields:, current_ability:, base_url:)
      @work = work
      @version = version.to_i
      @fields = fields
      @current_ability = current_ability
      @base_url = base_url
    end

    attr_reader :work, :version, :fields, :current_ability

    def build_metadata
      fields.map do |field|
        values = values_for(field_name: field)
        if field.name == :collection && member_of_collection? && viewable_collections.present?
          { 'label' => metadata_map(field, :label),
            'value' => metadata_map(field, :collection) }
        elsif values.present? && !empty_string?(values)
          { 'label' => metadata_map(field, :label),
            'value' => metadata_map(field, :value) }
        end
      end.compact
    end

    private

    def metadata_map(field, property)
      if version == 2
        case property
        when :label      then field.label
        when :value      then rendered_values_for(field)
        when :collection then make_collection_link(viewable_collections)
        end
      elsif version == 3
        case property
        when :label      then { I18n.locale.to_s => [field.label] }
        when :value      then { 'none' => rendered_values_for(field) }
        when :collection then { 'none' => make_collection_link(viewable_collections) }
        end
      end
    end

    # Bulkrax imports values as [""] if there isn't a value but still a header,
    # these fields should not show in the metadata pane
    def empty_string?(values)
      values.uniq.size == 1 ? values.first == "" : false
    end

    def member_of_collection?
      work[:member_of_collection_ids_ssim]&.present?
    end

    def scrub(value)
      Loofah.fragment(value).scrub!(:whitewash).to_s
    end

    def rendered_values_for(field)
      return flexible_values.rendered(field.name, field.options) if flexible?

      cast_to_value(field_name: field.name, options: field.options)
    end

    def cast_to_value(field_name:, options:)
      if options&.[](:render_as) == :faceted
        faceted_values_for(field_name: field_name)
      elsif qa_field?(field_name: options&.dig(:render_as) || field_name)
        authority_values_for(field_name: field_name)
      else
        make_link(values_for(field_name: field_name))
      end
    end

    def faceted_values_for(field_name:)
      values_for(field_name: field_name).map do |value|
        search_field = field_name.to_s + "_sim"
        path = Rails.application.routes.url_helpers.search_catalog_path(
          "f[#{search_field}][]": value, locale: I18n.locale
        )
        path += '&include_child_works=true' if work["is_child_bsi"] == true
        "<a href='#{File.join(@base_url, path)}'>#{value}</a>"
      end
    end

    def qa_field?(field_name:, questioning_authority_fields: IiifPrint.config.questioning_authority_fields)
      questioning_authority_fields.include?(field_name.to_s)
    end

    def authority_values_for(field_name:)
      authority = Qa::Authorities::Local.subauthority_for(field_name.to_s.pluralize)
      values_for(field_name: field_name).map do |value|
        id, term = authority.find(value).values_at('id', 'term')
        "<a href='#{id}'>#{term}</a>"
      end
    end

    def values_for(field_name:)
      return flexible_values.raw(field_name.try(:name) || field_name) if flexible?

      field_name = field_name.try(:name) || field_name
      # TODO: we are assuming tesim or dtsi (for dates), might want to account for other suffixes in the future
      Array(work["#{field_name}_tesim"] || work["#{field_name}_dtsi"]&.to_date.try(:to_formatted_s, :standard))
    end

    def flexible?
      Flexibility.applies_to?(work)
    end

    def flexible_values
      @flexible_values ||= Flexibility::Values.new(work: work, presenter: Flexibility.presenter_for(work, current_ability),
                                                  base_url: @base_url, autolink: method(:make_link))
    end

    def make_collection_link(collection_documents)
      collection_documents.map do |collection|
        "<a href='#{File.join(@base_url, 'collections', collection.id)}'>#{ERB::Util.h(collection.title.first)}</a>"
      end
    end

    def viewable_collections
      Hyrax::CollectionMemberService.run(SolrDocument.find(work.id), current_ability)
    end

    # @note This method turns link looking strings into links and assumes https if not protocol was given
    def make_link(texts)
      texts.map do |t|
        t.to_s.gsub(MAKE_LINK_REGEX) do |url|
          protocol = url.start_with?('www.') ? 'https://' : ''
          "<a href='#{protocol}#{url}' target='_blank'>#{url}</a>"
        end
      end
    end

    MAKE_LINK_REGEX = %r{
      \b
      (
        (?:
          (?:https?://) |
          (?:www\.)
        )
        (?:
          [^\s()<>]+ | \(([^\s()<>]+|(\([^\s()<>]+\)))*\)
        )+
        (?:
          \(([^\s()<>]+|(\([^\s()<>]+\)))*\) |
          [^\s`!()\[\]{};:'".,<>?«»〝〞‘‛]
        )
      )
    }ix.freeze
  end
  # rubocop:enable Metrics/ClassLength
end
