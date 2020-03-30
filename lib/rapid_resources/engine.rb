module RapidResources
  class Engine < ::Rails::Engine
    isolate_namespace RapidResources

    config.autoload_paths << File.expand_path("../../", __FILE__)

    # autoload support
    config.to_prepare do
      require_dependency 'rapid_resources/controller'
      require_dependency 'rapid_resources/result'
      require_dependency 'rapid_resources/fixed_collection'
      require_dependency 'rapid_resources/collection_field'
      require_dependency 'rapid_resources/grid_filter'
      require_dependency 'rapid_resources/grid_header_action'
      require_dependency 'rapid_resources/page'
      require_dependency 'rapid_resources/page_helpers/pundit_helpers'
      require_dependency 'rapid_resources/form'
      require_dependency 'rapid_resources/form_field_row'
      require_dependency 'rapid_resources/form_field'
      require_dependency 'rapid_resources/active_record_ext'
      require_dependency 'rapid_resources/form_builder'
    end
  end
end
