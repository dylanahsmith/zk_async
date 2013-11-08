class ZkAsync::Result
  attr_reader :finished

  def initialize(&block)
    @value = nil
    @error = nil
    @finished = false
    @callbacks = block ? [block] : []
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

  def group(results, &block)
    on_finished(&block) if block_given?

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
