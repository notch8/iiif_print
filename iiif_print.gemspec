$LOAD_PATH.push File.expand_path('../lib', __FILE__)

# version updated in one place:
require 'iiif_print/version'

# Gem description:
Gem::Specification.new do |spec|
  spec.name        = 'iiif_print'
  spec.version     = IiifPrint::VERSION
  spec.authors     = ['Sean Upton', 'Jacob Reed', 'Brian McBride',
                      'Eben English', 'Kirk Wang', 'LaRita Robinson', 'Jeremy Friesen']
  spec.email       = ['sean.upton@utah.edu', 'jacob.reed@utah.edu',
                      'brian.mcbride@utah.edu', 'eenglish@bpl.org', 'kirk.wang@scientist.com',
                      'larita@scientist.com', 'jeremy.n.friesen@gmail.com']
  spec.homepage    = 'https://github.com/notch8/iiif_print/'
  spec.description = 'Gem/Engine for IIIF Print works in Hyrax-based Samvera Application.'
  spec.summary     = <<-SUMMARY
  IiifPrint is a gem (Rails "engine") for Hyrax-based digital repository applications to support displaying parent/child works in the same viewer (Universal Viewer) and the ability to search OCR from the parent work to the child work(s). IiifPring was originally based off of the samvera-labs Newspaper gem.
SUMMARY
  spec.license = 'Apache-2.0'
  spec.files = `git ls-files`.split($OUTPUT_RECORD_SEPARATOR).select { |f| File.dirname(f) !~ %r{\A"?spec\/?} && f != 'bin/rails' }
  spec.test_files = spec.files.grep(%r{^(test|spec|features)/})
  spec.add_dependency 'blacklight_iiif_search', '>= 1.0', '< 3.0'
  spec.add_dependency 'derivative-rodeo', "~> 0.5"
  spec.add_dependency 'hyrax', '>= 2.5', '< 6'
  spec.add_dependency 'nokogiri', '>=1.13.2'
  spec.add_dependency 'rdf-vocab', '~> 3.0'

  spec.add_development_dependency 'bixby'
  spec.add_development_dependency 'database_cleaner', '~> 1.3'
  spec.add_development_dependency 'engine_cart', '~> 2.2'
  spec.add_development_dependency "factory_bot", '~> 4.4'
  spec.add_development_dependency 'fcrepo_wrapper', '~> 0.5', '>= 0.5.1'
  # TODO: We want to remove dependency on this
  spec.add_development_dependency 'newspaper_works_fixtures', '~> 0.3', '>=0.3.1'
  spec.add_development_dependency 'rails-controller-testing', '~> 1'
  spec.add_development_dependency 'json-canonicalization', '0.3.1'
  spec.add_development_dependency 'rspec-rails'
  spec.add_development_dependency 'rspec-activemodel-mocks'
  spec.add_development_dependency 'shoulda-matchers', '~> 3.1'
  spec.add_development_dependency 'solr_wrapper', '>= 1.1', '< 3.0'
  spec.add_development_dependency 'solargraph'
  spec.add_development_dependency 'yard'
end
