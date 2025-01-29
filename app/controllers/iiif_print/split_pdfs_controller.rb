module IiifPrint
  # Responsible for coordinating the request to resplit a PDF.
  class SplitPdfsController < ApplicationController
    before_action :authenticate_user!

    def create
      @file_set = IiifPrint.find_by(id: params[:file_set_id])
      authorize_create_split_request!(@file_set)

      IiifPrint::Jobs::RequestSplitPdfJob.perform_later(file_set_id: @file_set.to_param, user: current_user)
      respond_to do |wants|
        wants.html { redirect_to polymorphic_path([main_app, @file_set]), notice: t("iiif_print.file_set.split_submitted", id: @file_set.id) }
        wants.json { render json: { id: @file_set.id, to_param: @file_set.to_param }, status: :ok }
      end
    end

    private

    ##
    # @param file_set [FileSet]
    def authorize_create_split_request!(file_set)
      # NOTE: Duplicates logic of Hyrax: https://github.com/samvera/hyrax/blob/b334e186e77691d7da8ed59ff27f091be1c2a700/app/controllers/hyrax/file_sets_controller.rb#L234-L241
      #
      # Namely if we don't have a file_set we need not proceed.
      raise CanCan::AccessDenied unless file_set

      ##
      # Rely on CanCan's authorize! method.  We could add the :split_pdf action to the ability
      # class.  But we're pigging backing on the idea that you can do this if you can edit the work.
      authorize!(:edit, file_set)
      raise "Expected #{file_set.class} ID=#{file_set.id} #to_param=#{file_set.to_param} to be a PDF.  Instead found mime_type of #{file_set.mime_type}." unless IiifPrint.pdf?(file_set)

      work = IiifPrint.parent_for(file_set)
      raise WorkNotConfiguredToSplitFileSetError.new(file_set: file_set, work: work) unless work&.iiif_print_config&.pdf_splitter_job&.presence

      true
    end
  end
end
