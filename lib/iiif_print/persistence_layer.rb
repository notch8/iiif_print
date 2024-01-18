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
    end
  end
end
