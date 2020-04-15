module RapidResources
  class Page

    include ::Pundit
    public :policy

    include PageHelpers::PunditHelpers

    attr_reader :current_user
    attr_reader :url_helpers

    def initialize(user, url_helpers: nil)
      @current_user = user
      @url_helpers = url_helpers
      @sort_columns = []
    end

    def expose(items)
      return unless items.is_a?(Hash)
      items.each do |k,v|
        v_name = :"@#{k}"
        instance_variable_set(v_name, v)
      end
    end

    def index_html
      true
    end

    def model_class
      return @model_class if @model_class
      raise "Implement #model_class for #{self.class.name}"
    end

    def collection_fields
      @collection_fields ||= []
    end

    def collection_field(name, sortable: false, title: nil, link_to: nil, sorted: nil, cell_helper_method: nil, type: nil, css_class: nil)
      title ||= column_title(name)
      CollectionField.new(name,
        sortable: sortable, title: title, link_to: link_to,
        sorted: sorted, cell_helper_method: cell_helper_method,
        type: type, css_class: css_class
      )
    end

    def collection_idx_field
      CollectionField.idx
    end

    def collection_actions_field
      CollectionField.actions
    end

    def grid_paging
      false
    end

    def per_page
      nil
    end

    def grid_header_actions
      []
    end

    def grid_serializers
      {}
    end

    def grid_fields
      nil
    end

    def grid_expose
      {}
    end

    def default_order
      [:id, :asc]
    end

    def default_scope
      items = resource_policy_scope(model_class.all)
      items = items.alive if items.respond_to? :alive
      items
    end

    def load_items
      items = default_scope
      items = filter_items(items)
      items = order_items(items)

      items.is_a?(Array) ? items : items.all
    end

    def grid_filters
      []
    end

    def filter_params
      grid_filters.map(&:name)
    end

    def filter_args=(filter_args)
      return unless filter_args.is_a?(Hash)

      filter_args.each do |fk, fv|
        fk = fk.to_sym
        filter = grid_filters.find { |gf| gf.name == fk }
        next unless filter
        filter.filtered_value = fv
      end
    end

    def filter_items(items)
      grid_filters.each do |filter|
        next unless filter.has_value?
        if filter.type == GridFilter::TypeText && items.respond_to?(:full_text_search)
          items = items.full_text_search(filter.filtered_value)
        end

        items = apply_item_filter(items, filter)
      end

      items
    end

    def apply_item_filter(items, filter)
      items
    end

    def sort_param(jsonapi: false)
      s_fields = @sort_columns.map do |sort_col|
        col_field = collection_fields.find { |f| f.sortable && f.name == col_name }
        if col_field
          "#{f.sorted == :desc ? '-' : ''}#{jsonapi ? col_field.jsonapi_name : col_field.name}"
        else
          nil
        end
      end
      s_fields.compact!
      s_fields.join(',')
    end

    def sort_param=(new_sort)
      sort_columns = new_sort.split(',')
      sort_columns.map! do |col_name|
        desc = col_name.starts_with?('-')
        col_name = col_name[1..-1] if desc
        col_name = col_name.underscore
        col_field = collection_fields.find { |f| f.sortable && f.match_name?(col_name) }
        col_field ? [col_field.name, desc] : nil
      end
      sort_columns.compact!

      # apply given sort to columns
      @sort_columns = []
      collection_fields.each do |cf|
        sort_col, sort_desc = sort_columns.find { |sc| sc[0] == cf.name }
        if sort_col
          @sort_columns << sort_col
          cf.sorted = sort_desc ? :desc : :asc
        else
          cf.sorted = nil
        end
      end
    end

    def order_items(items)
      return items if items.is_a?(Array)

      # items = items.reorder('') # reset order to none
      order_fields = []

      @sort_columns.each do |col_name|
        col_field = collection_fields.find { |cf| cf.name == col_name }
        if col_field
          order_fields << [col_field.name, col_field.sorted]
        end
      end

      if order_fields.count.zero?
        # apply default order if set
        sort_field, sort_direction = default_order
        if sort_field
          order_fields << [sort_field, sort_direction]
          # mark default column ordered
          col_field = collection_fields.find { |cf| cf.sortable && cf.match_name?(sort_field) }
          col_field.sorted = sort_direction if col_field
        end
      end

      use_ordered = model_class.respond_to?(:ordered)
      if order_fields.count.positive?
        # apply specified order
        items = items.reorder('') # reset order to none
        order_fields.each do |col, direction|
          if use_ordered
            items = items.ordered(column: col, direction: direction == :desc ? :desc : :asc)
          else
            items = items.order(col => direction == :desc ? 'DESC' : 'ASC')
          end
        end
      elsif use_ordered
        # apply default order form model
        items = items.reorder('') # reset order to none
        items = items.ordered
      end

      if block_given?
        items = yield items, order_fields
      end

      items
    end

    def column_title(name)
      return nil if name == :idx || name == :actions
      # t("column.#{name}")
      title = I18n.translate(:"page.#{i18n_key}.columns.#{name}", {
        count: 1,
        default: nil,
        })
      title ||= model_class.human_attribute_name(name)
      title
    end

    def t(key)
      defaults = [
        :"page.base.#{key}",
        # key.to_s
      ]
      I18n.translate(:"page.#{i18n_key}.#{key}", {
        count: 1,
        default: defaults,
        })
    end

    def naming
      @naming ||= ActiveModel::Name.new(self.class)
    end

    def i18n_key
      @i18n_key ||= begin
        key = naming.i18n_key.to_s
        key.chomp!('_page')
        key
      end
    end

    def form(resource)
      Form.new
    end

    def form_fields(object)
      fields = []
      form(object).tabs.each do |tab|
        fields.concat tab[:fields]
      end
      fields
    end

    def display_form_errors
      @display_form_errors = true if @display_form_errors.nil?
      @display_form_errors
    end

    def display_form_errors=(value)
      @display_form_errors = value
    end

    def resource_errors(resource, exclude_form_fields: false)
      errors = []
      error_messages = resource.error_messages
      error_messages.concat resource.additional_error_messages if resource.respond_to?(:additional_error_messages)
      if error_messages.count.positive?
        f_fields = []
        form_fields(resource).each {|f| f_fields.concat(f.validation_keys) } if exclude_form_fields
        wildcard_f_fields = f_fields.map { |f| f.to_s }.select { |f| f.ends_with?('.') }
        error_messages.each do |attribute, message|
          if wildcard_f_fields.count.positive?
            attribute_s = attribute.to_s
            next if wildcard_f_fields.detect { |f| attribute_s.starts_with?(f) }
          end
          errors << message unless f_fields.include?(attribute)
        end
      end
      # errors.concat resource.additional_error_messages
      errors
    end

    def form_url(item)
      { action: item.persisted? ? :update : :create }
    end

    def form_options(options)
      options
    end

    def required_fields_context(resource)
    end

    def form_hide_buttons
      false
    end

    def form_buttons_partial(item)
    end

    def form_cancel_path(item)
    end

    def title_helper
    end

    def permitted_attributes(object)
      permitted_fields = []
      if (form_tabs = form(object).tabs)
        form_tabs.each do |tab|
          tab[:fields].each do |f|
            permitted_fields.concat f.params.flatten
          end
        end
      end
      permitted_fields
    end
  end
end