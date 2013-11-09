class ZkAsync::Locker::Base
  attr_accessor :lock_path, :root_lock_path, :locked
  attr_reader :client

  def initialize(client, root_lock_node)
    @client = client
    @root_lock_path = root_lock_node
    @lock_path = nil
    @locked = false
  end

  def lock(options={}, &block)
    raise NotImplementedError, "Blocking locking isn't supported yet" if options[:wait] != false
    result = client.result(&block)
    if @locked
      result.set(true)
      return result
    end
    data = options[:data] || ''
    client.create_path("#{root_lock_path}/#{lock_prefix}", :data => data, :ephemeral => true, :sequence => true) do |lock_path, error|
      @lock_path = lock_path
      if error
        result.set_error(error)
      else
        client.children(root_lock_path) do |children, error|
          if error
            result.set_error(error)
          else
            blocking_locks = self.blocking_locks(children)
            @locked = blocking_locks.empty?
            result.set(@locked)
          end
        end
      end
    end
    result
  end

  def unlock(&block)
    result = client.result(&block)
    if !@lock_path
      result.set(false)
      return result
    end
    client.delete(@lock_path) do |value, error|
      unless error
        @lock_path = nil
        @locked = false
      end
      result.set(!error, error)
    end
    result
  end

  protected

  def digits_from(path)
    path[/0*(\d+)\z/, 1].to_i
  end

  def sort_lock_children(children)
    children.sort! { |a, b| digits_from(a) <=> digits_from(b) }
  end

  def lower_lock_names(children)
    sort_lock_children(children)
    lock_number = digits_from(@lock_path)
    children.select do |lock|
      digits_from(lock) < lock_number
    end
  end

  def blocking_locks
    raise NotImplementedError
  end

  def lock_prefix
    raise NotImplementedError
  end
end
