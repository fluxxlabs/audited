module Audited
  module RspecMatchers
    # Ensure that the model is audited.
    #
    # Options:
    # * <tt>only</tt> - tests that the audit makes use of the only option *Overrides <tt>except</tt> option*
    # * <tt>except</tt> - tests that the audit makes use of the except option
    # * <tt>requires_comment</tt> - if specified, then the audit must require comments through the <tt>audit_comment</tt> attribute
    # * <tt>on</tt> - tests that the audit makes use of the on option with specified parameters
    #
    # Example:
    #   it { should be_audited }
    #   it { should be_audited.only(:field_name) }
    #   it { should be_audited.except(:password) }
    #   it { should be_audited.requires_comment }
    #
    def be_audited
      AuditMatcher.new
    end

    class AuditMatcher # :nodoc:
      def initialize
        @options = {}
      end

      def only(*fields)
        @options[:only] = fields.flatten
        self
      end

      def except(*fields)
        @options[:except] = fields.flatten
        self
      end

      def requires_comment
        @options[:comment_required] = true
        self
      end

      def on(*actions)
        @options[:on] = actions.flatten
        self
      end

      def matches?(subject)
        @subject = subject
        auditing_enabled? &&
          records_changes_to_specified_fields? &&
          comment_required_valid?
      end

      def failure_message
        "Expected #{@expectation}"
      end

      def negative_failure_message
        "Did not expect #{@expectation}"
      end

      def description
        description = "audited"
        description += " only => #{@options[:only].join ', '}"          if @options.key?(:only)
        description += " except => #{@options[:except].join(', ')}"     if @options.key?(:except)
        description += " requires audit_comment"                        if @options.key?(:comment_required)

        description
      end

      protected

      def expects(message)
        @expectation = message
      end

      def auditing_enabled?
        expects "#{model_class} to be audited"
        model_class.respond_to?(:auditing_enabled) && model_class.auditing_enabled
      end

      def model_class
        @subject.class
      end

      def records_changes_to_specified_fields?
        if @options[:only] || @options[:except]
          if @options[:only]
            except = model_class.column_names - @options[:only].map(&:to_s)
          else
            except = model_class.default_ignored_attributes + Audited.ignored_attributes
            except |= @options[:except].collect(&:to_s) if @options[:except]
          end

          expects "non audited columns (#{model_class.non_audited_columns.inspect}) to match (#{expect})"
          model_class.non_audited_columns =~ except
        else
          true
        end
      end

      def comment_required_valid?
        if @options[:comment_required]
          @subject.audit_comment = nil

          expects "to be invalid when audit_comment is not specified"
          @subject.valid? == false && @subject.errors.key?(:audit_comment)
        else
          true
        end
      end
    end
  end
end
