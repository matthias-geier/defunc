
# = Defunc Module
#
# Defunc is a tracing module which is plugged into a
# class to trace entering, exiting and respective values
# to a specified stream.
#
# == Usage
#
#   class Random
#     extend Defunc
#
#     def self.random
#       5
#     end
#   end
#
# This scenario will trace a call Random.random() to
# standard out and show you the empty argument array []
# and the returned value 5.
#
#   class Random
#     extend Defunc
#
#     watch_methods :initialize, :random
#     set_out_stream File.open("path/to/file", "w")
#
#   end
#
# Defunc offers two methods for class definitions to
# control the watched methods (this includes class
# and instance methods alike) and the stream it logs
# to. set_out_stream accepts any IO instance that has
# :puts defined.
#
# The IO instance is class-based and so is watch_methods.
# You can extend your super-class (like a base model)
# and have all deriving models enable tracing by that.
#
#
#
$object_ids = {}
$object_id_count = []
$outstream = $stdout
$threshold = 120
$trace_all = false
$method_store = {}

class BasicObject

  class << self

    alias saving_new new

    def new(*args, &block)
      result = saving_new(*args, &block)
      unless $object_id_count.include?(result.object_id)
        $object_id_count << result.object_id
      end
      if self.name.split('::').include?("RubyToken") or
          $object_ids[result.object_id]
        return result
      end
      $object_ids[result.object_id] = Time.now
      ObjectSpace.define_finalizer(result, self.method(:finalize).to_proc)
      result
    end

    def finalize(id)
      $object_id_count.delete(id)
      t = $object_ids[id]
      if t and Time.now - t > $threshold
        $outstream.puts "Collecting #{self} with id #{id} which stayed " +
          "in memory for #{Time.now - t}s"
      end
      $object_ids.delete(id)
    end

    # Private Class method
    #
    # Updates or initially sets a class variable in the
    # attached class.
    # [sym:] Class variable symbol
    # [value:] New value of the variable
    def update_variable(sym, value)
      self.class_variable_set(sym, value)
    end
    protected :update_variable

    # Private Class method
    #
    # Retrieves a class variable from the attached class. If
    # the variable is not found, the default or [] is set.
    # [sym:] Class variable symbol
    # [default:] Default value if variable is not defined, default: {}
    # [returns:] Value of the variable
    def get_variable(sym, default={:singleton => [], :instance => []})
      unless self.class_variable_defined?(sym)
        self.class_variable_set(sym, default)
      end
      self.class_variable_get(sym)
    end
    protected :get_variable

    # Class method
    #
    # By calling this in the class body, method symbols are set for
    # being watched and traced by the module.
    # [*args:] any number of symbols
    def watch_methods(*args)
      watch = get_variable(:@@watched_methods)
      args.each do |m|
        if "#{self.name}".empty?
          # singleton scope
          watch[:singleton] << m
        else
          # instance scope
          watch[:instance] << m
        end
      end
      update_variable(:@@watched_methods, watch)
    end

    # Class method
    #
    # Is called from both method added overrides and wraps the method
    # call with trace messages.
    # [klass:] Class
    # [selff:] Reference for method override
    # [m_name:] Method symbol
    # [m_def:] Method reference
    def override_methods(klass, selff, m_name, m_def)
      $indentation = 0 unless $indentation

      $method_store[selff.to_s] ||= {:singleton => [], :instance => []}
      watch = get_variable(:@@watched_methods)
      scope = klass == selff ? :instance : :singleton
      return if $method_store[selff.to_s][scope].include?(m_name) ||
        (watch[scope].any? && !watch[scope].include?(m_name.to_sym)) ||
        (watch[scope].empty? && !$trace_all) || m_name =~ /bind/i

      $method_store[selff.to_s][scope] << m_name

      selff.send(:define_method, m_name) do |*args, &block|
        i = $indentation
        item_count = $object_id_count.count
        $outstream.puts(
          "#{" "*i}enter #{klass.name}##{m_name}: #{args.inspect}")
        $indentation += 2

        p self.send(:binding)
        p selff.to_s
        p $method_store[selff.to_s][scope]
        if m_def.is_a?(UnboundMethod)
          puts "Binding #{m_name}"
          m_def = m_def.bind(self)
        end
        result = m_def.call(*args, &block)

        $indentation -= 2
        item_diff = $object_id_count.count - item_count
        $outstream.puts("#{" "*i}exit #{klass}##{m_name}: #{result.inspect}\
 (object count has changed by %+d)" % [item_diff])

        result
      end
    end

    # Instance method override
    #
    # Automatically called when a method is added to the instance body.
    # [m:] Method symbol
    def method_added(m)
      self.override_methods(self, self, m, instance_method(m))
    end

    # Class method override
    #
    # Automatically called when a method is added to the class body.
    # [m:] Method symbol
    def singleton_method_added(m)
      return if m == :singleton_method_added
      meta = class << self; self; end
      override_methods(self, meta, m, method(m))
    end

  end

end

