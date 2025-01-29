module IiifPrint
  module PersistenceLayer
    class ActiveFedoraAdapter < AbstractAdapter
      ##
      # @param object [ActiveFedora::Base]
      # @return [Array<SolrDocument>]
      def self.object_in_works(object)
        object.in_works
      end

      ##
      # @param object [ActiveFedora::Base]
      # @return [Array<SolrDocument>]
      def self.object_ordered_works(object)
        object.ordered_works
      end

      ##
      # @param work_type [Class<ActiveFedora::Base>]
      # @return indexer for the given :work_type
      def self.decorate_with_adapter_logic(work_type:)
        work_type.send(:include, IiifPrint::SetChildFlag) unless work_type.included_modules.include?(IiifPrint::SetChildFlag)
        work_type.indexer
      end

      ##
      # @param work_type [Class<ActiveFedora::Base>]
      # @return indexer for the given :work_type
      def self.decorate_form_with_adapter_logic(work_type:)
        work_type.indexer
      end

      ##
      # Return the immediate parent of the given :file_set.
      #
      # @param file_set [FileSet]
      # @return [#work?, Hydra::PCDM::Work]
      # @return [NilClass] when no parent is found.
      def self.parent_for(file_set)
        # fallback to Fedora-stored relationships if work's aggregation of
        #   file set is not indexed in Solr
        file_set.parent || file_set.member_of.find(&:work?)
      end

      ##
      # Return the parent's parent of the given :file_set.
      #
      # @param file_set [FileSet]
      # @return [#work?, Hydra::PCDM::Work]
      # @return [NilClass] when no grand parent is found.
      def self.grandparent_for(file_set)
        parent_of_file_set = parent_for(file_set)
        # HACK: This is an assumption about the file_set structure, namely that an image page split from
        # a PDF is part of a file set that is a child of a work that is a child of a single work.  That
        # is, it only has one grand parent.  Which is a reasonable assumption for IIIF Print but is not
        # valid when extended beyond IIIF Print.  That is GenericWork does not have a parent method but
        # does have a parents method.
        parent_of_file_set.try(:parent_works).try(:first) ||
          parent_of_file_set.try(:parents).try(:first) ||
          parent_of_file_set&.member_of&.find(&:work?)
      end

      def self.solr_construct_query(*args)
        if defined?(Hyrax::SolrQueryBuilderService)
          Hyrax::SolrQueryBuilderService.construct_query(*args)
        else
          ActiveFedora::SolrQueryBuilder.construct_query(*args)
        end
      end

      def self.clean_for_tests!
        super do
          ActiveFedora::Cleaner.clean!
        end
      end

      def self.solr_query(query, **args)
        if defined?(ActiveFedora::SolrService)
          ActiveFedora::SolrService.query(query, **args)
        else
          Hyrax::SolrService.query(query, **args)
        end
      end

      def self.solr_name(field_name)
        if defined?(Hyrax) && Hyrax.config.respond_to?(:index_field_mapper)
          Hyrax.config.index_field_mapper.solr_name(field_name.to_s)
        else
          ::ActiveFedora.index_field_mapper.solr_name(field_name.to_s)
        end
      end

      ##
      # @param file_set [Object]
      # @param work [Object]
      # @param model [Class] The class name for which we'll split children.
      def self.destroy_children_split_from(file_set:, work:, model:, **_args)
        # look first for children by the file set id they were split from
        children = model.where(split_from_pdf_id: file_set.id)
        if children.blank?
          # find works where file name and work `to_param` are both in the title
          children = model.where(title: file_set.label).where(title: work.to_param)
        end
        return if children.blank?
        children.each do |rcd|
          rcd.destroy(eradicate: true)
        end
        true
      end

      def self.pdf?(file_set)
        file_set.class.pdf_mime_types.include?(file_set.mime_type)
      end

      ##
      # Add a child record as a member of a parent record
      #
      # @param model [child_record] an ActiveFedora::Base model
      # @param model [parent_record] an ActiveFedora::Base model
      # @return [TrueClass]
      def self.create_relationship_between(child_record:, parent_record:)
        return true if parent_record.ordered_members.to_a.include?(child_record)
        parent_record.ordered_members << child_record
        true
      end

      ##
      # find a work by title
      # We should only find one, but there is no guarantee of that and `:where` returns an array.
      #
      # @param title [String]
      # @param model [String] an ActiveFedora::Base model
      def self.find_by_title_for(title:, model:)
        work_type = model.constantize

        work_type.where(title: title)
      end

      ##
      # find a work or file_set
      #
      # @param id [String]
      # @return [Array<ActiveFedora::Base]
      def self.find_by(id:)
        ActiveFedora::Base.find(id)
      end

      ##
      # save a work
      #
      # @param object [Array<ActiveFedora::Base]
      def self.save(object:)
        object.save!
      end

      ##
      # reindex an array of works and their file_sets
      #
      # @param objects [Array<ActiveFedora::Base]
      # @return [TrueClass]
      def self.index_works(objects:)
        objects.each do |work|
          work.update_index
          work.file_sets.each(&:update_index) if work.respond_to?(:file_sets)
        end
        true
      end

      ##
      # does nothing for ActiveFedora;
      # allows valkyrie works to have an extra step to create the Hyrax::Metadata objects.
      #
      # @param []
      # @return [TrueClass]
      def self.copy_derivatives_from_data_store(*)
        true
      end

      ##
      # Extract text from the derivatives
      #
      # @param [FileSet] an ActiveFedora fileset
      # @return [String] Text from fileset's file
      def self.extract_text_for(file_set:)
        IiifPrint.config.all_text_generator_function.call(object: file_set) || ''
      end

      ##
      # Location of the file for resplitting
      #
      # @param [FileSet] an ActiveFedora fileset
      # @return [String] location of the original file
      def self.pdf_path_for(file_set:)
        Hyrax::WorkingDirectory.find_or_retrieve(file_set.files.first.id, file_set.id)
      end
    end
  end
end
