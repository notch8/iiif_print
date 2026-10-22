require 'iiif_print/text_formats_from_alto_service'

module IiifPrint
  class TextExtractionDerivativeService < BaseDerivativeService
    # @param [Hash<Symbol,Symbol>]
    #
    # The key for the hash represents the file extension.  The key's value represents the instance
    # method to call on {IiifPrint::TextExtraction::PageOCR}
    class_attribute :ocr_derivatives, default: { txt: :plain, xml: :alto, json: :word_json }
    class_attribute :alto_derivative_service_class, default: IiifPrint::TextFormatsFromALTOService
    class_attribute :page_ocr_service_class, default: IiifPrint::TextExtraction::PageOCR
    def initialize(file_set)
      super(file_set)
    end

    def create_derivatives(src)
      from_alto = alto_derivative_service_class.new(
        file_set
      )
      return from_alto.create_derivatives(src) unless from_alto.alto_path.nil?
      create_derivatives_from_ocr(src)
    rescue => e
      user = User.find_by_user_key(file_set.depositor)
      ContentDepositErrorEventJob.perform_later(file_set, user, reason: e.message)
    end

    def create_derivatives_from_ocr(filename)
      # TODO: Do we need this source_path instance variable?
      @source_path = filename
      ocr = page_ocr_service_class.new(filename)
      # run all OCR first, so a failed or empty run leaves existing text in place
      contents = ocr_derivatives.transform_values { |method_name| ocr.public_send(method_name) }
      return if contents[:txt].blank?

      IiifPrint.remove_extracted_text_for(file_set: file_set)

      contents.each do |extension, content|
        next if content.blank?

        write(content: content, path: prepare_path(extension.to_s), extension: extension)
      end
    end

    def write(content:, path:, extension:)
      mime_type = mime_type_for(extension)
      File.open(path, 'w') do |outfile|
        outfile.write(content)
        IiifPrint.copy_derivatives_from_data_store(stream: content, directives: { url: path, container: 'extracted_text', mime_type: mime_type })
      end
    end

    def cleanup_derivatives(*)
      ocr_derivatives.keys do |extension|
        super(extension.to_s)
      end
    end
  end
end
