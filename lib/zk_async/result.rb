class ZkAsync::Result
  def initialize
    @value = nil
    @exception = nil
    @is_set = false
    @callbacks = []
    @monitor = Monitor.new
    @wait_cond = @monitor.new_cond
  end

  def get
    wait
    raise @exception if @exception
    @value
  end

  def exception
    wait
    @exception
  end

  def set(value)
    set_value_and_exception(value, nil)
  end

  def set_exception(exception, *args)
    exception = exception.new(*args) if exception.is_a?(Class)
    set_value_and_exception(nil, exception)
  end

  def set?
    @is_set
  end

  def wait
    return if @is_set
    @monitor.synchronize do
      @wait_cond.wait_until{ @is_set }
    end
    nil
  end

  def ensure(&block)
    is_set = nil
    @monitor.synchronize do
      is_set = @is_set
      @callbacks << block unless is_set
    end
    if is_set
      block.call(@value, @exception)
    end
    self
  end

  def rescue(*exception_classes, &block)
    result ||= self.class.new
    exception_classes << StandardError if exception_classes.empty?
    self.ensure do |value, exception|
      if exception && exception_classes.any?{ |exc_class| exception.kind_of?(exc_class) }
        if block_given?
          set_result_from_block(result, exception, &block)
        else
          result.set(nil)
        end
      else
        chain(result)
      end
    end
    result
  end

  def chain(result=nil, &block)
    result ||= self.class.new
    self.ensure do |value, exception|
      if block_given? && !exception
        set_result_from_block(result, value, &block)
      else
        exception ? result.set_exception(exception) : result.set(value)
      end
    end
    result
  end

  def group(results)
    pending = results.length
    return self.set([]) if pending == 0
    first_exception = nil
    callback = proc do |value, exception|
      pending -= 1
      first_exception ||= exception
      if pending == 0
        first_exception ? self.set_exception(first_exception) : self.set(results.map(&:get))
      end
    end
    results.each do |result|
      result.ensure(&callback)
    end
    self
  end

  private

  def set_value_and_exception(value, exception)
    raise "result already set" if @is_set
    @monitor.synchronize do
      @value = value
      @exception = exception
      @is_set = true
      @wait_cond.signal
    end
    @callbacks.each do |callback|
      callback.call(value, exception)
    end
    @callbacks = nil
    self
  end

  def set_result_from_block(result, *args, &block)
    begin
      ret = block.call(*args)
      if ret.is_a?(ZkAsync::Result)
        ret.chain(result) unless ret == result
      elsif ret.is_a?(Array) && ret.all?{ |item| item.is_a?(ZkAsync::Result) }
        self.class.new.group(ret).chain(result)
      else
        result.set(ret)
      end
    rescue Exception => e
      result.set_exception(e)
      raise unless e.kind_of?(StandardError)
    end
  end
end
