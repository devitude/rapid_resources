module RapidResources
  class FormFieldRow

    attr_reader :title, :html_options, :options

    def initialize(*fields, title: nil, html_options: nil, options: nil)
      @title = title
      @html_options = html_options
      @options = options || {}

      empty_cols = 0
      @fields = fields.map do |fld, col|
        empty_cols += 1 unless col
        [fld, col]
      end
      @empty_col_class = 'col'
      @empty_col_class = "col-md-#{12 / empty_cols}" if empty_cols == @fields.count && empty_cols > 0
    end

    def section?
      title.present?
    end

    def check_box_list?
      options[:check_box_list]
    end

    def params
      @fields.map{|fld, col| fld.params}
    end

    def validation_keys
      v_keys = []
      @fields.each {|fld, col| v_keys.concat(fld.validation_keys)}
      v_keys
    end

    def each_col
      return unless block_given?
      @fields.each do |field, col|
        col = if col.is_a? Numeric
          "col-md-#{col}"
        elsif col == :auto
          'col-auto'
        elsif col.present?
          col
        else
          nil
        end

        col_class = col ? col : (check_box_list? || section? ? nil : @empty_col_class)
        yield field, col_class
      end
    end
  end
end
