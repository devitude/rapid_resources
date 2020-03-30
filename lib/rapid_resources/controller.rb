module RapidResources
  module Controller
    extend ActiveSupport::Concern

    included do
      before_action :load_res
      define_callbacks :load_res
    end

    class_methods do
      def page_class
        nil
      end

      def around_load_res(*names, &blk)
        _insert_callbacks(names, blk) do |name, options|
          set_callback(:load_res, :around, name, options)
        end
      end

      def before_load_res(*names, &blk)
        _insert_callbacks(names, blk) do |name, options|
          set_callback(:load_res, :before, name, options)
        end
      end

      def after_load_res(*names, &blk)
        _insert_callbacks(names, blk) do |name, options|
          set_callback(:load_res, :after, name, options)
        end
      end
    end

    def index
      authorize_resource :index?

      respond_to do |format|
        format.jsonapi do
          grid_list
        end
        format.any do
          items = load_items

          @items = items
          @page = page
        end
      end
    end

    def new
      authorize_resource :new?
      return if response_rendered?

      render locals: {
        page: page,
        item: @resource,
      }
    end

    def create
      authorize_resource :create?

      result = save_resource(@resource, resource_params)
      if result.ok?
        save_response(:create)
        return
      end

      save_response(:create, false)
      return if response_rendered?

      r_params = {
        locals: {
          item: @resource,
          page: page
        }
      }

      respond_to do |format|
        format.html { render :new, r_params}
        # format.json do
        #   if jsonapi_form?
        #     render_jsonapi_form(error: result)
        #   else
        #     @modal = true
        #     # @html = render_to_string(:new, r_params.merge(layout: false, formats: [:html]))
        #     # render :new, formats: [:json]
        #     json_data = {
        #       'html' => render_to_string(:new, r_params.merge(layout: false, formats: [:html]))
        #     }
        #     json_data.merge! get_additional_json_data
        #     render json: json_data #, formats: [:json]
        #   end
        # end
        # format.jsonapi do
        #   if jsonapi_form?
        #     render_jsonapi_form(error: result)
        #   else
        #     render_jsonapi_resource_error
        #   end
        # end
      end
    end

    def edit
      authorize_resource :edit?
      return if response_rendered?

      render locals: {
        page: page,
        item: @resource,
      }
    end

    protected

    def _prefixes
      # add resources
      super << 'resources'
    end

    def page
      @page ||= create_page
    end

    # FIXME: use ActionController::Metal.performed? instead
    def response_rendered?
      # response_body
      performed?
    end

    # FIXME: migrate all pages and get rid of extra_params
    def create_page(page_class: nil)
      page_class ||= self.class.page_class
      new_page = page_class.new(current_user, url_helpers: self)

      if expose_items = page_expose
        new_page.expose(expose_items)
      end
      new_page
    end

    def page_expose
      nil
    end

    def authorize_resource(query)
      case query
      when :index?
        authorize page.model_class, query
      else
        authorize @resource, query
      end
    end

    def load_items(page: nil)
      page ||= self.page
      filter_params = if params.key?(:filter)
        params.fetch(:filter, {}).permit(*page.filter_params).to_h
      else
        params.permit(*page.filter_params).to_h
      end

      page.sort_param = params[:sort].to_s if params[:sort]
      page.filter_args = filter_params#params.permit(*grid_page.filter_params).to_h
      page.load_items
    end

    def grid_links(page)
      # { new: url_for({ action: :new}) } if page.index_actions.include?(:new)
      nil
    end

    def grid_meta(attributes)
      attributes
    end

    def grid_list(grid_page: nil, grid_items: nil, jsonapi_include: nil, additional_meta: nil)
      grid_page ||= page
      grid_items ||= load_items(page: grid_page)
      # grid_items, columns = grid_items(grid_page: grid_page, grid_items: grid_items)
      columns = grid_page.collection_fields

      if grid_page.grid_paging && grid_items.respond_to?(:page)
        grid_items = grid_items.page params[:page]
        if per_page = grid_page.per_page
          grid_items = grid_items.per(per_page)
        end
        grid_items = grid_items.page(1) if grid_items.current_page > grid_items.total_pages
        paginator = GridPaginator.new(total_pages: grid_items.total_pages, current_page: grid_items.current_page, per_page: grid_items.current_per_page)
      end

      # if grid_page.collection_actions.include?(:edit)
      #   columns << CollectionField.new(':actions', title: '', sortable: false)
      # end

      columns.map!(&:to_jsonapi_column)
      meta_fields = {
        columns: columns,
        filters: grid_page.grid_filters.map(&:to_jsonapi_filter),
        pages: paginator&.pages,
        current_page: paginator&.current_page,
        total_pages: paginator&.total_pages,
        page_first_index: paginator&.first_idx_in_page || 1,
        headerActions: grid_page.grid_header_actions.map(&:to_jsonapi)
      }
      meta_fields.merge!(additional_meta) if additional_meta.is_a?(Hash)

      jsonapi_index_response(grid_items,
        serializers: grid_page.grid_serializers,
        meta: grid_meta(meta_fields),
        links: grid_links(grid_page),
        render_fields: grid_page.grid_fields,
        expose: grid_page.grid_expose,
        jsonapi_include: jsonapi_include,
      )
    end

    def jsonapi_index_response(items, serializers: {}, meta: nil, links: nil, expose: {}, render_fields: nil, jsonapi_include: nil)
      jsonapi_options = {
        class: serializers,
        meta: meta,
        links: links,
        expose: {
          url_helpers: self,
          current_user: current_user,
        }.merge(expose || {})
      }
      jsonapi_options[:fields] = render_fields if render_fields
      jsonapi_options[:include] = jsonapi_include if jsonapi_include
      render jsonapi: items, **jsonapi_options
    end

    # load a single resource or build a resource
    def load_res
      @resource ||= begin
        if load_item_actions.include?(action_name)
          load_resource
        elsif build_item_actions.include?(action_name)
          build_resource
        end
      end
    end

    def load_resource
      page
        .default_scope
        .where(page.model_class.primary_key => params[id_param])
        .first!
    end

    def build_resource
      if page.model_class.respond_to?(:build_new)
        page.model_class.build_new
      else
        page.model_class.new
      end
    end

    def load_item_actions
      @load_item_actions ||= (%w[edit update destroy show] + additional_load_item_actions).freeze
    end

    def additional_load_item_actions
      []
    end

    def build_item_actions
      @build_item_actions ||= (%w[new create] + additional_build_item_actions).freeze
    end

    def additional_build_item_actions
      []
    end

    def id_param
      :id
    end

    def save_resource(resource, resource_params)
      resource.assign_attributes(resource_params)
      if resource.valid?(:form) && resource.save
        Result.ok
      else
        Result.err
      end
    end

    def save_response(action, saved = true)
      return unless saved

      respond_to do |format|
        format.html { redirect_to redirect_route(action) }
        format.json do
          if jsonapi_form?
            render jsonapi: @resource, expose: { url_helpers: self, current_user: current_user }, status: 201
          else
            json_data = {'status' => 'success'}
            json_data.merge! get_additional_json_data
            render json: json_data
          end
        end
        format.jsonapi do
          render_jsonapi_resource
        end
      end
    end

    def resource_params
      params_name = page.model_class.to_s.underscore.gsub('/', '_')

      # if request.format.jsonapi? && (deserializer = jsonapi_params_deserializer)
      #   resp = deserializer.call(params[:_jsonapi].to_unsafe_h)
      #   r_params = ActionController::Parameters.new(params_name => resp)
      #   r_params.require(params_name).permit(page.permitted_attributes(@resource))
      # else
        params
          .require(params_name)
          .permit(page.permitted_attributes(@resource))
      # end
    end

  end
end
