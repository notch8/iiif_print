# rubocop:disable Metrics/ClassLength

module IiifPrint
  module PersistenceLayer
    class ValkyrieAdapter < AbstractAdapter
      ##
      # @param object [Valkyrie::Resource]
      # @return [Array<Valkyrie::Resource>]
      def self.object_in_works(object)
        Array.wrap(Hyrax.custom_queries.find_parent_work(resource: object))
      end

      ##
      # @param object [Valkyrie::Resource]
      # @return [Array<Valkyrie::Resource>]
      def self.object_ordered_works(object)
        Hyrax.custom_queries.find_child_works(resource: object).to_a
      end

      ##
      # @param work_type [Class<Valkyrie::Resource>]
      # @return the indexer for the given :work_type
      def self.decorate_with_adapter_logic(work_type:)
        work_type.send(:include, Hyrax::Schema(:child_works_from_pdf_splitting)) unless
          Hyrax.config.try(:work_include_metadata?) || Hyrax.config.try(:flexible?) || work_type.included_modules.include?(Hyrax::Schema(:child_works_from_pdf_splitting))
        # TODO: Use `Hyrax::ValkyrieIndexer.indexer_class_for` once changes are merged.
        indexer = "#{work_type}Indexer".constantize
        indexer.send(:include, Hyrax::Indexer(:child_works_from_pdf_splitting)) unless
          Hyrax.config.try(:work_include_metadata?) || Hyrax.config.try(:flexible?) || indexer.included_modules.include?(Hyrax::Indexer(:child_works_from_pdf_splitting))
        indexer
      end

      ##
      # @param work_type [Class<ActiveFedora::Base>]
      # @return form for the given :work_type
      def self.decorate_form_with_adapter_logic(work_type:)
        form = "#{work_type}Form".constantize
        form.send(:include, Hyrax::FormFields(:child_works_from_pdf_splitting)) unless
          Hyrax.config.try(:work_include_metadata?) || Hyrax.config.try(:flexible?) || form.included_modules.include?(Hyrax::FormFields(:child_works_from_pdf_splitting))
        form
      end

      ##
      # Return the immediate parent of the given :file_set.
      #
      # @param file_set [Hyrax::FileMetadata or FileSet]
      # @return [#work?, Hydra::PCDM::Work]
      # @return [NilClass] when no parent is found.
      def self.parent_for(file_set)
        file_set = Hyrax.query_service.find_by(id: file_set.file_set_id) if file_set.is_a?(Hyrax::FileMetadata)
        Hyrax.query_service.find_parents(resource: file_set).first
      end

      ##
      # Return the parent's parent of the given :file_set.
      #
      # @param file_set [Hyrax::FileMetadata or FileSet]
      # @return [#work?, Hydra::PCDM::Work]
      # @return [NilClass] when no grand parent is found.
      def self.grandparent_for(file_set)
        parent = parent_for(file_set)
        return nil unless parent
        Hyrax.query_service.find_parents(resource: parent).first
      end

      def self.solr_construct_query(*args)
        Hyrax::SolrQueryBuilderService.construct_query(*args)
      end

      def self.clean_for_tests!
        # For Fedora backed repositories, we'll want to consider some cleaning mechanism.  For
        # database backed repositories, we can rely on the database_cleaner gem.
        raise NotImplementedError
      end

      def self.solr_query(query, **args)
        Hyrax::SolrService.query(query, **args)
      end

      def self.solr_name(field_name)
        Hyrax.config.index_field_mapper.solr_name(field_name.to_s)
      end

      # NOTE: this isn't the most efficient method, but it is the most reliable.
      #  Attribute 'split_from_pdf_id' is saved in Valkyrie as a string rather than as { id: string },
      #    so we can't use the 'find_inverse_references_by' query.
      #  Additionally, the attribute does not exist on all child works, as it was added later, so using
      #    a child work's title allows us to find child works when the attribute isn't present.
      #  Building a custom query to find these child works directly via the attribute would be more efficient.
      #    However, it would require more effort for a lesser-used feature, and would not allow for the fallback
      #    of finding child works by title.
      # rubocop:disable Lint/UnusedMethodArgument, Metrics/AbcSize, Metrics/MethodLength
      def self.destroy_children_split_from(file_set:, work:, model:, user:)
        all_child_works = Hyrax.custom_queries.find_child_works(resource: work)
        return if all_child_works.blank?
        # look first for children by the file set id they were split from
        children = all_child_works.select { |m| m.split_from_pdf_id == file_set.id }
        if children.blank?
          # find works where file name and work `to_param` are both in the title
          children = all_child_works.select { |m| m.title.include?(file_set.label) && m.title.include?(work.to_param) }
        end
        return if children.blank?
        # we have to update the work's members first, then delete the children
        # otherwise Hyrax tries to save the parent as each child is deleted, resulting
        # in failing jobs
        remaining_members = work.member_ids - children.map(&:id)
        work.member_ids = remaining_members
        Hyrax.persister.save(resource: work)
        Hyrax.index_adapter.save(resource: work)
        Hyrax.publisher.publish('object.membership.updated', object: work, user: user)

        children.each do |rcd|
          Hyrax.persister.delete(resource: rcd)
          Hyrax.index_adapter.delete(resource: rcd)
          Hyrax.publisher.publish('object.deleted', object: rcd, user: user)
        end
        true
      end
      # rubocop:enable Lint/UnusedMethodArgument, Metrics/AbcSize, Metrics/MethodLength

      def self.pdf?(file_set)
        file_set.original_file&.pdf?
      end

      ##
      # Add a child record as a member of a parent record
      #
      # @param model [child_record] a Valkyrie::Resource model
      # @param model [parent_record] a Valkyrie::Resource model
      # @return [TrueClass]
      def self.create_relationship_between(child_record:, parent_record:)
        return true if parent_record.member_ids.include?(child_record.id)
        parent_record.member_ids << child_record.id
        true
      end

      ##
      # find a work by title
      # We should only find one, but there is no guarantee of that
      # @param title [String]
      # @param model [String] a Valkyrie::Resource model
      # @return [Array<Valkyrie::Resource]
      def self.find_by_title_for(title:, model:)
        work_type = model.constantize
        # TODO: This creates a hard dependency on Bulkrax because that is where this custom query is defined
        #       Is this adequate?
        Array.wrap(Hyrax.query_service.custom_query.find_by_model_and_property_value(model: work_type,
                                                                                     property: :title,
                                                                                     value: title))
      end

      ##
      # find a work or file_set
      #
      # @param id [String]
      def self.find_by(id:)
        Hyrax.query_service.find_by(id: id)
      end

      ##
      # save a work
      #
      # @param object [Array<Valkyrie::Resource]
      def self.save(object:)
        Hyrax.persister.save(resource: object)
        Hyrax.index_adapter.save(resource: object)

        Hyrax.publisher.publish('object.membership.updated', object: object, user: object.depositor)
      end

      ##
      # reindex an array of works and their file_sets
      #
      # @param objects [Array<Valkyrie::Resource]
      # @return [TrueClass]
      def self.index_works(objects:)
        objects.each do |work|
          Hyrax.index_adapter.save(resource: work)
          Hyrax.custom_queries.find_child_file_sets(resource: work).each do |file_set|
            Hyrax.index_adapter.save(resource: file_set)
          end
        end
        true
      end

      ##
      # Performs an extra step to create the Hyrax::Metadata objects
      # for derivatives.
      #
      # @param []
      # @return [TrueClass]
      def self.copy_derivatives_from_data_store(stream:, directives:)
        Hyrax::ValkyriePersistDerivatives.call(stream, directives)
      end

      ##
      # Extract text from the derivatives
      #
      # @param [Hyrax::FileSet] a Valkyrie fileset
      # @return [String] Text from fileset's file
      def self.extract_text_for(file_set:)
        fm = Hyrax.custom_queries.find_many_file_metadata_by_use(resource: file_set,
        use: Hyrax::FileMetadata::Use.uri_for(use: :extracted_file))
        return if fm.empty?
        text_fm = fm.find { |t| t.mime_type == Marcel::MimeType.for(extension: 'txt') }
        return if text_fm.nil?
        text_fm.content
      end

      ##
      # Location of the file for resplitting
      #
      # @param [Hyrax::FileSet] a Valkyrie fileset
      # @return [String] location of the original file
      def self.pdf_path_for(file_set:)
        file = file_set.original_file
        return '' unless file.pdf?
        file.file.disk_path.to_s
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength
