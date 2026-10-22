module IiifPrint
  # Plugin to make text format derviatives (JSON, plain-text) from ALTO,
  #   either existing derivative, or an impending attachment.
  #   NOTE: to keep this from conflicting with TextExtractionDerivativeService,
  #         this class should be invoked by it, not PluggableDerivativeService.
  class TextFormatsFromALTOService < BaseDerivativeService
    self.target_extension = 'txt'.freeze

    def save_derivative(destination, data)
      mime_type = mime_type_for(destination)
      # Load/prepare base of "pairtree" dir structure for extension, fileset
      prepare_path(destination)
      #
      save_path = derivative_path_factory.derivative_path_for_reference(
        @file_set,
        destination
      )
      # Write data as UTF-8 encoded text
      File.open(save_path, "w:UTF-8") do |f|
        f.write(data)
        IiifPrint.copy_derivatives_from_data_store(stream: data, directives: { url: save_path, container: 'extracted_text', mime_type: mime_type })
      end
    end

    def nonempty_file?(path)
      return false if path.nil?
      return false unless File.exist?(path)
      !File.size(path).zero?
    end

    def alto_with_words?(path)
      nonempty_file?(path) && IiifPrint::TextExtraction::AltoReader.new(path).text.present?
    end

    # if there was no derivative yet, there might be one in-transit from
    #   an ingest, so check for that, and use its source if applicable:
    def incoming_alto_path
      path = IiifPrint::DerivativeAttachment.where(
        fileset_id: @file_set.id,
        destination_name: 'xml'
      ).pluck(:path).uniq.first
      path if alto_with_words?(path)
    end

    def alto_path
      # check first for existing derivative data with words; an ALTO without
      # words (e.g. from a failed OCR run) should not prevent OCR:
      path = derivative_path_factory.derivative_path_for_reference(
        @file_set,
        'xml'
      )
      return path if alto_with_words?(path)
      incoming_alto_path
    end

    def alto
      path = alto_path
      File.read(path, encoding: 'UTF-8') unless path.nil?
    end

    def create_derivatives(_filename)
      # as this plugin makes derivatives of derivative, _filename is ignored
      source_file = alto
      return if source_file.nil?
      # Image width from characterized primary file helps ensure proper scaling:
      file = @file_set.original_file
      width = file.nil? ? nil : file.width[0].to_i
      height = file.nil? ? nil : file.height[0].to_i
      # ALTOReader is responsible for transcoding, this class just saves result
      reader = IiifPrint::TextExtraction::AltoReader.new(
        source_file,
        width,
        height
      )
      IiifPrint.remove_extracted_text_for(file_set: @file_set)
      save_derivative('xml', source_file)
      save_derivative('json', reader.json)
      save_derivative('txt', reader.text)
    end

    def cleanup_derivatives(*args)
      # do nothing here; IiifPrint::TextExtractionDerivativeService
      # has this job instead for cleaning ALTO, JSON, TXT.
    end
  end
end
