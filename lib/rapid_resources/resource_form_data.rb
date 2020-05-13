module RapidResources
  class ResourceFormData
    attr_accessor :id, :html, :submit_title, :meta

    def initialize(id: nil, html: nil)
      @id = id
      @html = html
    end
  end
end
