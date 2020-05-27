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
      authorize_action :index?

      respond_to do |format|
        format.jsonapi do
          grid_list
        end
        format.xlsx do
          items = load_items
          columns = page.collection_fields

          xlsx_path = generate_xlsx_file(items, columns)
          send_file xlsx_path, filename: xlsx_filename, type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        end
        format.any do
          items = load_items

          @items = items
          @page = page
        end
      end
    end

    def new
      authorize_action :new?
      return if response_rendered?

      respond_to do |format|
        format.jsonapi do
          render_jsonapi_form
        end
        format.any do
          render locals: {
            page: page,
            item: @resource,
          }
        end
      end
    end

    def create
      authorize_action :create?

      result = save_resource(@resource, resource_params)
      return if response_rendered?

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
        # format.jsonapi do
        #   render_jsonapi_form(error: result)
        # end
        format.any { render :new, r_params}
        format.jsonapi do
          render_jsonapi_form(error: result)
        end
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
      authorize_action :edit?
      return if response_rendered?

      respond_to do |format|
        format.jsonapi do
          render_jsonapi_form
        end
        format.any do
          render locals: {
            page: page,
            item: @resource,
          }
        end
      end
    end

    def update
      authorize_action :update?

      result = save_resource(@resource, resource_params)
      return if response_rendered?

      if result.ok?
        save_response(:update)
        return
      end

      save_response(:update, false)

      return if response_rendered?

      r_params = {
        locals: {
          item: @resource,
          page: page
        }
      }

      respond_to do |format|
        format.html { render :edit, r_params}
        # format.json do
        #   if jsonapi_form?
        #     render_jsonapi_form(error: result)
        #   else
        #     @modal = true
        #     # @html = render_to_string(:new, r_params.merge(layout: false, formats: [:html]))
        #     # render :new, formats: [:json]
        #     json_data = {
        #       'html' => render_to_string(:edit, r_params.merge(layout: false, formats: [:html]))
        #     }
        #     json_data.merge! get_additional_json_data
        #     render json: json_data #, formats: [:json]
        #   end
        # end
        # format.jsonapi do
        #   render_jsonapi_form(error: result)
        # end
      end
    end

    protected

    def _prefixes
      # add resources
      super << 'resources'
    end

    def jsonapi_form?
      params[:jsonapi_form] == '1'
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

    def authorize_action(query)
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
        expose: { page: grid_page }.merge(grid_page.grid_expose),
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

    def render_jsonapi_form_error(error, status: 422)
      frm_id = controller_path.split('/').last.singularize.camelize.freeze
      form_data = ResourceFormData.new(id: "frm-#{frm_id}") #(id: 'new-project')
      form_data.html = ''
      form_data.meta = { error: { message: error } }
      render jsonapi: form_data, status: status
    end

    def render_jsonapi_form(error: nil, form_id: nil, form_page: nil)
      form_page ||= page

      old_display_errors = form_page.display_form_errors
      @modal = true
      form_page.display_form_errors = false
      frm_id = controller_path.split('/').last.singularize.camelize.freeze
      form_data = ResourceFormData.new(id: "frm-#{frm_id}") #(id: 'new-project')
      # form_data.submit_title = @resource.new_record? ? 'Create new project' : 'Save project' # page.t(@resource.persisted? ? :'form_action.update' : :'form_action.create')
      form_data.submit_title = form_page.t(@resource.persisted? ? :'form.action.update' : :'form.action.create')
      form_data.html = render_to_string(partial: 'form',
        formats: [:html],
        locals: {
          page: form_page,
          item: @resource,
          jsonapi_form: 1,
        })
      form_page.display_form_errors = old_display_errors

      if error.present?
        if error.is_a?(Result) && error.error.present?
          form_data.meta = { error: { message: "Notikusi kļūda: #{error.error}"} }
        else
          form_data.meta = { error: { message: 'Notikusi kļūda', details: @resource.error_messages.map(&:second) } }
        end
        render jsonapi: form_data, status: 422
      else
        render jsonapi: form_data, class: { :'RapidResources::ResourceFormData' => SerializableResourceFormData }, expose: { url_helpers: self, current_user: current_user }
      end
    end

    # load a single resource or build a resource
    def load_res
      if @resource.nil?
        run_callbacks :load_res do
          @resource ||= begin
            if load_item_actions.include?(action_name)
              load_resource
            elsif build_item_actions.include?(action_name)
              build_resource
            end
          end
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
            headers['JsonapiForm-Status'] = 'success'
            render jsonapi: @resource, expose: { page: page, url_helpers: self, current_user: current_user }
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

    def index_route_url
      { action: :index }
    end

    def redirect_route(action = nil)
      index_route_url
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

    def xlsx_filename
      'items.xlsx'
    end

    def generate_xlsx_file(items, columns, sheet_name: 'Items')
      xlsx = Axlsx::Package.new do |package|
        package.workbook.use_shared_strings = true # otherwise file can not be read back by rubyXL
        package.workbook.add_worksheet(name: sheet_name) do |sheet|
          headers = columns.map { |c| c.title }
          sheet.add_row headers

          items.each do |item|
            row_data = []
            columns.each do |c|
              val = item.send(c.name) rescue nil
              row_data << (val || '')
            end
            sheet.add_row row_data
          end
        end
      end

      uid = current_user ? "-#{current_user.id}" : nil
      temp_path = Rails.root.join('tmp', "items-#{Time.now.to_f}#{uid}.xlsx")
      xlsx.serialize temp_path
      temp_path
    end

  end
end
