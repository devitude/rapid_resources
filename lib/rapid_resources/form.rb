module RapidResources
  class Form

    # attr_reader :fields
    attr_reader :tabs
    attr_reader :resource
    attr_reader :show_destroy_btn
    attr_reader :btn_wrap_col
    attr_reader :destroy_confirmation_code
    attr_reader :destroy_confirmation_message
    attr_reader :destroy_confirmation_title
    attr_reader :destroy_confirmation_action_title
    attr_reader :destroy_confirmation_cancel_title
    attr_reader :message
    attr_reader :css_class, :wrapper_css_class

    def initialize(show_destroy_btn: false, btn_wrap_col: nil, destroy_confirmation: nil, message: nil, css_class: nil, wrapper_css_class: nil, &block)
      @__cur_fields = nil
      @__cur_tab = nil
      @tabs = []
      get_current_tab # ensure we have one tab
      instance_eval &block if block_given?
      @field_stack = nil

      @btn_wrap_col = btn_wrap_col

      @show_destroy_btn = show_destroy_btn

      destroy_confirmation = {} unless destroy_confirmation.is_a?(Hash)
      @destroy_confirmation_code = destroy_confirmation[:code]
      @destroy_confirmation_message = destroy_confirmation[:message]
      @destroy_confirmation_message = 'Vai dzēst ierakstu?' if @destroy_confirmation_message.blank?

      @destroy_confirmation_title = destroy_confirmation[:title]
      @destroy_confirmation_title = 'Dzēšanas apstiprinājums' if @destroy_confirmation_title.blank?

      @destroy_confirmation_action_title = destroy_confirmation[:action_title]
      @destroy_confirmation_action_title = 'Dzēst' if destroy_confirmation_action_title.blank?

      @destroy_confirmation_cancel_title = destroy_confirmation[:cancel_title]
      @destroy_confirmation_cancel_title = 'Atcelt' if destroy_confirmation_cancel_title.blank?

      @message = message
      @css_class = css_class
      @wrapper_css_class = wrapper_css_class
    end

    def has_form_fields?
      @message.blank?
    end

    def message_title
      return nil if @message.blank?

      if @message.is_a?(String)
        @message
      else
        @message[:title]
      end
    end

    def field(*args)
      get_current_tab
      args = *args
      the_field = (args.count == 1 ? args[0] : args)
      if @__cur_fields
        @__cur_fields << the_field
      else
        @__cur_tab[:fields] << the_field
      end
    end

    def row(title: nil, html_options: nil, options: nil, &block)
      if block_given?
        get_current_tab

        @__cur_fields = []
        @field_stack ||= []
        @field_stack << @__cur_fields

        instance_eval &block

        row_fields = @field_stack.pop
        @__cur_fields = @field_stack.last

        if @field_stack.count == 0
          @__cur_tab[:fields] << FormFieldRow.new(*row_fields, title: title, html_options: html_options, options: options)
          @__cur_fields = nil
          @field_stack = nil
        else
          @__cur_fields << FormFieldRow.new(*row_fields, title: title, html_options: html_options, options: options)
        end
      end
    end

    def tab(title, &block)
      if block_given?
        add_tab(title: title)
        instance_eval &block
        @__cur_tab = nil
      end
    end

    def get_current_tab
      add_tab() unless @__cur_tab
      @__cur_tab
    end

    def add_tab(title: nil)
      if @__cur_tab && @__cur_tab[:fields].count == 0
        @__cur_tab[:title] = title
      else
        @__cur_tab = {
          title: title,
          fields: [],
        }
        @tabs << @__cur_tab
      end
      @__cur_tab
    end

    def field_row(*fields)
      FormFieldRow.new(*fields)
    end

    def text_field(name, options = {})
      FormField.new(FormField::TEXT_FIELD, name, options)
    end

    def hidden_field(name, options = {})
      FormField.new(FormField::HIDDEN_FIELD, name, options)
    end

    def text_area(name, options = {})
      FormField.new(FormField::TEXT_AREA, name, options)
    end

    def check_box(name, options = {})
      FormField.new(FormField::CHECK_BOX, name, options)
    end

    def check_box_list(name, items, options = {})
      options[:items] = items
      FormField.new(FormField::CHECK_BOX_LIST, name, options)
    end

    def radio_button_list(name, items, options = {})
      options[:items] = items
      FormField.new(FormField::RADIO_BUTTON_LIST, name, options)
    end

    def collection_select(name, items, value_field, title_field, options = {})
      FormField.collection_select(name, items, value_field, title_field, options)
    end

    def select(name, items, options = {})
      FormField.new(FormField::COLLECTION_SELECT, name, options.merge({ items: items }))
    end

    def password_field(name, options = {})
      FormField.new(FormField::PASSWORD_FIELD, name, options)
    end

    def autocomplete(name, options = {})
      FormField.new(FormField::AUTOCOMPLETE, name, options)
    end

    def read_only_field(name, options = {})
      options.merge!(readonly: true)
      FormField.new(FormField::READ_ONLY, name, options)
    end

    def custom_field(name, helper_method, options = {})
      options[:helper_method] = helper_method
      options[:field_names] ||= [] unless options[:field_names]
      FormField.new(FormField::CUSTOM, name, options)
    end

    def partial(partial_name, options = {})
      options[:partial_name] = partial_name
      FormField.new(FormField::PARTIAL, nil, options)
    end

    def date_field(name, options = {})
      FormField.new(FormField::DATE_FIELD, name, options)
    end

    def datetime_field(name, options = {})
      FormField.new(FormField::DATETIME_FIELD, name, options)
    end

    def html(options = {}, &block)
      FormField.new(FormField::HTML, nil, options, &block)
    end

    def block(title, options, &block)
      FormField.new(FormField::BLOCK, nil, options.merge(title: title), &block)
    end
  end
end
