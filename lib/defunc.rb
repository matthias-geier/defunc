
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
module Defunc

  # Private Class method
  #
  # Updates or initially sets a class variable in the
  # attached class.
  # [sym:] Class variable symbol
  # [value:] New value of the variable
  def update_variable(sym, value)
    self.class_variable_set(sym, value)
  end
  private :update_variable

  # Private Class method
  #
  # Retrieves a class variable from the attached class. If
  # the variable is not found, the default or [] is set.
  # [sym:] Class variable symbol
  # [default:] Default value if variable is not defined, default: []
  # [returns:] Value of the variable
  def get_variable(sym, default=[])
    unless self.class_variable_defined?(sym)
      self.class_variable_set(sym, default)
    end
    self.class_variable_get(sym)
  end
  private :get_variable

  # Class method
  #
  # By calling this in the class body, method symbols are set for
  # being watched and traced by the module.
  # [*args:] any number of symbols
  def watch_methods(*args)
    watch = get_variable(:@@watched_methods)
    update_variable(:@@watched_methods, watch.push(args).flatten.uniq)
  end

  # Class method
  #
  # By calling this in the class body, standard out is replaced by
  # the stream given. Every trace is being logged to the new stream.
  # [stream:] IO instance
  def set_out_stream(stream)
    update_variable(:@@out, stream)
  end

  # Instance method override
  #
  # Automatically called when a method is added to the instance body.
  # [m:] Method symbol
  def method_added(m)
    override_methods(self, self, m, instance_method(m))
  end

  # Class method override
  #
  # Automatically called when a method is added to the class body.
  # [m:] Method symbol
  def singleton_method_added(m)
    meta = class << self; self; end
    override_methods(self, meta, m, method(m))
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
    outstream = get_variable(:@@out, $stdout)

    @method_store = [] unless @method_store
    watch = get_variable(:@@watched_methods)
    return if @method_store.include?(m_name) ||
      (watch.any? && !watch.include?(m_name.to_sym))

    @method_store << m_name

    selff.send(:define_method, m_name) do |*args, &block|
      i = $indentation
      outstream.puts "#{" "*i}enter #{m_name}: #{args.inspect}"
      $indentation += 2

      m_def = m_def.bind(self) if m_def.is_a?(UnboundMethod)
      result = m_def.call(*args, &block)

      $indentation -= 2
      outstream.puts "#{" "*i}exit #{m_name}: #{result.inspect}"

      result
    end
  end

end
