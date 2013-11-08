require 'minitest/autorun'
require 'zk_async'

class ZkAsync::TestCase < MiniTest::Unit::TestCase
  def zk
    @zk ||= ZK.new("localhost:2181/zk_async")
  end

  def client
    @client ||= ZkAsync::Client.new(zk)
  end

  def teardown
    @zk.close if @zk
  end
end
