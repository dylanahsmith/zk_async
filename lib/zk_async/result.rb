class ZkAsync::Result
  attr_reader :finished

  def initialize
    @value = nil
    @error = nil
    @finished = false
    @callbacks = []
    @monitor = Monitor.new
    @wait_cond = @monitor.new_cond
  end

  def get
    wait
    [@value, @error]
  end

  def get!
    error!
    @value
  end

  def error
    wait
    @error
  end

  def error!
    raise error if error
  end

  def set(value=nil, error=nil)
    raise "result already set" if @finished
    @monitor.synchronize do
      @value = value
      @error = error
      @finished = true
      @wait_cond.signal
    end
    @callbacks.each do |callback|
      callback.call(value, error)
    end
    self
  end

  def set_error(error)
    set(nil, error)
  end

  def wait
    return if @finished
    @monitor.synchronize do
      @wait_cond.wait_until{ @finished }
    end
    nil
  end

  def on_finished(&block)
    @monitor.synchronize do
      finished = @finished
      @callbacks << block unless finished
    end
    if finished
      block.call(@value, @error)
    end
    self
  end

  def chain(result=nil, &block)
    result ||= self.class.new
    self.on_finished do |value, error|
      if block_given?
        yield value, error, result
      else
        result.set(value, error)
      end
    end
    result
  end

  def chain!(result=nil, &block)
    chain(result) do |value, error, result|
      if error
        result.set_error(error)
      else
        yield value, result
      end
    end
  end

  def group(results)
    pending = results.length
    return self.set(true, nil) if pending == 0
    first_error = nil
    callback = proc do |_, error|
      pending -= 1
      first_error ||= error
      if pending == 0
        set(!first_error, first_error)
      end
    end
    results.each do |result|
      result.on_finished(&callback)
    end
    self
  end
end
