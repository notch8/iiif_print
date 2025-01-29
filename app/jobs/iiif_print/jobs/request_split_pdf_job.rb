module IiifPrint
  module Jobs
    ##
    # Encapsulates logic for cleanup when the PDF is destroyed after pdf splitting into child works
    class RequestSplitPdfJob < IiifPrint::Jobs::ApplicationJob
      ##
      # @param file_set_id [FileSet id]
      # @param user [User]
      # rubocop:disable Metrics/MethodLength
      def perform(file_set_id:, user:)
        file_set = IiifPrint.find_by(id: file_set_id)
        return true unless IiifPrint.pdf?(file_set)
        work = IiifPrint.parent_for(file_set)

        # Woe is ye who changes the configuration of the model, thus removing the splitting.
        raise WorkNotConfiguredToSplitFileSetError.new(work: work, file_set: file_set) unless work&.iiif_print_config&.pdf_splitter_job&.presence

        # clean up any existing spawned child works of this file_set
        IiifPrint::SplitPdfs::DestroyPdfChildWorksService.conditionally_destroy_spawned_children_of(
          file_set: file_set,
          work: work,
          user: user
        )

        location = IiifPrint.pdf_path_for(file_set: file_set)
        IiifPrint.conditionally_submit_split_for(work: work, file_set: file_set, locations: [location], user: user)
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
