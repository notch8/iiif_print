IiifPrint
===================================================
Docs:
[![Apache 2.0 License](http://img.shields.io/badge/APACHE2-license-blue.svg)](./LICENSE)
[![Contribution Guidelines](http://img.shields.io/badge/CONTRIBUTING-Guidelines-blue.svg)](./CONTRIBUTING.md)

Jump in the Samvera Slack: <a href="http://slack.samvera.org/"><img src="https://status.slack.com/fonts/icons/icon_slack_hash_colored.svg" width="15" /></a>

<!-- TOC -->

- [Overview](#overview)
  - [Documentation](#documentation)
  - [Requirements](#requirements)
  - [Dependencies](#dependencies)
- [Installation](#installation)
  - [Changes made by the installer:](#changes-made-by-the-installer)
  - [Configuration to enable IiifPrint features](#configuration-to-enable-iiifprint-features)
    - [Model level configurations](#model-level-configurations)
    - [Application level configurations](#application-level-configurations)
- [Ingesting Content](#ingesting-content)
- [Developing, Testing, and Contributing](#developing-testing-and-contributing)
  - [Contributing](#contributing)
- [Acknowledgements](#acknowledgements)

<!-- /TOC -->

# Overview
IiifPrint is a gem (Rails "engine") for [Hyrax](https://hyrax.samvera.org/)-based digital repository applications to support displaying parent/child works in the same viewer (Universal Viewer) and the ability to search OCR from the parent work to the child work(s).

IiifPrint is not a stand-alone application. It is designed to be integrated into a new or existing Hyku (v4.0-v5.0) application.  Future development will include integrating it into a Hyrax-based application without Hyku and support for [IIIF Presentation Manifest version 3](https://iiif.io/api/presentation/3.0/) along with [AllinsonFlex](https://github.com/samvera-labs/allinson_flex) metadata profiles.

IiifPrint supports:
* OCR and ALTO creation
* full-text search
* OCR keyword match highlighting
* viewer with page navigation and deep zooming
* splitting of PDFs to LZW compressed TIFFs for viewing
* adding metadata fields to the manifest with faceted search links and external links
* excluding specified work types to be found in the catalog search
* external IIIF image urls that work with services such as serverless-iiif or cantaloup

A complete list of features can be found [here](https://github.com/notch8/iiif_print/wiki/Features-List).

## Documentation
A set of helpful documents to help you learn more and deploy IiifPrint can be found on the [Project Wiki](https://github.com/notch8/iiif_print/wiki).

IiifPrint was developed against [Hyku](https://github.com/samvera/hyku) v4.0-v5.0. If your application uses [Bulkrax](https://github.com/samvera-labs/bulkrax), please ensure that its version is 5.0.1 or greater.

## Requirements

  * [Ruby](https://rubyonrails.org/) >=2.4
  * [Rails](https://rubyonrails.org/) ~>5.0
  * [Bundler](http://bundler.io/)
  * [Hyrax](https://github.com/samvera/hyrax) v2.5-v3.5.0
    - ..._and various [Samvera dependencies](https://github.com/samvera/hyrax#https://github.com/samvera/hyrax#how-to-run-the-code) that entails_.
  * A Hyrax-based Rails application

## Dependencies

  * [FITS](https://projects.iq.harvard.edu/fits/home)
  * [Tesseract-ocr](https://github.com/tesseract-ocr/)
  * [LibreOffice](https://www.libreoffice.org/)
  * [ghostscript](https://www.ghostscript.com/)
  * [poppler-utils](https://poppler.freedesktop.org/)
  * [ImageMagick](https://github.com/ImageMagick/ImageMagick6)
    - _ImageMagick policy XML may need to be more permissive in both resources and source media types allowed.  See template [policy.xml](config/vendor/imagemagick-6-policy.xml)._
  * [libcurl3](https://packages.ubuntu.com/search?keywords=libcurl3)
  * [libgbm1](https://packages.debian.org/sid/libgbm1)

# Installation
IiifPrint easily integrates with your Hyrax 2.x applications.

* Add `gem 'iiif_print'` to your Gemfile.
* Run `bundle install`
* Run `rails generate iiif_print:install`
* Set config options as indicated below...


## Changes made by the installer:
* In `app/assets/javascripts/application.js`, it adds `//= require iiif_print`
* Adds `app/assets/stylesheets/iiif_print.scss`
* In `app/controllers/catalog_controller.rb`, it adds `include BlacklightIiifSearch::Controller`
* In `app/controllers/catalog_controller.rb`, it adds `add_index_field` and `iiif_search` config in the `configure_blacklight` block
* Adds `app/models/iiif_search_build.rb`
* In `config/routes.rb`, it adds `concern :iiif_search, BlacklightIiifSearch::Routes.new`
* In `config/routes.rb`, it adds `concerns :iiif_search` in the `resources :solr_documents` block
* Adds `config/initializers/iiif_print.rb`
* Adds three migrations, `CreateIiifPrintDerivativeAttachments`, `CreateIiifPrintIngestFileRelations`, and `CreateIiifPrintPendingRelationships`

(It may be helpful to run `git diff` after installation to see all the changes made by the installer.)

## Catalog to Universal Viewer search:
To enable a feature where the UV automatically picks up the search from the catalog, do the following:
* Add `highlight: urlDataProvider.get('q'),` into your uv.html in the `<script>` section.
```js
uv = createUV('#uv', {
    root: '.',
    iiifResourceUri: urlDataProvider.get('manifest'),
    configUri: 'uv-config.json',
    collectionIndex: Number(urlDataProvider.get('c', 0)),
    manifestIndex: Number(urlDataProvider.get('m', 0)),
    sequenceIndex: Number(urlDataProvider.get('s', 0)),
    canvasIndex: Number(urlDataProvider.get('cv', 0)),
    rangeId: urlDataProvider.get('rid', 0),
    rotation: Number(urlDataProvider.get('r', 0)),
    xywh: urlDataProvider.get('xywh', ''),
    embedded: true,
    highlight: urlDataProvider.get('q'), // <-- here's a good spot
    locales: formattedLocales
}, urlDataProvider);
```

* Make sure to remove your application's `app/helpers/hyrax/iiif_helper.rb` and `app/views/hyrax/base/iiif_viewers/_universal_viewer.html.erb` (if exists)

## Configuration to enable IiifPrint features
**NOTE: WorkTypes and models are used synonymously here.**

### Persistence Layer Adapter

We created IiifPrint with an assumption of ActiveFedora.  However, as Hyrax now supports Valkyrie, we need an alternate approach.  We introduced `IiifPrint::Configuration#persistence_layer` as a configuration option.  By default it will use `ActiveFedora` methods; but you can switch adapters to use Valkyrie instead.  (See `IiifPrint::PersistentLayer` for more details).

### IIIF URL configuration

If you set EXTERNAL_IIIF_URL in your environment, then IiifPrint will use that URL as the root for your IIIF URLs. It will also switch from using the file set ID to using the SHA1 of the file as the identifier. This enables using serverless_iiif or Cantaloupe (refered to as the service) by pointing the service to the same S3 bucket that FCREPO writes the uploaded files to. By setting it up that way you do not need the service to connect to FCREPO or Hyrax at all, both natively support connecting to an S3 bucket to get their data.

### Model level configurations

In `app/models/{work_type}.rb` add `include IiifPrint.model_configuration` to any work types which require IiifPrint processing features (such as PDF splitting or OCR derivatives). See [lib/iiif_print.rb](./lib/iiif_print.rb) for details on configuration options.

```rb
# Example model Book which splits PDFs into child works of
# model Page, and runs only one derivative service (TIFFs)

class Book < ActiveFedora::Base
  include IiifPrint.model_configuration(
    pdf_split_child_model: Page,
    derivative_service_plugins: [
      IiifPrint::TIFFDerivativeService
    ]
  )
end
```

### Application level configurations

In `config/initializers/iiif_print.rb` specify application level configuration options.

```rb
IiifPrint.config do |config|
  # Add models to be excluded from search so the user would not see them in the search results.
  # By default, use the human readable versions like:
  config.excluded_model_name_solr_field_values = ['Generic Work', 'Image']

  # Add configurable solr field key for searching, default key is: 'human_readable_type_sim' if
  # another key is used, make sure to adjust the config.excluded_model_name_solr_field_values to match
  config.excluded_model_name_solr_field_key = 'some_solr_field_key'
end
```

TO ENABLE OCR Search (from the UV and catalog search)
### catalog_controller.rb
* In the CatalogController, find the add_search_field config block for 'all_fields'. Add `advanced_parse: false` as seen in the following example:
```rb
    config.add_search_field('all_fields', label: 'All Fields', include_in_advanced_search: false, advanced_parse: false) do |field|
      all_names = config.show_fields.values.map(&:field).join(" ")
      title_name = 'title_tesim'
      field.solr_parameters = {
        qf: "#{all_names} file_format_tesim all_text_timv",
        pf: title_name.to_s
      }
    end
```
* Set `config.search_builder_class = IiifPrint::CatalogSearchBuilder` to remove works from the catalog search results if `is_child_bsi: true`
* Ensure that all text search is configured in default_solr_params config block:
```rb
    config.default_solr_params = {
      qt: "search",
      rows: 10,
      qf: "title_tesim description_tesim creator_tesim keyword_tesim all_text_timv"
    }
```

To remove child works from recent works on homepage
### homepage_controller.rb
* In the HomepageController, change the search_builder_class to remove works from recent_documents if `is_child_bsi: true`
```rb
    require "iiif_print/homepage_search_builder"

    def search_builder_class
      IiifPrint::HomepageSearchBuilder
    end
```

### Skipping Certain File Suffixes for PDF Splitting

By default when a work is configured for splitting PDFs, we will split all PDFs.  However, in some cases you don't want to split based on the file name's suffix.  In that case, configure code as follows:

```ruby
IiifPrint.config do |config|
  config.skip_splitting_pdf_files_that_end_with_these_texts = ['.reader.pdf']
end
```

### Derivative Rodeo Configuration

The Derivative Rodeo is used in two ways:

- Configuring the `Hyrax::DerivativeService` by adding `IiifPrint::DerivativeRodeoService`
- Enable Derivative Rodeo PDF Splitting service by `IiifPrint.model_configuration`

#### Configuring Hyrax::Derivative

In the application initializer:

```ruby
      Hyrax::DerivativeService.services = [
        IiifPrint::DerivativeRodeoService,
        Hyrax::FileSetDerivativesService]
```

#### Enabling Derivative Rodeo PDF Splitting

The [IiifPrint.model\_configuration  method](./lib/iiif_print.rb) allows for specifying the `pdf\_splitter\_service` as below:

```ruby
class Book < ActiveFedora::Base
  include IiifPrint.model_configuration(
            pdf_splitter_service: IiifPrint::SplitPdfs::DerivativeRodeoSplitter
          )
end
```

#### Pre-Process Location

The [DerivativeRodeo](https://github.com/notch8/derivative_rodeo) allows for specifying a location where you've done pre-processing (e.g. you ran splitting and derivative generation in AWS's Lambda).

By default the preprocess location is S3, as that is where SoftServ has been running pre-processing.  However that default may not be adequate for local development.

#### Conditional Derivative Generation

The [IiifPrint::DerivativeRodeoService][./app/services/iiif_print/derivative_rodeo_service.rb] provides a means of specifying the derivatives to generate via two configuration points:

- `IiifPrint::DerivativeRodeoService.named_derivatives_and_generators_by_type`
- `IiifPrint::DerivativeRodeoService.named_derivatives_and_generators_filter`

In the case of `named_derivatives_and_generators_by_type`, we're saying all mime categories will generate these derivatives.

In the case of `named_derivatives_and_generators_filter`, we're providing a point where we can specify for each file_set and filename the specific derivatives to accept/reject/append to the named derivative generation.

See their examples for further configuration guidance.

# Ingesting Content

IiifPrint supports a range of different ingest workflows:
* single-item ingest via the UI
* batch ingest of works from local files or remote files via Bulkrax

The ingest process is configurable at the model level, granting the option to:
* split a PDF into TIFFs and create child works
* create a full complement of derivatives, including TIFF, JP2, PDF, OCR text, and word-coordinate JSON

# Developing, Testing, and Contributing

We develop the IIIF Print gem using Docker and Docker Compose.  You'll want to clone this repository and run the following commands:

```shell
$ docker compose build
$ docker compose up
$ docker compose exec web bash
```

You'll now be inside the web container:

```shell
$ bundle exec rake
```

The above will build the test application (if it doesn't already exist).  During the rebuild you might get a notice on a conflict for files.  It will ask you to override.  We recommend that you select the "accept all" option (e.g. Typing <kbd>a</kbd>).

To rebuild the test application, delete the `.internal_test_app` directory.

## Contributing

If you're working on a PR for this project, create a feature branch off of `main`.

This repository follows the [Samvera Community Code of Conduct](https://samvera.atlassian.net/wiki/spaces/samvera/pages/405212316/Code+of+Conduct) and [language recommendations](https://github.com/samvera/maintenance/blob/master/templates/CONTRIBUTING.md#language).  Please ***do not*** create a branch called `master` for this repository or as part of your pull request; the branch will either need to be removed or renamed before it can be considered for inclusion in the code base and history of this repository.

We encourage anyone who is interested in newspapers and Samvera to contribute to this project. [How can I contribute?](https://github.com/samvera/hyrax/blob/master/.github/CONTRIBUTING.md)

# Acknowledgements

IIIF Print is a gem that was forked off [Newspaper Works](https://github.com/samvera-labs/newspaper_works), a powerful and versatile library for working with digitized newspapers. We would like to thank the team and maintainers of Newspaper Works for creating such a useful and well-designed gem. Our work on IIIF Print would not have been possible without their hard work and dedication.

In particular, we would like to express our gratitude to [brianmcbride](https://github.com/brianmcbride), [seanupton](https://github.com/seanupton), [ebenenglish](https://github.com/ebenenglish), and [JacobR](https://github.com/JacobR) for their pioneering efforts on Newspaper Works. Their foundation and expertise were invaluable in the development of this gem.

Thank you to the entire Newspaper Works team for creating and maintaining such a valuable resource for the Samvera community.
