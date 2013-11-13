class ZkAsync::Locker::Base
  attr_accessor :lock_path, :root_lock_path, :locked
  attr_reader :client

  def initialize(client, root_lock_node)
    @client = client
    @root_lock_path = root_lock_node
    @lock_path = nil
    @locked = false
  end

  def lock(options={})
    raise NotImplementedError, "Blocking locking isn't supported yet" if options[:wait] != false
    return client.result(true) if @locked
    data = options[:data] || ''
    client.create_path("#{root_lock_path}/#{lock_prefix}", :data => data, :ephemeral => true, :sequence => true).chain do |lock_path|
      @lock_path = lock_path
      client.children(root_lock_path).chain do |children|
        blocking_locks = self.blocking_locks(children)
        @locked = blocking_locks.empty?
        @locked
      end
    end
  end

  def unlock
    return client.result(false) if !@lock_path
    client.delete(@lock_path).chain do |value|
      @lock_path = nil
      @locked = false
      true
    end
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
