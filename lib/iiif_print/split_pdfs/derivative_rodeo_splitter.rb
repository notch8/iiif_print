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
      # @param filename [String] the local path to the PDFDerivativeServicele
      # @param file_set [FileSet] file set containing the PDF file to split
      #
      # @return [Array<String>] paths to images split from each page of PDF file
      #
      # @see IiifPrint::SplitPdfs::BaseSplitter
      def self.call(filename, file_set:)
        new(filename, file_set: file_set).split_files
      end

      ##
      # @param filename [String] path to the original file.  Note that we use {#filename} to
      #        derivate {#input_uri}
      # @param file_set [FileSet] the container for the original file and its derivatives.
      #
      # @param output_tmp_dir [String] where we will be writing things.  In using `Dir.mktmpdir`
      #        we're creating a sudirectory on `Dir.tmpdir`
      def initialize(filename, file_set:, output_tmp_dir: Dir.tmpdir)
        @filename = filename
        @file_set = file_set

        @input_uri = "file://#{filename}"

        # We are writing the images to a local location that CarrierWave can upload.  This is a
        # local file, internal to IiifPrint; it looks like SpaceStone/DerivativeRodeo lingo, but
        # that's just a convenience.
        output_template_path = File.join(output_tmp_dir, '{{ dir_parts[-1..-1] }}', '{{ filename }}')

        @output_location_template = "file://#{output_template_path}"
      end

      attr_reader :filename, :file_set

      ##
      # This is where, in "Fedora" we have the original file.  This is not the original file in the
      # pre-processing location but instead the long-term location of the file in the application
      # that mounts IIIF Print.
      #
      # @return [String]
      attr_reader :input_uri

      ##
      # This is the location where we're going to write the derivatives that will "go into Fedora";
      # it is a local location, one that IIIF Print's mounting application can directly do
      # "File.read"
      #
      # @return [String]
      attr_reader :output_location_template

      ##
      # Where can we find the file that represents the pre-processing template.  In this case, the
      # original PDF file.
      #
      # The logic handles a case where SpaceStone successfully fetched the file to then perform
      # processing.
      #
      # For example, SpaceStone::Serverless will pre-process derivatives and write them into an S3
      # bucket that we then use for IIIF Print.
      #
      # @note The preprocessed_location_template should end in `.pdf`.  The
      #       DerivativeRodeo::BaseGenerator::PdfSplitGenerator#derive_preprocessed_template_from
      #       will coerce the template into one that represents the split pages.
      #
      # @return [String]
      #
      # @see https://github.com/notch8/space_stone-serverless/blob/7f46dd5b218381739cd1c771183f95408a4e0752/awslambda/handler.rb#L58-L63
      # rubocop:disable Metrics/MethodLength
      # rubocop:disable Metrics/AbcSize
      def preprocessed_location_template
        return @preprocessed_location_template if defined?(@preprocessed_location_template)

        derivative_rodeo_candidate = IiifPrint::DerivativeRodeoService.derivative_rodeo_uri(file_set: file_set, filename: filename)

        @preprocessed_location_template =
          if derivative_rodeo_candidate.blank?
            message = "#{self.class}##{__method__} could not establish derivative_rodeo_candidate for " \
                      "#{file_set.class} ID=#{file_set&.id} #to_param=#{file_set&.to_param} with filename #{filename.inspect}.  " \
                      "Move along little buddy."
            Rails.logger.debug(message)
            nil
          elsif rodeo_conformant_uri_exists?(derivative_rodeo_candidate)
            Rails.logger.debug("#{self.class}##{__method__} found existing file at location #{derivative_rodeo_candidate}.  High five partner!")
            derivative_rodeo_candidate
          elsif file_set.import_url
            message = "#{self.class}##{__method__} did not find #{derivative_rodeo_candidate.inspect} to exist.  " \
                      "Moving on to check the #{file_set.class}#import_url of #{file_set.import_url.inspect}"
            Rails.logger.warn(message)
            handle_original_file_not_in_derivative_rodeo
          else
            message = "#{self.class}##{__method__} could not find an existing file at #{derivative_rodeo_candidate} " \
                      "nor a remote_url for #{file_set.class} ID=#{file_set.id} #to_param=#{file_set&.to_param}.  " \
                      "Returning `nil' as we have no possible preprocess.  " \
                      "Maybe the input_uri #{input_uri.inspect} will be adequate."
            Rails.logger.warn(message)
            nil
          end
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/MethodLength

      ##
      # @api private
      #
      # When the file does not exist in the pre-processed location (e.g. "SpaceStone") we need to
      # ensure that we have something locally.  We copy the {FileSet#import_url} to the {#input_uri}
      # location.
      #
      # @return [String] should be the {#input_uri}
      # @raise [DerivativeRodeo::Errors::FileMissingError] when the input_uri does not exist
      def handle_original_file_not_in_derivative_rodeo
        # A quick short-circuit.  Don't attempt to copy.  Likely already covered by the DerivativeRodeo::Generators::CopyGenerator
        return input_uri if rodeo_conformant_uri_exists?(input_uri)

        message = "#{self.class}##{__method__} found #{file_set.class}#import_url of #{file_set.import_url.inspect} to exist.  " \
                  "Perhaps there was a problem in SpaceStone downloading the file?  " \
                  "Regardless, we'll use DerivativeRodeo::Generators::CopyGenerator to ensure #{input_uri.inspect} exists.  " \
                  "However, we'll almost certainly be generating child pages locally."
        Rails.logger.info(message)

        # This ensures that we have a copy of the file_set.import_uri at the input_uri location;
        # we likely have this.
        DerivativeRodeo::Generators::CopyGenerator.new(
          input_uris: [file_set.import_url],
          output_location_template: input_uri
        ).generated_uris.first
      end
      # private :handle_original_file_not_in_derivative_rodeo

      def rodeo_conformant_uri_exists?(uri)
        DerivativeRodeo::StorageLocations::BaseLocation.from_uri(uri).exist?
      end
      private :rodeo_conformant_uri_exists?

      ##
      # @return [Array<Strings>] the paths to each of the images split off from the PDF.
      def split_files
        DerivativeRodeo::Generators::PdfSplitGenerator.new(
          input_uris: [input_uri],
          output_location_template: output_location_template,
          preprocessed_location_template: preprocessed_location_template
        ).generated_files.map(&:file_path)
      rescue => e
        message = "#{self.class}##{__method__} encountered `#{e.class}' “#{e}” for " \
                  "input_uri: #{input_uri.inspect}, " \
                  "output_location_template: #{output_location_template.inspect}, and " \
                  "preprocessed_location_template: #{preprocessed_location_template.inspect}."
        exception = RuntimeError.new(message)
        exception.set_backtrace(e.backtrace)
        raise exception
      end
    end
  end
end
