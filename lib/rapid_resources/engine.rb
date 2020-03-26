module RapidResources
  class Engine < ::Rails::Engine
    isolate_namespace RapidResources

    config.autoload_paths << File.expand_path("../../", __FILE__)

    # autoload support
    config.to_prepare do
      require_dependency 'rapid_resources/result'
      require_dependency 'rapid_resources/fixed_collection'
    end
  end
end
