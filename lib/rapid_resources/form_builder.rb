module RapidResources
  class FormBuilder < ActionView::Helpers::FormBuilder

    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::TextHelper
    include ActionView::Helpers::UrlHelper

    # include Rails.application.routes.url_helpers

    attr_accessor :output_buffer
    def initialize(object_name, object, template, options)
      super
      # @output_buffer = nil
      @page = options[:page]
      @small = options[:small]

      required_fields_context = @page.required_fields_context(object)
      @required_fields = object.class.respond_to?(:required_fields) ? object.class.required_fields(required_fields_context) : []

      @context_stack = []
    end

    def row_check_box_list?
      @context_stack.last&.[](:check_box_list)
    end

    def field_html_name(*fields)
      field_names = [*fields].map{ |fld| "[#{fld.to_s.sub(/\?$/, '')}]" }.join
      "#{@object_name.to_s}#{field_names}"
    end

    def field_html_id(*fields)
      field_names = [*fields].map{ |fld| fld.to_s.sub(/\?$/, '') }.join('_')
      "#{@object_name.to_s}_#{field_names}"
    end

    def field_tag(field, *params, &block)
      field.options[:wrap_controls] = false
      self.field(field, *params, &block)
    end

    def fields_for(record_name, record_object = nil, options = {}, &block)
      opts = record_object.is_a?(Hash) ? record_object : options
      opts[:builder] ||= self.class
      opts[:page] ||= @page
      super(record_name, record_object, options, &block)
    end

    def field(field_or_name, *params, &block)
      if field_or_name.is_a?(RapidResources::FormFieldRow)

        wrapper_content_tag = :div
        html_options = { class: 'form-row' }.merge(field_or_name.html_options || {})
        html_options[:class] << ' check-box-list' if field_or_name.check_box_list?
        if field_or_name.section?
          wrapper_content_tag = :fieldset
          html_options = field_or_name.html_options&.dup || {}
          html_options[:class] = (['form-fields-group'] + [*html_options[:class]]).select { |c| c.present? }.join(' ')
        end

        @context_stack << field_or_name.options
        row_html = content_tag wrapper_content_tag, html_options do
          if field_or_name.section?
            section_title = content_tag(:div, class: 'section-title') do
              content_tag(:h4, field_or_name.title)
            end
            concat section_title
          end
          field_or_name.each_col do |fld, col_class|
            concat field(fld, wrap_col: col_class, skip_form_row: true)
          end
        end
        @context_stack.pop
        return row_html
      end

      html_block = nil

      name, type, options, css_class = if field_or_name.is_a?(RapidResources::FormField)
        validation_keys = field_or_name.validation_keys
        options = field_or_name.options
        options.delete(:validation_keys)
        options.merge!(params[0]) if Array === params && params.any? && Hash === params[0]
        options[:items] = field_or_name.items

        html_block = field_or_name.block if field_or_name.type == :html

        [field_or_name.name, field_or_name.type, options]
      else
        type, options = parse_field_params(params)
        name = field_or_name.to_sym if type != :custom || field_or_name
        validation_keys = [name]
        [name, type, options]
      end

      validation_keys.compact!

      wrap_col = options.delete(:wrap_col)
      skip_form_row = options.delete(:skip_form_row)

      skip_form_row = true unless wrap_col

      wrap_controls = true
      if type.to_s.ends_with?('_field')
        wrap_controls = !type.to_s.ends_with?('_field')
        type = type.to_s[0...-6].to_sym
      end

      wc = options.delete(:wrap_controls)
      wrap_controls = wc unless wc.nil?

      # if some transformation must be applied to value
      # a callable should be passed in value option
      if options[:value].respond_to?(:call)
        f_value = @object.send name
        options[:value] = options[:value].call(f_value)
      end

      errors = []
      validation_keys.each do |k|
        errors.concat @object.errors.full_messages_for(k)
      end

      if errors.any?
        css_class = [*options[:class]]
        css_class << 'is-invalid'
        options[:class] = css_class.join(' ')
      end

      control_html = case type
      when :text
        options[:value] = @object.send(name) unless options.key?(:value) #f_value = options.delete(:value) || @object.send(name)
        text_field name, options
      when :hidden
        hidden_field name, options
      when :text_area
        text_area name, options.merge(class: css_class(options, form_control_class))
      when :password
        password_field name, options.merge(class: css_class(options, form_control_class))
      when :date
        f_date = options.delete(:value) || @object.send(name)
        date_field(name, f_date, options)
      when :datetime
        f_date = options.delete(:value) || @object.send(name)

        if f_date.is_a?(String)
          dv = Date.strptime(f_date, '%d/%m/%Y') rescue nil
          f_date = dv if dv
        end

        f_time = false
        if time_name = options.delete(:time)
          f_time = @object.send(time_name) rescue nil
        end

        datetime_field(name, f_date, options, time: f_time)
      when :autocomplete
        # items = options.delete(:items) || []
        # id_field = options.delete(:value_field) || :id
        # title_field = options.delete(:title_field) || :title

        # selected_id    = nil
        # selected_title = nil
        # if Hash === options[:selected] && options[:selected].key?(id_field) && options[:selected].key?(title_field)
        #   selected_id    = options[:selected][id_field]
        #   selected_title = options[:selected][title_field]
        # else
        #   f_item = @object.send(name.to_s[0...-3]) if name.to_s.ends_with?('_id')
        #   if f_item
        #     selected_id    = f_item.send(id_field)
        #     selected_title = f_item.send(title_field)
        #   end
        # end

        # control_options = {
        #   class: css_class(options, form_control_class + ' custom-select autocomplete')
        # }
        # control_options['data-autocomplete-url'] = options[:url] if options[:url]
        # control_options['data-allow-other'] = 'true' if options[:allow_other]
        # select name, @template.options_for_select(items, selected_id), {}, control_options
        autocomplete_field(name, options)
      when :check_box
        wrap_controls = false if row_check_box_list?
        g_label = options.delete(:global_label)
        html_options = options.dup
        options.delete(:help_text)
        options[:label] = g_label.blank? ? false : g_label
        check_box(name, html_options)
      when :check_box_list
        items = options.delete(:items) || []
        check_box_list(name, items, options)
      when :radio_button_list
        items = options.delete(:items) || []
        radio_button_list(name, items, options)
      when :upload
        multiple = options[:multiple]
        files = options[:files]
        content_tag :div, class: 'uploads-wrap' do
          "File uploads ...."
        end
      when :collection
        collection_field(name, options, &block) if block_given?
      when :select
        choices = options.delete(:choices) || []
        select_options = options.delete(:options) || {}
        select name, choices, select_options, options.merge(class: css_class(options, select_control_class))
      when :collection_select
        select_options = {
          prompt: options.delete(:prompt),
          include_blank: options.delete(:include_blank),
        }
        options[:disabled] = true if options.delete(:readonly)

        options['data-autocomplete'] = 'true' if options.delete(:autocomplete)
        select_options[:selected] = options.delete(:selected) if options.key?(:selected)
        if options[:value_field] || options[:title_field]
          collection_select name, options.delete(:items), options.delete(:value_field),
            options.delete(:title_field), select_options, options.merge(class: css_class(options, select_control_class))
        else
          select name, options.delete(:items), select_options, options.merge(class: css_class(options, select_control_class))
        end
      when :read_only
        read_only(name, options)
      when :custom
        if block_given?
          @template.capture(&block)
        else
          opts = options.dup
          helper_method = opts.delete(:helper_method)
          @template.send(helper_method, @object, name, self, opts) unless helper_method.blank?
        end
      when :partial
        wrap_controls = false
        partial_name = options.delete(:partial_name)
        locals = { f: self }
        locals.merge!(options.delete(:locals) || {})
        @template.render(partial: partial_name, locals: locals)
      when :html
        @template.instance_eval &html_block if html_block
      else
        content_tag :p, "Invalid field: '#{type}'", class: 'form-control-static text-danger'
      end

      additional_group_class = options.delete(:form_group_css_class)
      if wrap_controls
        help_text = options.delete(:help_text)
        wrap_col = " #{wrap_col.is_a?(Numeric) ? "col-md-#{wrap_col}" : wrap_col}" unless wrap_col.blank?
        wrap_html = content_tag :div, class: "form-group#{wrap_col} #{additional_group_class}" do
          control_class = form_control_class + ' input-sm'
          if type != :hidden && options[:label] != false && (name || options[:label])
            opts = {}
            opts[:for] = field_html_id(name, :date) if type == :datetime
            label_text = if String === options[:label]
              options[:label]
            else
              # object.class.human_attribute_name(name)
              # name
              object.class.human_attribute_name(name, form: true)
            end
            opts[:class] = 'required' if @required_fields.include?(name)
            concat label(name, label_text, opts)
          else
            control_class = "#{control_class}"
          end
          # concat content_tag :div, control_html, class: control_class
          concat control_html
          concat content_tag(:small, help_text, class: 'form-text text-muted') if help_text.present?
          concat content_tag(:div, errors.join('; '), class: 'invalid-feedback') if errors.any?
        end
        wrap_html = content_tag(:div, wrap_html, class: 'form-row') unless skip_form_row

        wrap_html
      else
        control_html
      end
    end

    def form_control_class
      @form_control_class ||= @small ? 'form-control form-control-sm' : 'form-control'
    end

    def select_control_class
      @select_control_class ||= @small ? 'custom-select custom-select-sm' : 'custom-select'
    end

    def form_row(options = {}, &block)
      @context_stack << options
      result = content_tag :div, class: css_class(options, 'form-row') do
        @template.capture(self, &block)
      end
      @context_stack.pop
      result
    end

    def form_group(col: nil, &block)
      col_class = if col
        col.is_a?(Numeric) ? "col-md-#{col}" : col
      else
        'col-md-12'
      end
      content_tag :div, class: "form-group #{col_class}" do
        @template.capture(self, &block)
      end
    end

    def text_field(name, options = {})
      options[:class] = [form_control_class, options[:class]].compact.join(' ')

      if options[:scope]
        scoped_field(:text_field, name, options)
      else
        super(name, options)
      end
    end

    def hidden_field(name, options = {})
      if options[:scope]
        scoped_field(:hidden_field, name, options)
      elsif options[:array_idx]
        scoped_field(:hidden_field, name, options)
      else
        super(name, options)
      end
    end

    def extract_scope(options)
      options = @default_options.merge(options)

      scope, scoped_object = options.delete(:scope)
      options[:object] = scoped_object if scoped_object

      [options, scope, scoped_object]
    end

    def scoped_field(field_name, method, options)
      # cant use objectify_options(options) because that method overrides :options key

      options, scope, scoped_object = extract_scope(options)


      # options, scope, scoped_object = if options[:scope]
      #   extract_scope(options)
      # else
      #   [options, method, field_name]
      # end

      # array_idx = options.delete(:array_idx)
      # options[:object] ||= @object

      # if array_idx == true
      #   scope = "#{scope}[]"
      # elsif array_idx
      #   scope = "#{scope}[#{array_idx}]"
      # end

      @template.send( #   @template.send(
          field_name, #     "text_field",
          scope,      #     @object_name,
          method,     #     method,
          options)    #     objectify_options(options))'
    end

    def check_box(name, html_options = {}, checked_value = '1', unchecked_value = '0')
      label = html_options.delete(:label)
      html_options[:disabled] = true if html_options.delete(:readonly)
      help_text = html_options.delete(:help_text)
      small_help_text = html_options.delete(:small_help_text)

      content_tag :div, class: 'custom-control custom-checkbox' do
        html_options[:class] = 'custom-control-input'
        obj_name = @object_name
        obj = @object
        options = html_options

        if html_options[:scope]
          options, obj_name, obj = extract_scope(options)
          concat @template.check_box(obj_name, name, options, checked_value, unchecked_value)
        else
          concat super(name, html_options)
        end
        label_text = if label.is_a?(String)
          label
        elsif label != false
          obj.class.human_attribute_name(name)
        end
        # concat label(name, label_text, class: 'custom-control-label')
        concat @template.label(obj_name, name, label_text, options.merge(class: 'custom-control-label'))

        unless help_text.blank?
          p_class = small_help_text ? 'small text-muted' : 'form-text'
          concat content_tag(:p, help_text, class: p_class)
        end
      end
    end

    def check_box_list(name, items, html_options = {}, &block)
      inline = html_options.delete(:inline)

      cb_options = html_options.delete(:check_box)
      cb_options = {} unless cb_options.is_a?(Hash)
      cb_options[:disabled] = true if html_options.delete(:readonly)
      cb_items = collection_check_boxes name, items, :second, :first do |b|
        css_class = 'custom-control custom-checkbox'
        css_class << ' custom-control-inline' if inline
        cb_html = content_tag :div, class: css_class do
          buffer = ''.html_safe
          buffer << b.check_box({class: 'custom-control-input'}.merge(cb_options))
          buffer << b.label(class: 'custom-control-label')

          # if help_messages[b.value]
          #   buffer << content_tag(:small, help_messages[b.value], class: 'custom-control form-text text-muted')
          # end

          buffer
        end
        cb_html << @template.capture(b.object, &block) if block_given?
        cb_html
      end
      if inline
        content_tag(:div, cb_items, class: [*html_options[:class]].join(' '))
      else
        content_tag(:div, cb_items, class: 'custom-controls-stacked')
        css_class = ['custom-controls-stacked']
        css_class.concat [*html_options[:class]]
        content_tag(:div, cb_items, class: css_class.join(' '))
      end
    end

    def radio_button(name, tag_value, html_options = {}, &block)
      radio_label = html_options.delete(:label)
      css_class = %w(custom-control custom-radio)
      css_class.concat [*html_options.delete(:class)]

      content_tag :div, class: css_class.join(' ') do
        obj_name = @object_name
        obj = @object
        options = html_options
        if options[:scope]
          options, obj_name, obj = extract_scope(options)
          concat @template.radio_button(obj_name, name, tag_value, options.merge(class: 'custom-control-input'))
        else
          concat super(name, html_options.merge(class: 'custom-control-input'))
        end

        label_html = if block_given?
          @template.capture(self, &block)
        elsif radio_label.is_a?(String)
          radio_label
        elsif radio_label != false
          obj.class.human_attribute_name(name)
        end
        concat @template.label(obj_name, name, label_html, options.merge(class: 'custom-control-label', value: tag_value))
      end
    end

    def radio_button_list(name, items, html_options = {}, &block)
      inline = html_options.delete(:inline)

      help_messages = html_options.delete(:help_messages)
      help_messages = {} unless help_messages.is_a?(Hash)

      cb_options = html_options.delete(:check_box)
      cb_options = {} unless cb_options.is_a?(Hash)
      cb_options[:disabled] = true if html_options.delete(:readonly)
      cb_items = collection_radio_buttons name, items, :second, :first do |b|

        css_class = 'custom-control custom-radio'
        css_class << ' custom-control-inline' if inline
        cb_html = content_tag :div, class: css_class do
          buffer = ''.html_safe
          buffer << b.radio_button({class: 'custom-control-input'}.merge(cb_options))
          buffer << b.label(class: 'custom-control-label')

          if help_messages[b.value]
            buffer << content_tag(:small, help_messages[b.value], class: 'custom-control form-text text-muted')
          end

          buffer
        end
        cb_html << @template.capture(b.object, &block) if block_given?
        cb_html
      end
      if inline
        content_tag(:div, cb_items)
      else
        content_tag(:div, cb_items, class: 'custom-controls-stacked')
      end
    end

    def date_field(name, value, html_options = {})
      readonly = html_options.delete(:readonly)
      css_class = [*html_options[:class]]
      css_class << 'input-group date'
      html_options[:class] = css_class.compact.join(' ')
      content_tag :div, html_options do
        input_options = { class: 'date', 'ref' => 'date' }
        input_options[:readonly] = true if readonly
        input_options[:value] = value.respond_to?(:strftime) ? value.strftime('%d/%m/%Y') : value.to_s
        concat text_field(name, input_options)
        toggler = content_tag(:div, class: 'input-group-append') do
          content_tag(:button, '', type: 'button', class: 'btn btn-date', 'ref' => 'date-toggler', disabled: readonly)
        end
        concat toggler
      end
    end

    def datetime_field(name, value, html_options = {}, options = {})
      time = options.delete(:time)
      time_value = nil
      if time == false
        # time comes from date object
        time_value = value
      else
        time_value = time
      end

      date_str = if value.respond_to?(:strftime)
        value.strftime('%d/%m/%Y')
      else
        value.to_s
      end

      time_str = if time_value.respond_to?(:strftime)
        time_value.strftime('%H:%M')
      else
        time_value.to_s
      end

      readonly = html_options.delete(:readonly)
      css_class = [*html_options[:class]]
      css_class << 'input-group date datetime'
      html_options[:class] = css_class.compact.join(' ')
      content_tag :div, html_options do
        date_input_options = { class: 'date', 'ref' => 'date', name: field_html_name(name, :date), id: field_html_id(name, :date) }
        date_input_options[:readonly] = true if readonly
        concat text_field(name, date_str, date_input_options)
        concat content_tag(:div, content_tag(:button, content_tag(:span, '', class: 'glyphicons calendar'), type: 'button', class: 'btn btn-picker btn-outline-secondary', 'ref' => 'date-toggler', disabled: readonly), class: 'input-group-append')

        time_input_options = { class: 'time', 'ref' => 'time', name: field_html_name(name, :time), id: field_html_id(name, :time) }
        time_input_options[:readonly] = true if readonly
        concat text_field(name, time_str, time_input_options)
        concat content_tag(:div, content_tag(:button, content_tag(:span, '', class: 'glyphicons time'), type: 'button', class: 'btn btn-picker btn-outline-secondary', 'ref' => 'time-toggler', disabled: readonly), class: 'input-group-append ui-timepicker-trigger')
      end
    end

    def autocomplete_field(name, options = {})
      # css_class = [form_control_class, html_options.delete(:class)].compact.join(' ')
      # html_options = html_options.merge(value: value, class: css_class)
      # super_text_field(name, html_options)

      items = options.delete(:items) || []
      id_field = options.delete(:value_field) || :id
      title_field = options.delete(:title_field) || :title

      selected_id    = nil
      selected_title = nil
      if Hash === options[:selected] && options[:selected].key?(id_field) && options[:selected].key?(title_field)
        selected_id    = options[:selected][id_field]
        selected_title = options[:selected][title_field]
      else
        f_item = name.to_s[0...-3]
        if name.to_s.ends_with?('_id') && !f_item.blank? && @object.respond_to?(f_item)

          if (obj = @object.send(f_item)) && obj.respond_to?(id_field) && obj.respond_to?(title_field)
            selected_id    = f_item&.send(id_field)
            selected_title = f_item&.send(title_field)
          end
        else
          selected_id = @object.send(name)
        end
      end

      control_options = {
        class: css_class(options, form_control_class + ' custom-select autocomplete')
      }
      control_options['data-autocomplete-url'] = options[:url] if options[:url]
      control_options['data-allow-other'] = 'true' if options[:allow_other]
      control_options['data-placeholder'] = options[:placeholder] if options[:placeholder]
      control_options['data-allow-clear'] = 'true' if options[:allow_clear]
      control_options['ref'] = options[:ref] if options[:ref]

      items = items.map do |item|
        if item.is_a?(Hash)
          [item[title_field], item[id_field]]
        else
          [item.send(title_field), item.send(id_field)]
        end
      end

      if options[:field_tag]
        @template.select_tag name, @template.options_for_select(items, selected_id), control_options
      else
        select name, @template.options_for_select(items, selected_id), {}, control_options
      end
    end

    def read_only(name, options = {})
      html_options = options[:html].dup || {}
      html_options[:class] = css_class(html_options, form_control_class)
      html_options[:readonly] = true
      @template.text_field_tag(nil, @object.send(name), html_options)
      # @template.text_field('candidate', name, html_options)
    end

    def buttons(options = {})
      options = {
        cancel_url: [@object.class]
      }.merge(options)
      content_tag :div, class: 'form-group' do
        content_tag :div, class: 'col-sm-offset-2 col-sm-10' do
          concat button(options[:submit_title] || 'Save', type: 'submit', name: nil, class: 'btn btn-default')
          if options[:reset]
            concat ' '
            title = options[:reset].is_a?(String) ? options[:reset] : 'Reset'
            concat button(title, type: 'reset', class: 'btn btn-default')
          end
          if options[:clean]
            concat ' '
            title = options[:clean].is_a?(String) ? options[:clean] : 'Reset'
            concat button(title, type: 'button', 'data-action' => 'clean-form', class: 'btn btn-default')
          end
          if options[:cancel_url]
            concat ' '
            concat @template.link_to('Cancel', options[:cancel_url], class: 'btn btn-default')
          end
        end
      end
    end

    def collection_field(name, options, &block)
      collection_obj_class = @object.send(name).klass
      @collection_name = name.to_s
      @collection_builder = self.class
      @collection_obj = collection_obj_class.respond_to?(:build_new) ? collection_obj_class.build_new
                                                                    : collection_obj_class.new
      result = @template.capture(self, &block)
      result.gsub!('__idx__', '{ i }')

      @collection_name = nil
      @collection_builder = nil
      @collection_obj = nil

      result.html_safe
    end

    def item_template_form(&block)
      item_form = fields_for "#{@collection_name}_attributes", @collection_obj, index: '__idx__', builder: @collection_builder, &block
      item_form
    end

    def riot_tag(tag_name, items = {}, mixin_name = nil, &block)
      result = ActiveSupport::SafeBuffer.new
      result << %[<div riot-tag="#{tag_name}" class="#{tag_name}"></div>\n].html_safe
      result << %-<script type="riot/tag">\n-.html_safe
      result << "\t<#{tag_name}>\n".html_safe
      result << @template.capture(&block) if block_given?
      result << "\n\n\tthis.mixin(#{mixin_name})\n" unless mixin_name.blank?
      result << "\t</#{tag_name}>\n".html_safe
      result << %-</script>\n-.html_safe
      result << %/<script>\n\t$(function(){ riot.mount('#{tag_name}', /.html_safe
      result << items.to_json.html_safe
      result << %[);});\n</script>\n].html_safe

      result
    end

    def label_for(field, options = {})
      form_field = @page.form_field(@object, field)
      if form_field
        w = options.key?(:w) ? options[:w] : 'col-sm-2'
        label(form_field.name, class: [w, 'control-label'].join(' '))
      end
    end

    def control_for(field, options = {})
      form_field = @page.form_field(@object, field)
      if form_field
        options = { wrap_controls: false }.merge(options)
        field(form_field, options)
      end
    end

    def fields(only: [], except: [])
      only = [] unless Array === only
      except = [] unless Array === except

      response = "".html_safe
      if only.any?
        @page.form(@object).each do |form_field|
          response << field(form_field) if only.include?(form_field.name)
        end
      elsif except.any?
        @page.form(@object).each do |form_field|
          response << field(form_field) unless except.include?(form_field.name)
        end
      else
        # render all fields
        @page.form(@object).each do |form_field|
          response << field(form_field)
        end
      end
      response
    end

    protected
    def css_class(options, base_class = nil)
      [base_class, options[:class]].compact.join(' ')
    end

    def parse_field_params(params)
      if Array === params
        type = nil
        options = nil
        if Hash === params[0]
          type = params[:type]
          options = params
        else
          type = params[0]
        end

        unless options
          options = params[1] if params.length > 1 && Hash === params[1]
          options ||= {}
        end

        [type, options]
      else
        [nil, {}]
      end
    end
  end
end
