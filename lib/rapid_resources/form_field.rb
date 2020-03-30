module RapidResources
  class FormField
    TEXT_FIELD = :text
    HIDDEN_FIELD = :hidden
    TEXT_AREA  = :text_area
    CHECK_BOX  = :check_box
    PASSWORD_FIELD = :password
    CHECK_BOX_LIST = :check_box_list
    RADIO_BUTTON_LIST = :radio_button_list
    COLLECTION_SELECT = :collection_select
    CUSTOM     = :custom
    DATE_FIELD = :date
    DATETIME_FIELD = :datetime
    AUTOCOMPLETE = :autocomplete
    READ_ONLY = :read_only
    PARTIAL = :partial
    HTML = :html
    BLOCK = :block

    attr_reader :type, :name, :options, :block
    def initialize(type, name, options = {}, &block)
      @type = type
      @name = name
      @options = options
      @block = block if block_given?
    end

    def form_name
      if @type == CHECK_BOX_LIST
        "#{name}[]"
      else
        name
      end
    end

    def items
      @options[:items]
    end

    def css_class(base_class = nil)
      [base_class, options[:class]].compact.join(' ')
    end

    def params
      prms = if @options[:readonly]
        []
      elsif @type == CHECK_BOX_LIST
        [{name => []}]
      elsif @type == DATETIME_FIELD
        [{name => [:date, :time]}]
      elsif @type == COLLECTION_SELECT && @options[:multiple]
        [{name => []}]
      else
        [name]
      end

      if @options.key?(:field_names) && @options[:field_names]
        prms.concat @options[:field_names]
      end
      prms
    end

    def model_attribute_keys
      if @type == CUSTOM && @options.key?(:field_names)
        f_names = @options[:field_names].map do |opt|
          opt.is_a?(Hash) ? opt.keys : opt
        end
        f_names.flatten!
        f_names.compact!
        f_names
      else
        [name]
      end
    end

    def validation_keys
      model_attribute_keys + (options[:validation_keys] || [])
    end

    class << self
      def collection_select(name, items, value_field, title_field, options = {})
        new(COLLECTION_SELECT, name, options.merge({ items: items, value_field: value_field, title_field: title_field }))
      end
    end
  end
end
