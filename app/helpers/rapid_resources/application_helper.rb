module RapidResources
  module ApplicationHelper
    def rapid_resources_index_component(page)
      content_tag(:div, "Create helper method `rapid_resources_index_component(page)`")
    end

    def rapid_resources_form_wrapper_css_class(form)
      (['rapid-form'] + [*form.wrapper_css_class]).select { |v| v.present? }.join(' ')
    end

    def rapid_resources_form_class(item, page_form_css_class, form_css_class)
      [page_form_css_class, form_css_class].compact.uniq.join(' ')
    end


    def rapid_resources_form_options(form, item, page = nil, options = {})
      html_options = options.delete(:html) || {}
      f_options = {
        model: item,
        url: page.form_url(item),
        html: { class: rapid_resources_form_class(item, page.form_css_class, form.css_class) }.merge!(html_options),
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

    def rapid_resources_form_delete_tag(page, item, resource_form)
      if resource_form.show_destroy_btn && item.persisted?
        link_to page.t('form.action.delete'), url_for(action: :destroy, return_to: params[:return_to]), class: 'btn btn-sm btn-danger ml-auto',
          'data-method' => 'DELETE',
          'data-confirm' => resource_form.destroy_confirmation_message,
          'data-confirm-title' => resource_form.destroy_confirmation_title,
          'data-confirm-code' => resource_form.destroy_confirmation_code,
          'data-confirm-action-title' => resource_form.destroy_confirmation_action_title,
          'data-confirm-cancel-title' => resource_form.destroy_confirmation_cancel_title,
          'data-confirm-type' => 'destroy'
      end
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

    def rapid_resources_form_before(page)
    end

    def rapid_resources_form_after(page)
    end

    def render_rapid_resources_view_form(page, resource, resource_form)
      render partial: 'show_form', locals: { page: page, item: resource, resource_form: resource_form }
    end
  end
end
