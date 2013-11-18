class ZkAsync::Locker::Base
  attr_accessor :lock_path, :root_lock_path
  attr_reader :client

  def initialize(client, root_lock_node)
    @client = client
    @root_lock_path = root_lock_node
    @lock_path = nil
  end

  def lock(options={})
    raise ArgumentError, ":wait option required" unless options.key?(:wait)

    data = options[:data] || ''
    @lock_path ||= client.create_path("#{root_lock_path}/#{lock_prefix}", :data => data, :ephemeral => true, :sequence => true)

    @lock_path.chain { locked_check(ZkAsync::Result.new, options) }
  end

  def unlock
    return client.result(true) unless @lock_path
    @lock_path.chain do |lock_path|
      client.delete(lock_path)
    end.chain do
      @lock_path = nil
      true
    end
  end

  protected

  def locked_check(result, options)
    client.children(root_lock_path).chain(result) do |children|
      raise ZkAsync::Locker::LostLockError unless children.include?(File.basename(@lock_path.get))
      blocking_locks = self.blocking_locks(children)
      locked = blocking_locks.empty?
      if !locked && options[:wait]
        client.wait_until_deleted("#{root_lock_path}/#{blocking_locks.last}").chain(result) do
          locked_check(result, options)
        end
      else
        locked
      end
    end
  end

  def digits_from(path)
    path[/0*(\d+)\z/, 1].to_i
  end

  def sort_lock_children(children)
    children.sort! { |a, b| digits_from(a) <=> digits_from(b) }
  end

  def lower_lock_names(children)
    sort_lock_children(children)
    lock_number = digits_from(@lock_path.get)
    children.select do |lock|
      digits_from(lock) < lock_number
    end
  end

  def blocking_locks(children)
    raise NotImplementedError
  end

  def lock_prefix
    raise NotImplementedError
  end
end
