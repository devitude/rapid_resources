module RapidResources
  class Result

    class << self
      def ok(value = nil, **kw_args)
        new(true, value: value, **kw_args)
      end

      def err(error = nil, **kw_args)
        new(false, error: error, **kw_args)
      end
    end

    attr_reader :error, :value

    def initialize(ok, value: nil, error: nil, **kw_args)
      raise ArgumentError.new("Invalid argument type for `ok`, expecting boolean") unless ok.is_a?(TrueClass) || ok.is_a?(FalseClass)
      @ok = ok
      @value = value
      @error = error
      @args = kw_args.is_a?(Hash) ? kw_args.with_indifferent_access : {}
    end

    def ok?
      !!@ok
    end

    def err?
      !@ok
    end

    def arg(arg_key)
      @args[arg_key]
    end

    def [](arg_key)
      @args[arg_key]
    end

    def unwrap
      return @value if ok?
      raise ArgumentError.new("Can't unwrap Err value!")
    end

    def method_missing(method_id)
      if @args.key?(method_id)
        @args[method_id]
      else
        super
      end
    end
  end
end
