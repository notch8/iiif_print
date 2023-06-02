module IiifPrint
  module SplitPdfs
    ##
    # This class wraps the DerivativeRodeo::Generators::PdfSplitGenerator to find preprocessed
    # images, or split a PDF if there are no preprocessed images.
    #
    # We have already attached the original file to the file_set.  We want to convert that original
    # file that's attached to a input_uri (e.g. "file://path/to/original-file" as in what we have
    # written to Fedora as the PDF)
    #
    # @see .call
    class DerivativeRodeoSplitter
      ##
      # @param path [String] the local file location
      # @param file_set [FileSet] file set containing a PDF file to split
      #
      # @return [Array] paths to images split from each page of PDF file
      def self.call(path, file_set:)
        new(path, file_set: file_set).split_files
      end

      def initialize(path, file_set:, output_tmp_dir: Dir.tmpdir)
        @input_uri = "file://#{path}"

        # We are writing the images to a location that CarrierWave can upload.
        #
        # https://github.com/scientist-softserv/iiif_print/blob/b969541de1a0526305b54de37bf7cf100289f088/lib/iiif_print/jobs/child_works_from_pdf_job.rb#L108
        output_template_path = File.join(output_tmp_dir, '{{ dir_parts[-1..-1] }}', '{{ filename }}')

        @output_location_template = "file://#{output_template_path}"
        @preprocessed_location_template = IiifPrint::DerivativeRodeoService.derivative_rodeo_input_uri(file_set: file_set, filename: filename)
      end

      ##
      # This is where, in "Fedora" we have the original file.  This is not the original file in the
      # pre-processing location but instead the long-term location of the file in the application
      # that mounts IIIF Print.
      #
      # @return [String]
      attr_reader :input_uri

      ##
      # This is the location where we're going to write the derivatives that will "go into Fedora".
      #
      # @return [String]
      attr_reader :output_location_template

      ##
      # Where can we find, in the DerivativeRodeo's storage, what has already been done regarding
      # derivative generation.
      #
      # For example, SpaceStone::Serverless will pre-process derivatives and write them into an S3
      # bucket that we then use for IIIF Print.
      #
      # @return [String]
      #
      # @see https://github.com/scientist-softserv/space_stone-serverless/blob/7f46dd5b218381739cd1c771183f95408a4e0752/awslambda/handler.rb#L58-L63
      attr_reader :preprocessed_location_template

      ##
      # @return [Array<Strings>] the paths to each of the images split off from the PDF.
      def split_files
        DerivativeRodeo::Generators::PdfSplitGenerator.new(
          input_uris: [@input_uri],
          output_location_template: output_location_template,
          preprocessed_location_template: preprocessed_location_template
        ).generated_files.map(&:file_path)
      end
    end
  end
end
