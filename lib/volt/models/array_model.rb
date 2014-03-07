require 'volt/models/model_wrapper'
require 'volt/models/model_helpers'
require 'volt/models/model_state'

class ArrayModel < ReactiveArray
  include ModelWrapper
  include ModelHelpers
  include ModelState

  attr_reader :parent, :path, :persistor, :options

  def initialize(array=[], options={})
    @options = options
    @parent = options[:parent]
    @path = options[:path] || []
    @persistor = setup_persistor(options[:persistor])

    array = wrap_values(array)

    super(array)

    @persistor.loaded if @persistor
  end

  # For stored items, tell the collection to load the data when it
  # is requested.
  def [](index)
    load_data
    super
  end

  def size
    load_data
    super
  end

  tag_method(:find) do
    destructive!
    pass_reactive!
  end
  def find(*args)
    if @persistor
      return @persistor.find(*args)
    else
      raise "this model's persistance layer does not support find, try using store"
    end
  end

  tag_method(:fetch) do
    destructive!
  end
  def fetch(*args, &block)
    if @persistor
      return @persistor.fetch(*args, &block)
    else
      raise "this model's persistance layer does not support fetch, try using store"
    end
  end


  def attributes
    self
  end

  # Make sure it gets wrapped
  def <<(model)
    if model.cur.is_a?(Model)
      # Set the new path
      model.cur.options = @options.merge(path: @options[:path] + [:[]])
    else
      model = wrap_values([model]).first
    end

    super(model)

    @persistor.added(model, @array.size-1) if @persistor

    return model
  end
  alias_method :append, :<<

  # Make sure it gets wrapped
  def inject(*args)
    args = wrap_values(args)
    super(*args)
  end

  # Make sure it gets wrapped
  def +(*args)
    args = wrap_values(args)
    super(*args)
  end

  def new_model(attributes, options)
    class_at_path(options[:path]).new(attributes, options)
  end

  def new_array_model(*args)
    ArrayModel.new(*args)
  end

  # Convert the model to an array all of the way down
  def to_a
    array = []
    attributes.each do |value|
      array << deep_unwrap(value)
    end

    return array
  end

  def inspect
    if @persistor && @persistor.is_a?(Persistors::ArrayStore) && state == :not_loaded
      # Show a special message letting users know it is not loaded yet.
      return "#<#{self.class.to_s}:not loaded, access with [] or size to load>"
    end

    # Otherwise inspect normally
    super
  end

  tag_method(:buffer) do
    destructive!
  end
  def buffer
    model_path = options[:path] + [:[]]
    model_klass = class_at_path(model_path)

    new_options = options.merge(path: model_path, save_to: self).reject {|k,_| k.to_sym == :persistor }
    model = model_klass.new({}, new_options)

    return ReactiveValue.new(model)
  end

  private
    # Takes the persistor if there is one and
    def setup_persistor(persistor)
      if persistor
        @persistor = persistor.new(self)
      end
    end

    # Loads data in an array store persistor when data is requested.
    def load_data
      if @persistor && @persistor.is_a?(Persistors::ArrayStore)
        @persistor.load_data
      end
    end


end
