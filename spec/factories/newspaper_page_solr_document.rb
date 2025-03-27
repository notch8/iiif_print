FactoryBot.define do
  factory :file_set_solr_document, class: SolrDocument do
    initialize_with do
      new(id: 'fs123456',
          has_model_ssim: ['FileSet'])
    end
  end

  factory :newspaper_page_solr_document, class: SolrDocument do
    initialize_with do
      file_set = build(:file_set_solr_document)
      new(id: '123456',
          title_tesim: ['Page 1'],
          has_model_ssim: ['NewspaperPage'],
          issue_id_ssi: 'abc123',
          member_ids_ssim: [file_set.id],
          descendent_member_ids_ssim: [file_set.id],
          thumbnail_path_ss: '/downloads/123456?file=thumbnail')
    end
  end
end
