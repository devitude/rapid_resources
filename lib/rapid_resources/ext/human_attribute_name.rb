module RapidResources::Ext::HumanAttributeName
  extend ActiveSupport::Concern

  class_methods do
    if Rails.version != '6.0.3.1'
      raise RuntimeError, 'RapidResources::Ext::HumanAttributeName supports only raisl 6.0.3.1'
    end

    # customize default human_attribute_name
    # Original code in activemodel:lib/active_model/translation.rb
    def human_attribute_name(attribute, options = {})
      options   = { count: 1 }.merge!(options)
      parts     = attribute.to_s.split(".")
      attribute = parts.pop
      namespace = parts.join("/") unless parts.empty?
      attributes_scope = "#{i18n_scope}.attributes"

      if namespace
        defaults = lookup_ancestors.map do |klass|
          :"#{attributes_scope}.#{klass.model_name.i18n_key}/#{namespace}.#{attribute}"
        end
        defaults << :"#{attributes_scope}.#{namespace}.#{attribute}"
      else
        defaults = lookup_ancestors.map do |klass|
          :"#{attributes_scope}.#{klass.model_name.i18n_key}.#{attribute}"
        end
      end

      defaults << :"attributes.#{attribute}"
      defaults << options.delete(:default) if options[:default]
      defaults << attribute.humanize

      ### begin customisation ###
      if options.delete(:form)
        defaults.unshift :"#{attributes_scope}.#{model_name.i18n_key}.form.#{attribute}"
      end
      ### end customisation ###

      options[:default] = defaults
      I18n.translate(defaults.shift, **options)
    end
  end
end