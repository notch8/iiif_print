module IiifPrint
  ##
  # The PersistenceLayer module provides the namespace for other adapters:
  #
  # - {IiifPrint::PersistenceLayer::ActiveFedoraAdapter}
  # - {IiifPrint::PersistenceLayer::ValkyrieAdapter}
  #
  # And the defining interface in the {IiifPrint::PersistenceLayer::AbstractAdapter}
  module PersistenceLayer
    # @abstract
    class AbstractAdapter
      ##
      # @param object [Object]
      # @return [Array<Object>]
      def self.object_in_works(object)
        raise NotImplementedError, "#{self}.{__method__}"
      end

      ##
      # @param object [Object]
      # @return [Array<Object>]
      def self.object_ordered_works(object)
        raise NotImplementedError, "#{self}.{__method__}"
      end

      ##
      # @param work_type [Class]
      # @return the corresponding indexer for the work_type
      def self.decorate_with_adapter_logic(work_type:)
        raise NotImplementedError, "#{self}.{__method__}"
      end

      ##
      # @param work_type [Class]
      # @return the corresponding indexer for the work_type
      def self.decorate_form_with_adapter_logic(work_type:)
        raise NotImplementedError, "#{self}.{__method__}"
      end

      ##
      # @param file_set [Object]
      # @param work [Object]
      # @param model [Class] The class name for which we'll split children.
      def self.destroy_children_split_from(file_set:, work:, model:)
        raise NotImplementedError, "#{self}.{__method__}"
      end

      ##
      # @abstract
      def self.parent_for(*)
        raise NotImplementedError, "#{self}.{__method__}"
      end

      ##
      # @abstract
      def self.grandparent_for(*)
        raise NotImplementedError, "#{self}.{__method__}"
      end

      ##
      # @abstract
      def self.solr_field_query(*)
        raise NotImplementedError, "#{self}.{__method__}"
      end

      ##
      # @abstract
      def self.clean_for_tests!
        return false unless Rails.env.test?
        yield
      end

      ##
      # @abstract
      def self.solr_query(*args)
        raise NotImplementedError, "#{self}.{__method__}"
      end

      ##
      # @abstract
      def self.solr_name(*args)
        raise NotImplementedError, "#{self}.{__method__}"
      end

      def self.pdf?(_file_set)
        raise NotImplementedError, "#{self}.{__method__}"
      end

      def self.create_relationship_between(child_record:, parent_record:)
        raise NotImplementedError, "#{self}.{__method__}"
      end

      def self.find_by_title_for(title:, model:)
        raise NotImplementedError, "#{self}.{__method__}"
      end

      def self.find_by(id:)
        raise NotImplementedError, "#{self}.{__method__}"
      end

      def self.save(object:)
        raise NotImplementedError, "#{self}.{__method__}"
      end

      def self.index_works(objects:)
        raise NotImplementedError, "#{self}.{__method__}"
      end

      def self.copy_derivatives_from_data_store(stream:, directives:)
        raise NotImplementedError, "#{self}.{__method__}"
      end

      def self.extract_text_for(file_set:)
        raise NotImplementedError, "#{self}.{__method__}"
      end

      def self.pdf_path_for(file_set:)
        raise NotImplementedError, "#{self}.{__method__}"
      end
    end
  end
end
