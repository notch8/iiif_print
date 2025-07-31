##
# @see https://github.com/samvera/hyrax/wiki/Hyrax's-Event-Bus-(Hyrax::Publisher)
# @see https://www.rubydoc.info/gems/hyrax/Hyrax/Publisher
# @see https://dry-rb.org/gems/dry-events
module IiifPrint
  class Listener
    ##
    # Responsible for conditionally enqueuing the creation of child works from a PDF.
    #
    # @param event [#[]] a hash like construct with keys :user and :file_set
    # @param service [#conditionally_enqueue]
    #
    # @see Hyrax::WorkUploadsHandler
    def on_file_characterized(event, service: IiifPrint::SplitPdfs::ChildWorkCreationFromPdfService)
      file_set = event[:file_set]
      return false unless file_set
      return false unless file_set.file_set?
      return false unless file_set.original_file&.respond_to?(:pdf?)
      return false unless file_set.original_file&.pdf?

      work = IiifPrint.parent_for(file_set)
      # A short-circuit to avoid fetching the underlying file.
      return false unless work

      user = work.depositor
      # TODO: Verify that this is the correct thing to be sending off for conditional enquing.  That
      # will require a more involved integration test.
      file = file_set.original_file
      service.conditionally_enqueue(file_set: file_set, work: work, file: file, user: user)
    end
  end
end
