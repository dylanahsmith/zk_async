require 'test_helper'

class ClientTest < ZkAsync::TestCase
  def test_create
    path = client.create("/foo", :ephemeral => true).get!
    assert_equal "/foo", path
  end

  def test_create_with_sequence
    path = client.create("/foo", :ephemeral => true, :sequence => true).get!
    assert_match /\A\/foo\d+\z/, path
  end

  def test_create_in_missing_node
    assert_equal ZK::Exceptions::NoNode, client.create("/foo/bar", :ephemeral => true).error
  end

  def test_get
    client.create("/foo", :data => "hello", :ephemeral => true)
    data, stat = client.get("/foo").get!
    assert_equal "hello", data
  end

  def test_set
    client.create("/foo", :data => "hello", :ephemeral => true)

    stat = client.set("/foo", "hi").get!
    assert_equal 2, stat.dataLength

    data, stat2 = client.get("/foo").get!
    assert_equal "hi", data
    assert_equal stat, stat2
  end

  def test_children
    assert_equal [], client.children("/").get!
    client.create("/foo", :ephemeral => true)
    assert_equal ["foo"], client.children("/").get!
  end

  def test_stat
    client.create("/foo", :data => 'hello', :ephemeral => true).get!
    stat = client.stat("/foo").get!
    assert_equal true, stat.exists
    assert_equal 5, stat.data_length
    assert_equal 0, stat.num_children
  end

  def test_stat_missing_node
    stat, error = client.stat("/foo").get
    assert_equal false, stat.exists
    assert_equal ZK::Exceptions::NoNode, error
  end

  def test_delete
    client.create("/foo", :ephemeral => true)
    client.delete("/foo")
    assert_equal ZK::Exceptions::NoNode, client.stat("/foo").error
  end
end
