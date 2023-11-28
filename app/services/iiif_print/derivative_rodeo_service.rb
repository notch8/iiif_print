module IiifPrint
  ##
  # This class implements the interface of a Hyrax::DerivativeService.
  #
  # That means three important methods are:
  #
  # - {#valid?}
  # - {#create_derivatives}
  # - {#cleanup_derivatives}
  #
  # And the object initializes with a FileSet.
  #
  # It is a companion to {IiifPrint::PluggableDerivativeService}.
  #
  # @see https://github.com/samvera/hyrax/blob/main/app/services/hyrax/derivative_service.rb Hyrax::DerivativesService
  # rubocop:disable Metrics/ClassLength
  class DerivativeRodeoService
    ##
    # @!group Class Attributes
    #
    # @attr parent_work_identifier_property_name [String] the property we use to identify the unique
    #       identifier of the parent work as it went through the SpaceStone pre-process.
    #
    # TODO: The default of :aark_id is a quick hack for adventist.  By exposing a configuration
    # value, my hope is that this becomes easier to configure.
    class_attribute :parent_work_identifier_property_name, default: 'aark_id'

    ##
    # @attr preprocessed_location_adapter_name [String] The name of a derivative rodeo storage location;
    #       this will must be a registered with the DerivativeRodeo::StorageLocations::BaseLocation.
    class_attribute :preprocessed_location_adapter_name, default: 's3'

    ##
    # @attr named_derivatives_and_generators_by_type [Hash<Symbol, #constantize>] the named
    #       derivative and it's associated generator.  The "name" is important for Hyrax or IIIF
    #       Print implementations.  The generator is one that exists in the DerivativeRodeo.
    #
    # TODO: Could be nice to have a registry for the DerivativeRodeo::Generators; but that's a
    # tomorrow wish.
    class_attribute(:named_derivatives_and_generators_by_type, default: {
                      pdf: {
                        thumbnail: "DerivativeRodeo::Generators::ThumbnailGenerator"
                      },
                      image: {
                        thumbnail: "DerivativeRodeo::Generators::ThumbnailGenerator",
                        json: "DerivativeRodeo::Generators::WordCoordinatesGenerator",
                        xml: "DerivativeRodeo::Generators::AltoGenerator",
                        txt: "DerivativeRodeo::Generators::PlainTextGenerator"
                      }
                    })
    # @!endgroup Class Attributes
    ##

    # @see .named_derivatives_and_generators_by_type
    def named_derivatives_and_generators
      @named_derivatives_and_generators ||=
        if file_set.class.pdf_mime_types.include?(mime_type)
          named_derivatives_and_generators_by_type.fetch(:pdf)
        elsif file_set.class.image_mime_types.include?(mime_type)
          named_derivatives_and_generators_by_type.fetch(:image)
        else
          raise "Unexpected mime_type #{mime_type} for #{file_set.class} ID=#{file_set.id.inspect}"
        end
    end

    ##
    # This method encodes some existing assumptions about the URI based on implementations for
    # Adventist.  Those are reasonable assumptions but time will tell how reasonable.
    #
    # By convention, this method is returning output_location of the SpaceStone::Serverless
    # processing.  We might know the original location that SpaceStone::Serverless processed, but
    # that seems to be a tenuous assumption.
    #
    # In other words, where would SpaceStone, by convention, have written the original file and by
    # convention written that original file's derivatives.
    #
    # TODO: We also need to account for PDF splitting
    #
    # @param file_set [FileSet]
    # @param filename [String]
    # @param extension [String]
    # @param adapter_name [String] Added as a parameter to make testing just a bit easier.  See
    #        {.preprocessed_location_adapter_name}
    #
    # @return [String]
    # rubocop:disable Metrics/MethodLength
    def self.derivative_rodeo_uri(file_set:, filename: nil, extension: nil, adapter_name: preprocessed_location_adapter_name)
      # TODO: This is a hack that knows about the inner workings of Hydra::Works, but for
      # expendiency, I'm using it.  See
      # https://github.com/samvera/hydra-works/blob/c9b9dd0cf11de671920ba0a7161db68ccf9b7f6d/lib/hydra/works/services/add_file_to_file_set.rb#L49-L53
      filename ||= Hydra::Works::DetermineOriginalName.call(file_set.original_file)

      dirname = derivative_rodeo_preprocessed_directory_for(file_set: file_set, filename: filename)

      # The aforementioned filename and the following basename and extension are here to allow for
      # us to take an original file and see if we've pre-processed the derivative file.  In the
      # pre-processed derivative case, that would mean we have a different extension than the
      # original.
      extension ||= File.extname(filename)
      extension = ".#{extension}" unless extension.start_with?(".")

      # We want to strip off the extension of the given filename.
      basename = File.basename(filename, File.extname(filename))

      # TODO: What kinds of exceptions might we raise if the location is not configured?  Do we need
      # to "validate" it in another step.
      location = DerivativeRodeo::StorageLocations::BaseLocation.load_location(adapter_name)

      File.join(location.adapter_prefix, dirname, "#{basename}#{extension}")
    end
    # rubocop:enable Metrics/MethodLength

    ##
    # @api public
    #
    # Figure out the ancestor type and ancestor
    def self.get_ancestor(filename: nil, file_set:)
      # In the case of a page split from a PDF, we need to know the grandparent's identifier to
      # find the file(s) in the DerivativeRodeo.
      if DerivativeRodeo::Generators::PdfSplitGenerator.filename_for_a_derived_page_from_a_pdf?(filename: filename)
        [IiifPrint.grandparent_for(file_set), :grandparent]
      else
        [IiifPrint.parent_for(file_set), :parent]
      end
    end

    ##
    # @api public
    #
    # @note You may find yourself wanting to override this method.  Please do if you find a better
    #       way to do this.
    #
    # By convention, we're putting the files of a work in a "directory" that is based on some
    # identifying value (e.g. an object's AARK ID) of the work.
    #
    # Because we split PDFs (see {IiifPrint::SplitPdfs::DerivativeRodeoSplitter} we need to consider
    # that we may be working on the PDF (and that FileSet is directly associated with the work) or
    # we are working on one of the pages ripped from the PDF (and the FileSet's work is a to be
    # related child work of the original work).
    #
    # @param file_set [FileSet]
    # @param filename [String]
    # @return [String] the dirname (without any "/" we hope)
    # rubocop:disable Metrics/AbcSize
    # rubocop:disable Metrics/MethodLength
    def self.derivative_rodeo_preprocessed_directory_for(file_set:, filename:)
      # SpaceStone does not know about lineage; it makes assumptions based on the URL of the work.
      # If we have an import_url, let's follow the same assumption that SpaceStone would make.
      #
      # NOTE: We're assuming that a page ripped from a PDF will not have an import_url.  This may
      # not be the case.
      return file_set.import_url.split("/")[-2] if file_set&.import_url&.split("/")[-2]&.presence

      ancestor, ancestor_type = get_ancestor(filename: filename, file_set: file_set)

      # Why might we not have an ancestor?  In the case of grandparent_for, we may not yet have run
      # the create relationships job.  We could sneak a peak in the table to maybe glean some insight.
      # However, read further the `else` clause to see the novel approach.
      #
      # Why might the ancestor not respond (nor have) a configured
      # parent_work_identifier_property_name?  Because data is sloppy.  And we're trying to "guess"
      # how this data was written in SpaceStone; a non-trivial task.
      #
      # TODO: Perhaps we could use the original remote_url to sniff that out the space stone
      # directory?
      #
      # rubocop:disable Style/GuardClause
      if ancestor && ancestor.try(parent_work_identifier_property_name).presence
        message = "#{self.class}.#{__method__} #{file_set.class} ID=#{file_set.id} and filename: #{filename.inspect}" \
                  "has #{ancestor_type} of #{ancestor.class} ID=#{ancestor.id}"
        Rails.logger.info(message)
        ancestor.public_send(parent_work_identifier_property_name)
      else
        # HACK: This makes critical assumptions about how we're creating the title for the file_set;
        # but we don't have much to fall-back on.  Consider making this a configurable function.  Or
        # perhaps this entire method should be more configurable.
        # TODO: Revisit this implementation.
        Array.wrap(file_set.title).first.split(".").first ||
          raise("#{file_set.class} ID=#{file_set.id} has title #{file_set.title.first} from which we cannot infer information.")
      end
      # rubocop:enable Style/GuardClause
    end
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/AbcSize

    def initialize(file_set)
      @file_set = file_set
    end

    attr_reader :file_set
    delegate :uri, :mime_type, to: :file_set

    ##
    # @return
    # @see https://github.com/samvera/hyrax/blob/426575a9065a5dd3b30f458f5589a0a705ad7be2/app/services/hyrax/file_set_derivatives_service.rb#L18-L20 Hyrax::FileSetDerivativesService#valid?
    def valid?
      if in_the_rodeo?
        Rails.logger.info("Using the DerivativeRodeo for FileSet ID=#{file_set.id} with mime_type of #{mime_type}")
        true
      else
        Rails.logger.info("Skipping the DerivativeRodeo for FileSet ID=#{file_set.id} with mime_type of #{mime_type}")
        false
      end
    end

    ##
    # @api public
    #
    # The file_set.class.*_mime_types are carried over from Hyrax.
    #
    # @note We write derivatives to the {#absolute_derivative_path_for} and should likewise clean
    #       them up when deleted.
    # @see #cleanup_derivatives
    def create_derivatives(filename)
      # TODO: Do we need to handle "impending derivatives?"  as per {IiifPrint::PluggableDerivativeService}?
      named_derivatives_and_generators.flat_map do |named_derivative, generator_name|
        lasso_up_some_derivatives(
          named_derivative: named_derivative,
          generator_name: generator_name,
          filename: filename
        )
      end
    end

    # We need to clean up the derivatives that we created.
    #
    # @see #create_derivatives
    #
    # @note Due to the configurability and plasticity of the named derivatives, it is possible that
    #       when we created the derivatives, we had a different configuration (e.g. were we to
    #       create derivatives again, we might get a set of different files).  So we must ask
    #       ourselves, is it important to clean up all derivatives (even ones that may not be in
    #       scope for this service) or to clean up only those presently in scope?  I am favoring
    #       removing all of them.  In part because of the nature of the valid derivative service.
    def cleanup_derivatives
      ## Were we to only delete the derivatives that this service presently creates, this would be
      ## that code:
      #
      # named_derivatives_and_generators.keys.each do |named_derivative|
      #   path = absolute_derivative_path_for(named_derivative)
      #   FileUtils.rm_f(path) if File.exist?(path)
      # end

      ## Instead, let's clean it all up.
      Hyrax::DerivativePath.derivatives_for_reference(file_set).each do |path|
        FileUtils.rm_f(path) if File.exist?(path)
      end
    end

    private

    def absolute_derivative_path_for(named_derivative:)
      Hyrax::DerivativePath.derivative_path_for_reference(file_set, named_derivative.to_s)
    end

    # rubocop:disable Metrics/MethodLength
    def lasso_up_some_derivatives(filename:, named_derivative:, generator_name:)
      # TODO: Can we use the filename instead of the antics of the original_file on the file_set?
      # We have the filename in create_derivatives.

      # This is the location that Hyrax expects us to put files that will be added to Fedora.
      output_location_template = "file://#{absolute_derivative_path_for(named_derivative: named_derivative)}"

      # The generator knows the output extensions.
      generator = generator_name.constantize

      # This is the location where we hope the derivative rodeo will have generated the derived
      # file (e.g. a PDF page's txt file or an image's thumbnail.
      preprocessed_location_template = self.class.derivative_rodeo_uri(file_set: file_set, filename: filename, extension: generator.output_extension)

      begin
        generator.new(
          input_uris: [input_uri],
          preprocessed_location_template: preprocessed_location_template,
          output_location_template: output_location_template
        ).generated_files.first.file_path
      rescue => e
        message = "#{generator}#generated_files encountered `#{e.class}' “#{e}” for " \
                  "input_uri: #{input_uri.inspect}, " \
                  "output_location_template: #{output_location_template.inspect}, and " \
                  "preprocessed_location_template: #{preprocessed_location_template.inspect}."
        exception = RuntimeError.new(message)
        exception.set_backtrace(e.backtrace)
        # Why this additional logging?  Because you may splice in a different logger for the
        # Rodeo, and having this information might be helpful as you try to debug a very woolly
        # operation.
        DerivativeRodeo.logger.error(message)
        raise exception
      end
    end
    # rubocop:enable Metrics/MethodLength

    def supported_mime_types
      # If we've configured the rodeo
      named_derivatives_and_generators_by_type.keys.flat_map { |type| file_set.class.public_send("#{type}_mime_types") }
    end

    # Where can we find the "original" file that we want to operate on?
    #
    # @return [String]
    def input_uri
      return @input_uri if defined?(@input_uri)

      # TODO: I've built up logic to use the derivative_rodeo_uri, however what if we don't need to
      # look at that location?  If not there, then we need to look to the file associated with the
      # file set.
      # QUESTION: Should we skip using the derivative rodeo uri as a candidate for the input_uri?
      input_uri = self.class.derivative_rodeo_uri(file_set: file_set)
      location = DerivativeRodeo::StorageLocations::BaseLocation.from_uri(input_uri)
      @input_uri = if location.exist?
                     input_uri
                   elsif file_set.import_url.present?
                     file_set.import_url
                   else
                     # TODO: This is the fedora URL representing the file we uploaded; is that adequate?  Will we
                     # have access to this file?
                     file_set.original_file.uri.to_s
                   end
    end

    def in_the_rodeo?
      # We can assume that we are not going to have pre-processed an unsupported mime type.  We
      # could check if the original file is in the rodeo, but the way it's designed thee rodeo is
      # capable of generating all of the enumerated derivatives (see
      # .named_derivatives_and_generators_by_type) for the supported mime type.
      supported_mime_types.include?(mime_type)
    end
  end
  # rubocop:enable Metrics/ClassLength
end
