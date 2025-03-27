require 'iiif_print/jobs/application_job'

module IiifPrint
  module Jobs
    # @deprecated
    class ChildWorksFromPdfJob < IiifPrint::Jobs::ApplicationJob
      ##
      # Break a pdf into individual pages
      #
      # @param candidate_for_parency [FileSet, Hydra::PCDM::Work]
      # @param pdf_paths: [<Array => String>] paths to pdfs
      # @param user: [User]
      # @param admin_set_id: [<String>]
      # rubocop:disable Metrics/MethodLength
      def perform(id, pdf_paths, user, admin_set_id, *)
        candidate_for_parency = IiifPrint.find_by(id: id)

        ##
        # We know that we have cases where parent_work is nil, this will definitely raise an
        # exception; which is fine because we were going to do it later anyway.
        @parent_work = if candidate_for_parency.work?
                         pdf_file_set = nil
                         candidate_for_parency
                       else
                         # We likely have a file set
                         pdf_file_set = candidate_for_parency
                         IiifPrint.parent_for(candidate_for_parency)
                       end
        @child_admin_set_id = admin_set_id
        child_model = @parent_work.iiif_print_config.pdf_split_child_model

        # When working with remote files, we have put the PDF file into the correct path before submitting this job.
        # However, there seem to be cases where we still don't have the file when we get here, so to be sure, we
        # re-do the same command that was previously used to prepare the file path. If the file is already here, it
        # simply returns the path, but if not it will copy the file there, giving us one more chance to have what we need.
        redownload = pdf_file_set&.is_a?(ActiveFedora::Base)
        pdf_paths = [Hyrax::WorkingDirectory.find_or_retrieve(pdf_file_set.original_file.id, pdf_file_set.id, pdf_paths.first)] if redownload
        # handle each input pdf (when input is a file set, we will only have one).
        pdf_paths.each do |original_pdf_path|
          split_pdf(original_pdf_path, user, child_model, pdf_file_set)
        end

        # Link newly created child works to the parent
        # @param user: [User] user
        # @param parent_id: [<String>] parent work id
        # @param parent_model: [<String>] parent model
        # @param child_model: [<String>] child model
        IiifPrint::Jobs::CreateRelationshipsJob.set(wait: 10.minutes).perform_later(
          user: user,
          parent_id: @parent_work.id.to_s,
          parent_model: @parent_work.class.to_s,
          child_model: child_model.to_s
        )

        # TODO: clean up image_files and pdf_paths
      end
      # rubocop:enable Metrics/MethodLength

      private

      # rubocop:disable Metrics/ParameterLists
      # rubocop:disable Metrics/MethodLength
      def split_pdf(original_pdf_path, user, child_model, pdf_file_set)
        user = User.find_by_user_key(user) unless user.is_a?(User)
        # split the pdf into individual pages; pdf_file_set needed for derivative rodeo splitter
        image_files = @parent_work.iiif_print_config.pdf_splitter_service.call(original_pdf_path, file_set: pdf_file_set)

        # give as much info as possible if we don't have image files to work with.
        if image_files.blank?
          raise "#{@parent_work.class} (ID=#{@parent_work.id} " \
                "to_param:#{@parent_work.to_param}) " \
                "original_pdf_path #{original_pdf_path.inspect} " \
                "pdf_file_set #{pdf_file_set.inspect}"
        end

        @split_from_pdf_id = pdf_file_set&.id.to_s
        prepare_import_data(original_pdf_path, image_files, user)

        # submit the job to create all the child works for one PDF
        # @param [User] user
        # @param [Hash<String => String>] titles
        # @param [Hash<String => String>] resource_types (optional)
        # @param [Array<String>] uploaded_files Hyrax::UploadedFile IDs
        # @param [Hash] attributes attributes to apply to all works, including :model
        # @param [Hyrax::BatchCreateOperation] operation
        operation = Hyrax::BatchCreateOperation.create!(
          user: user,
          operation_type: "PDF Batch Create"
        )
        BatchCreateJob.perform_later(user,
                                     @child_work_titles,
                                     @resource_types,
                                     @uploaded_files,
                                     attributes.merge!(model: child_model.to_s, split_from_pdf_id: @split_from_pdf_id).with_indifferent_access,
                                     operation)
      end
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/ParameterLists

      # rubocop:disable Metrics/MethodLength
      def prepare_import_data(original_pdf_path, image_files, user)
        @uploaded_files = []
        @child_work_titles = {}
        @resource_types = {}
        number_of_pages_in_pdf = image_files.size
        image_files.each_with_index do |image_path, page_number|
          file_id = create_uploaded_file(user, image_path).to_s

          child_title = IiifPrint.config.unique_child_title_generator_function.call(
            original_pdf_path: original_pdf_path,
            image_path: image_path,
            parent_work: @parent_work,
            page_number: page_number,
            page_padding: number_of_digits(nbr: number_of_pages_in_pdf)
          )

          @resource_types[file_id] = resource_types
          @uploaded_files << file_id
          @child_work_titles[file_id] = child_title
          # save child work info to create the member relationships
          PendingRelationship.create!(child_title: child_title,
                                      parent_id: @parent_work.id,
                                      child_order: child_title,
                                      parent_model: @parent_work.class,
                                      child_model: @parent_work.iiif_print_config.pdf_split_child_model,
                                      file_id: @split_from_pdf_id)

          begin
            # Clean up the temporary image path.
            FileUtils.rm_f(image_path) if File.exist?(image_path)
          rescue
            # If we can't delete, let's move on.  Maybe it was already cleaned-up.
          end
        end
      end
      # rubocop:enable Metrics/MethodLength

      def number_of_digits(nbr:)
        nbr.to_s.size
      end

      def create_uploaded_file(user, path)
        # TODO: Could we create a remote path?
        uf = Hyrax::UploadedFile.new
        uf.user_id = user.try(:id) || user
        uf.file = CarrierWave::SanitizedFile.new(path)
        uf.save!
        uf.id
      end

      def attributes
        IiifPrint.config.child_work_attributes_function.call(parent_work: @parent_work, admin_set_id: @child_admin_set_id)
      end

      # TODO: Does this method need to be configurable?
      def resource_types
        @parent_work.try(:resource_type)
      end
    end
  end
end
