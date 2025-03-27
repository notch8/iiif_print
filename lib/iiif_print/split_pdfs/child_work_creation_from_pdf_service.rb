# frozen_string_literal: true

module IiifPrint
  module SplitPdfs
    ##
    # Encapsulates methods used for pdf splitting into child works.
    #
    # The primary point of entry is {.conditionally_enqueue}.
    class ChildWorkCreationFromPdfService
      ##
      # Responsible for conditionally enqueueing the PDF splitting job.  The conditions attempt to
      # sniff out whether the given file was a PDF.
      #
      # @param file_set [FileSet] What is the containing file set for the provided file.
      # @param file [#path, #id]
      # @param user [User] Who did the upload?
      # @param import_url [NilClass, String] Provided when we're dealing with a file provided via a
      #        URL.
      # @param work [Hydra::PCDM::Work] An optional parameter that saves us a bit of time in not
      #        needing to query for the parent of the given :file_set (see {.parent_for})
      #
      # @return [Symbol] when we don't enqueue the job
      # @return [TrueClass] when we actually enqueue the job underlying job.
      # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      def self.conditionally_enqueue(file_set:, file:, user:, import_url: nil, work: nil)
        work ||= IiifPrint.parent_for(file_set)

        return :no_split_for_parent unless iiif_print_split?(work: work)
        return :no_pdfs_to_split_for_import_url if import_url && !pdfs?(paths: [import_url])

        file_locations = if import_url
                           # TODO: Fix this logic, currently unsupported in Bulkrax
                           [Hyrax::WorkingDirectory.find_or_retrieve(file.id, file_set.id)]
                         else
                           pdf_paths(file: file)
                         end
        return :no_pdfs_to_split if file_locations.empty?

        file_set_id = file_set.id.try(:id) || file_set.id
        work_admin_set_id = work.admin_set_id.try(:id) || work.admin_set_id
        job = work.try(:iiif_print_config)&.pdf_splitter_job&.perform_later(
          file_set_id,
          file_locations,
          user,
          work_admin_set_id,
          0 # A no longer used parameter; but we need to preserve the method signature (for now)
        )
        job ? :enqueued : :pdf_job_failed_enqueue
      end
      # rubocop:enable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

      ##
      # @api private
      #
      # Are there any PDF files?
      # @param [Array > String] paths to PDFs
      # @return [Boolean]
      def self.pdfs?(paths:)
        pdf_paths = pdfs_only_for(paths)
        return false unless pdf_paths.count.positive?
        true
      end

      ##
      # @api private
      # Load an array of paths to pdf files
      # @param [Array > Hyrax::Upload file ids]
      # @return [Array > String] file paths to temp directory
      def self.pdf_paths(file:)
        return [] unless file

        if file.class < Valkyrie::Resource
          # assuming that if one PDF is uploaded to a Valkyrie resource then all of them should be
          return [] unless file.pdf?
          [file.file.disk_path.to_s]
        else
          upload_ids = filter_file_ids(file.id.to_s)
          return [] if upload_ids.empty?

          uploads = Hyrax::UploadedFile.find(upload_ids)
          paths = uploads.map(&method(:upload_path))
          pdfs_only_for(paths)
        end
      end

      ##
      # @api private
      #
      # Is child work splitting defined for model?
      # @param [GenericWork, etc] A valid type of hyrax work
      # @return [Boolean]
      def self.iiif_print_split?(work:)
        config = work.try(:iiif_print_config)
        return false unless config
        return false if config.pdf_splitter_service.try(:never_split_pdfs?)
        # defined only if work has include IiifPrint.model_configuration with pdf_split_child_model
        return true if config&.pdf_split_child_model
        false
      end

      ##
      # @api private
      def self.filter_file_ids(input)
        Array.wrap(input).select(&:present?)
      end

      ##
      # @api private
      #
      # Given Hyrax::Upload object, return path to file on local filesystem
      def self.upload_path(upload)
        # so many layers to this onion:
        # TODO: Write a recursive function to keep calling file until
        # the file doesn't respond to file then return that file.
        upload.file.file.file
      end

      ##
      # @api private
      #
      # TODO: Consider other methods to identify a PDF file.
      #       This sub-selection may need to be moved to use mimetype if there
      #       is a need to support paths not ending in .pdf (i.e. remote_urls)
      def self.pdfs_only_for(paths)
        paths.select { |path| IiifPrint.split_for_path_suffix?(path) }
      end
    end
  end
end
