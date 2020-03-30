module RapidResources
  class GridHeaderAction
    Url = 1
    Action = 2
    Separator = 3
    List = 4

    attr_reader :title, :name, :url, :type, :group, :items

    def initialize(type, title = nil, name: nil, url: nil, group: nil, items: nil)
      @type = type
      @title = title
      @name = name
      @url = url
      @group = group
      @items = items
    end

    class << self
      def separator
        new(Separator)
      end

      def action(name, title, url: nil, group: nil)
        new(Action, title, name: name, url: url, group: group)
      end

      def url(title, url: nil, group: nil)
        new(Url, title, url: url, group: group)
      end

      def list(&block)
        item = new(List)
        item.instalce_eval(&block) if block_given?
        item
      end
    end

    def add_item(item)
      @items ||= []
      @items << item
    end

    def type_str
      @@type_mapping ||= {
        Url => 'url',
        Action => 'action',
        Separator => 'separator',
        List => 'list'
      }
      @@type_mapping[@type]
    end

    def to_jsonapi
      if @type == List
        @items.map(&:to_jsonapi)
      else
        {
          type: type_str,
          name: @name,
          title: @title,
          url: @url,
          group: @group
        }
      end
    end
  end
end