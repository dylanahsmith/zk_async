require 'test_helper'

class ClientTest < ZkAsync::TestCase
  def test_create
    path = client.create("/foo", :ephemeral => true).get
    assert_equal "/foo", path
  end

  def test_create_with_sequence
    path = client.create("/foo", :ephemeral => true, :sequence => true).get
    assert_match /\A\/foo\d+\z/, path
  end

  def test_create_in_missing_node
    assert_equal ZK::Exceptions::NoNode, client.create("/foo/bar", :ephemeral => true).exception.class
  end

  def test_get
    client.create("/foo", :data => "hello", :ephemeral => true)
    data, stat = client.get("/foo").get
    assert_equal "hello", data
  end

  def test_set
    client.create("/foo", :data => "hello", :ephemeral => true)

    stat = client.set("/foo", "hi").get
    assert_equal 2, stat.dataLength

    data, stat2 = client.get("/foo").get
    assert_equal "hi", data
    assert_equal stat, stat2
  end

  def test_children
    client.create("/dir")
    assert_equal [], client.children("/dir").get
    client.create("/dir/foo")
    assert_equal ["foo"], client.children("/dir").get
  ensure
    client.delete("/dir")
    client.delete("/dir/foo").wait
  end

  def test_stat
    client.create("/foo", :data => 'hello', :ephemeral => true).get
    stat = client.stat("/foo").get
    assert_equal true, stat.exists
    assert_equal 5, stat.data_length
    assert_equal 0, stat.num_children
  end

  def test_stat_missing_node
    assert_equal ZK::Exceptions::NoNode, client.stat("/foo").exception.class
  end

  def test_delete
    client.create("/foo", :ephemeral => true)
    client.delete("/foo")
    assert_equal ZK::Exceptions::NoNode, client.stat("/foo").exception.class
  end

  def test_mkdir_p_
    path = "/a/b/c/d/e"
    mkdir_result = client.mkdir_p(path)
    assert_equal path, mkdir_result.get

    stat = client.stat(path).get
    assert_equal true, stat.exists
  ensure
    delete_empty_path(path)
  end

  def test_create_path
    path = "/a/b/c/d/e"
    assert_equal path, client.create_path(path, :data => "sub data", :ephemeral => true).get
    assert_equal "sub data", client.get(path).get[0]
    data, stat = client.get("/a/b/c/d").get
    assert_equal true, stat.exists
    assert_equal "", data
  ensure
    delete_empty_path(path)
  end

  def test_rm_rf
    client.create_path("/a/b/c/d/e").wait
    client.create("/a/b/c/d/f")
    client.create("/a/b/c/g")
    client.create("/a/b/h")
    client.create("/a/i")
    client.rm_rf("/a/b").get
    assert_equal ["i"], client.children("/a").get
    client.rm_rf("/a").get
    assert_equal ZK::Exceptions::NoNode, client.stat("/a").exception.class
  end

  private

  def delete_empty_path(path)
    until path == "/"
      client.delete(path)
      path = File.dirname(path)
    end
  end
end
