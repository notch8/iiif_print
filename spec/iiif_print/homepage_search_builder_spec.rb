# frozen_string_literal: true

require 'spec_helper'
require 'iiif_print/homepage_search_builder'
require 'support/show_parents_only_examples'

RSpec.describe IiifPrint::HomepageSearchBuilder do
  it_behaves_like 'a search builder that shows parent works only'
end
