module RapidResources
  module PageHelpers
    module PunditHelpers
      extend ActiveSupport::Concern

      def resource_policy_class
        nil
      end

      def resource_policy_namespace
        nil
      end

      def resource_policy(record = nil)
        if record.nil?
          @resource_policy ||= if resource_policy_class
            resource_policy_class.new(current_user, model_class)
          elsif (policy_namespace = resource_policy_namespace)
            Pundit::policy!(current_user, [*policy_namespace] + [model_class])
          else
            Pundit::policy!(current_user, model_class)
          end
        elsif record.is_a?(model_class)
          # load policy for record
          if resource_policy_class
            resource_policy_class.new(current_user, record)
          elsif (policy_namespace = resource_policy_namespace)
            Pundit::policy!(current_user, [*policy_namespace] + [record])
          else
            Pundit::policy!(current_user, record)
          end
        else
          raise ArgumentError, %/Expected instance of '#{model_class}', got: '#{record.class.name}'/
        end
      end

      def resource_policy_scope(scope)
        scope_class = if resource_policy_class
          "#{resource_policy_class}::Scope"
        else
          "#{resource_policy.class}::Scope"
          # Pundit::policy_scope!(current_user, [:admin, scope])
        end
        scope_class.safe_constantize.new(current_user, scope).resolve
      end
    end
  end
end