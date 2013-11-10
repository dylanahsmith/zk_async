require 'test_helper'

class ResultTest < ZkAsync::TestCase
  def test_set_get
    result = ZkAsync::Result.new
    result.set("all good")
    assert_equal "all good", result.get!
  end

  def test_set_get_error
    result = ZkAsync::Result.new
    exc = RuntimeError.new("oh no")
    result.set(0, exc)
    assert_equal [0, exc], result.get
    assert_equal exc, result.error
  end

  def test_get_bang_raises_on_error
    result = ZkAsync::Result.new
    exc = RuntimeError.new("oh no")
    result.set_error(exc)
    begin
      result.get!
      flunk
    rescue RuntimeError => e
      assert_equal "oh no", e.message
    end
  end

  def test_on_finished
    call_count = 0
    result = ZkAsync::Result.new
    result.on_finished do |value, error|
      call_count += 1
      assert_equal "hello block", value
    end
    result.set("hello block")
    assert_equal 1, call_count
  end

  def test_on_finished_after_result_set
    call_count = 0
    result = ZkAsync::Result.new
    result.set("hello block")
    result.on_finished do |value, error|
      call_count += 1
      assert_equal "hello block", value
    end
    assert_equal 1, call_count
  end

  def test_chain_to_new_result
    result1 = ZkAsync::Result.new
    result2 = result1.chain do |value, error, result|
      result.set(value + 1)
    end
    assert_equal false, result2.finished
    result1.set(1)
    assert_equal true, result2.finished
    assert_equal 2, result2.get!
  end

  def test_chain_to_existing_result
    result2 = ZkAsync::Result.new
    result1 = ZkAsync::Result.new
    result1.chain(result2)
    assert_equal false, result2.finished
    result1.set(1)
    assert_equal true, result2.finished
    assert_equal 1, result2.get!
  end

  def test_chain_to_existing_result_with_block
    result1 = ZkAsync::Result.new
    result2 = ZkAsync::Result.new
    result1.chain(result2) do |value, error|
      result2.set(value + 1, error)
    end
    assert_equal false, result2.finished
    result1.set(1)
    assert_equal true, result2.finished
    assert_equal 2, result2.get!
  end

  def test_wait
    result = ZkAsync::Result.new
    Thread.new do
      sleep(0.1)
      result.set("done")
    end
    assert_equal false, result.finished
    result.wait
    assert_equal true, result.finished
    assert_equal "done", result.get!
  end

  def test_group
    result1 = ZkAsync::Result.new
    result2 = ZkAsync::Result.new
    group_result = ZkAsync::Result.new.group([result1, result2])
    result2.set(2)
    assert_equal false, group_result.finished
    result1.set(1)
    assert_equal true, group_result.finished
    assert_equal true, group_result.get!
  end

  def test_group_with_error
    result1 = ZkAsync::Result.new
    result2 = ZkAsync::Result.new
    group_result = ZkAsync::Result.new.group([result1, result2])
    exc = RuntimeError.new("one error")
    result1.set(1, exc)
    assert_equal false, group_result.finished
    result2.set(2)
    assert_equal true, group_result.finished
    assert_equal [false, exc], group_result.get
  end
end
