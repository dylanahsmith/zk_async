require 'zk'

module ZkAsync
  autoload :Result, 'zk_async/result'
  autoload :Client, 'zk_async/client'
  autoload :Locker, 'zk_async/locker'
  autoload :VERSION, 'zk_async/version'

  def self.client=(client)
    Thread.current[:zk_async_client] = client
  end

  def self.client
    Thread.current[:zk_async_client] ||= Client.new(ZK.new)
  end
end
