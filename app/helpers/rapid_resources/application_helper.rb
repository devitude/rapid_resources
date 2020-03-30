module RapidResources
  module ApplicationHelper
    def rapid_resources_index_component(page)
      content_tag(:div, "Create helper method `rapid_resources_index_component(page)`")
    end

    def rapid_resources_container_class(page)
      'container-fluid'
    end

    def rapid_resources_form_class(item, additional_classes = nil)
      controller_class = controller_path.gsub('_', '-').split('/').join(' ') + '-form'
      [additional_classes, controller_class].compact.join(' ')
    end


    def rapid_resources_form_options(item, page = nil, options = {})
      html_options = options.delete(:html) || {}
      f_options = {
        model: item,
        url: page.form_url(item),
        html: { class: rapid_resources_form_class(item, page.try(:form_css_class)) }.merge!(html_options),
        builder: ::RapidResources::FormBuilder,
        remote: false,
        page: page,
      }.merge!(options)
      page.form_options(f_options)
    end

    def rapid_resources_form_cancel_tag(page, item)
      cancel_path = rapid_resources_form_cancel_path(page, item)
      return nil if cancel_path == :none

      link_to page.t(:'form.action.cancel'), cancel_path, class: 'btn btn-default btn-sm'
    end

    def rapid_resources_form_cancel_path(page, item)
      cp = page.form_cancel_path(item)
      if !params[:return_to].blank? && params[:return_to].starts_with?('/')
        params[:return_to]
      elsif cp.nil?
        url_for(action: :index)
      elsif cp.is_a?(Hash)
        url_for(cp)
      else
        cp
      end
    end
  end
end
