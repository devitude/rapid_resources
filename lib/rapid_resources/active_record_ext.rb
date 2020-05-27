module RapidResources
  module ActiveRecordExt
    extend ActiveSupport::Concern

    included do
      define_callbacks :on_save

      around_save :on_around_save
      after_rollback :on_after_rollback

      validate :tests_fail_validation if Rails.env.test?

      attr_reader :required_fields
    end

    class_methods do
      def before_on_save(*cb_methods, &block)
        set_callback :on_save, :before, &block if block_given?
        set_callback :on_save, :before, *cb_methods if cb_methods.any?
      end

      def after_on_save(*cb_methods, &block)
        set_callback :on_save, :after, &block if block_given?
        set_callback :on_save, :after, *cb_methods if cb_methods.any?
      end

      def around_on_save(*cb_methods, &block)
        set_callback :on_save, :around, &block if block_given?
        set_callback :on_save, :around, *cb_methods if cb_methods.any?
      end

      def alive
        where(alive_query_params)
      end

      def build_new(attributes = {})
        new(default_new_attributes.merge(attributes))
      end

      def alive_query_params
        {}
      end

      def default_new_attributes
        {}
      end

      def ordered(column: nil, direction: nil)
        all
      end

      def required_fields_attributes(context = nil)
        {}
      end

      def additional_required_fields(context = nil)
        []
      end

      def required_fields(context = nil)
        @required_fields ||= {}
        fields_tag = context || :base
        @required_fields[fields_tag] ||= begin
          fields = []
          obj = self.new(required_fields_attributes(context))
          obj.validate(context)
          obj.errors.keys.each do |e_attribute|
            fields << e_attribute if obj.errors.added?(e_attribute, :blank)
          end
          fields.concat additional_required_fields(context)
          fields
        end
      end

      # if Rails.env.test?
      #   require 'redis'
      #   def set_fail_validation(record_id, should_fail)
      #     rr = Redis.new
      #     r_key = "#{self.name}#{record_id}"
      #     if should_fail
      #       rr.set(r_key, '1')
      #     else
      #       rr.del(r_key)
      #     end
      #   end
      # end
    end

    if Rails.env.test?
      def tests_fail_validation
        if persisted?
          rr = Redis.new
          errors.add(:base, 'forced invalid') if rr.get("#{self.class.name}#{id}") == '1'
        end
      end
    end

    def additional_error_messages
      []
    end

    def error_messages
      error_messages = []
      errors.each do |attribute, message|
        error_messages << [attribute, errors.full_message(attribute, message)]
      end

      error_messages
    end

    def save(*args, **options, &block)
      call_on_save
      with_swallow_save_excetions { super }
    end

    def save!(*args, **options, &block)
      current_swallow, Thread.current[:swallow_save_exceptions] = Thread.current[:swallow_save_exceptions], false

      call_on_save
      super
    ensure
      Thread.current[:swallow_save_exceptions] = current_swallow
    end

    def create(attributes = nil, &block)
      with_swallow_save_excetions { super }
    end

    def update(attribute)
      with_swallow_save_excetions { super }
    end

    protected

    def with_swallow_save_excetions(&block)
      do_swallow = Thread.current[:swallow_save_exceptions] == false ? false : true
      orig_swallow, @__swallow_save_exceptions = @__swallow_save_exceptions, do_swallow
      yield
    ensure
      @__swallow_save_exceptions = orig_swallow
    end

    # runs when saving object, but before any validation/saving callbacks
    def on_save
    end

    def add_not_unique_db_error(ex)
      # DETAIL:  Key (username)=(aabb)
      unique_rx = /DETAIL:\s+Key\s+\(([^\)]+)\)=/
      md = unique_rx.match(ex.message)

      uniq_error = nil
      non_uniq_attribute = md[1] if md && md.length > 1

      non_uniq_attribute = extract_not_unique_attribute_from_db(non_uniq_attribute, ex.message)
      if non_uniq_attribute && attributes.key?(non_uniq_attribute)
        uniq_error = [non_uniq_attribute.to_sym, :taken]
      else
        uniq_error = [:base, :not_unique]
      end
      uniq_error
    end

    def extract_not_unique_attribute_from_db(key, message)
      key
    end

    def on_around_save
      @save_failed = false
      @the_save_errors = []
      begin
        yield
      rescue ActiveRecord::Rollback => ex
        raise unless @__swallow_save_exceptions

        # rollback, pass the exception
        @save_failed = true
        raise
      rescue ActiveRecord::RecordNotUnique => ex
        raise unless @__swallow_save_exceptions

        uniq = add_not_unique_db_error(ex) rescue nil
        if uniq
          add_save_error(uniq[0], uniq[1])
        end
        @save_failed = true

        raise ActiveRecord::Rollback
      rescue ActiveRecord::NotNullViolation => ex
        logger.info("Non null error .... #{ex.inspect}")
        raise unless @__swallow_save_exceptions

        col_rx = /null value in column "([^"]+)"/
        if (md = col_rx.match(ex.message))
          add_save_error(md[1], :blank)
        else
          # failed to extract column, report exception
          RapidResources::Base.report_exception_proc.call(ex)
          add_save_error(:base, :error)
        end
        @save_failed = true
        # raise ActiveRecord::Rollback
        # raise
      rescue StandardError => ex
        raise unless @__swallow_save_exceptions

        # other exception
        RapidResources::Base.report_exception_proc.call(ex)

        add_save_error(:base, :error)
        @save_failed = true

        raise ActiveRecord::Rollback
      end
      !@save_failed
    end

    def on_after_rollback
      logger.info("On after rollback: #{@save_failed.inspect}")
      if @save_failed
        logger.info("On rollback, populate errors: #{@the_save_errors.inspect} - #{errors.inspect}")
        @the_save_errors.each do |k, v|
          errors.add(k, v)
        end
        @save_failed = false
        on_save_error
      end
    end

    # update record state after object has failed to save
    def on_save_error
    end

    def add_save_error(key, error)
      errors.add(key, error)
      @the_save_errors << [key, error]
    end

    def call_on_save
      run_callbacks :on_save do
        on_save
      end
    end
  end
end
