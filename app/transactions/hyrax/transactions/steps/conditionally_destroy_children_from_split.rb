module Hyrax
  module Transactions
    module Steps
      ##
      # For a FileSet that is a PDF, we need to delete any works and file_sets that are the result of
      # splitting that PDF into constituent images of each page of the PDF.  This is responsible for
      # that work.
      class ConditionallyDestroyChildrenFromSplit
        include Dry::Monads[:result]

        ##
        # @param resource [Hyrax::FileSet]
        def call(resource, user: nil)
          return Failure(:resource_not_persisted) unless resource.persisted?

          parent = IiifPrint.persistence_adapter.parent_for(resource)
          return Success(resource) unless parent

          # We do not care about the results of this call; as it is conditionally looking for things
          # to destroy.
          IiifPrint::SplitPdfs::DestroyPdfChildWorksService.conditionally_destroy_spawned_children_of(
            file_set: resource,
            work: parent,
            user: user
          )

          Success(resource)
        end
      end
    end
  end
end
