module RapidResources
  class CollectionField
    attr_reader :name, :title, :sortable, :link_to, :cell_helper_method, :css_class
    attr_accessor :sorted
    attr_reader :type

    class << self
      def actions
        # fields << [:actions, :actions_column, header: false] if with_actions
        new(':actions', title: nil)
      end

      def idx
        new(':idx', title: '#')
      end
    end

    def initialize(name, sortable: false, title: nil, link_to: nil, sorted: nil, cell_helper_method: nil, type: nil, css_class: nil)
      @name = name
      @sortable = sortable
      @title = title
      @sorted = sorted
      @str_names = [name.to_s]
      @cell_helper_method = cell_helper_method
      @link_to = link_to
      @type = type
      @css_class = css_class
    end

    def match_name?(name)
      @str_names.include?(name.to_s)
    end

    def to_jsonapi_column
      result = {
        name: name.to_s.camelize(:lower),
        title: title,
        sortable: sortable,
        sorted: sorted,
        css_class: css_class,
        type: type,
      }
      if link_to.present?
        result[:type] = 'link_to'
        result[:link_to] = link_to
      end
      result
    end
  end

end
