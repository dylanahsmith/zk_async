require 'test_helper'

class ResultTest < ZkAsync::TestCase
  class TestError < StandardError; end

  def test_set_get
    result = ZkAsync::Result.new
    result.set("all good")
    assert_equal "all good", result.get
  end

  def test_set_get_exception
    result = ZkAsync::Result.new
    exc = TestError.new("oh no")
    result.set_exception(exc)
    assert_equal true, result.set?
    assert_equal exc, result.exception
    assert_raises(TestError) do
      result.get
    end
  end

  def test_ensure
    call_count = 0
    result = ZkAsync::Result.new
    result.ensure do |value, error|
      call_count += 1
      assert_equal "hello block", value
    end
    result.set("hello block")
    assert_equal 1, call_count
  end

  def test_ensure_after_result_set
    call_count = 0
    result = ZkAsync::Result.new
    result.set("hello block")
    result.ensure do |value, error|
      call_count += 1
      assert_equal "hello block", value
    end
    assert_equal 1, call_count
  end

  def test_chain_to_result
    result2 = ZkAsync::Result.new
    result1 = ZkAsync::Result.new
    result1.chain(result2)
    assert_equal false, result2.set?
    result1.set(1)
    assert_equal true, result2.set?
    assert_equal 1, result2.get
  end

  def test_chain_with_block
    result1 = ZkAsync::Result.new
    result2 = result1.chain { |value| value + 1 }
    assert_equal false, result2.set?
    result1.set(1)
    assert_equal true, result2.set?
    assert_equal 2, result2.get
  end

  def test_chain_result_from_block
    result1 = ZkAsync::Result.new
    result2 = ZkAsync::Result.new
    result3 = result1.chain { result2 }
    result1.set(1)
    assert_equal false, result2.set?
    assert_equal false, result3.set?
    result2.set(2)
    assert_equal true, result3.set?
    assert_equal 2, result3.get
  end

  def test_chain_group_of_results
    result1 = ZkAsync::Result.new
    grouped_results = [ZkAsync::Result.new, ZkAsync::Result.new]
    result2 = result1.chain { grouped_results }
    result1.set(0)
    grouped_results[1].set(2)
    assert_equal false, result2.set?
    grouped_results[0].set(1)
    assert_equal true, result2.set?
    assert_equal [1, 2], result2.get
  end

  def test_chain_block_exception
    result1 = ZkAsync::Result.new
    result2 = result1.chain { |value| raise TestError, "bad block code" }
    assert_equal false, result2.set?
    result1.set(1)
    assert_equal true, result2.set?
    assert_raises(TestError) do
      result2.get
    end
  end

  def test_rescue
    result1 = ZkAsync::Result.new.set_exception(TestError, "oh no")
    result2 = result1.rescue(TestError)
    assert_equal nil, result2.exception
    assert_equal nil, result2.get
  end

  def test_rescue_with_block
    result1 = ZkAsync::Result.new.set_exception(TestError, "catch me")
    result2 = result1.rescue { |exception| exception.message }
    assert_equal nil, result2.exception
    assert_equal "catch me", result2.get
  end

  def test_rescue_block_exception
    result1 = ZkAsync::Result.new.set_exception(TestError, "catch me")
    result2 = result1.rescue { |exception| raise RuntimeError, "rescue fail" }
    assert_equal RuntimeError, result2.exception.class
    assert_equal "rescue fail", result2.exception.message
  end

  def test_rescue_different_exception
    result1 = ZkAsync::Result.new.set_exception(TestError, "don't catch me")
    result2 = result1.rescue(RuntimeError) do |exception|
      exception.message
    end
    assert_raises(TestError) do
      result2.get
    end
  end

  def test_wait
    result = ZkAsync::Result.new
    Thread.new do
      sleep(0.1)
      result.set("done")
    end
    assert_equal false, result.set?
    result.wait
    assert_equal true, result.set?
    assert_equal "done", result.get
  end

  def test_group
    result1 = ZkAsync::Result.new
    result2 = ZkAsync::Result.new
    group_result = ZkAsync::Result.new.group([result1, result2])
    result2.set(2)
    assert_equal false, group_result.set?
    result1.set(1)
    assert_equal true, group_result.set?
    assert_equal [1, 2], group_result.get
  end

  def test_group_with_error
    result1 = ZkAsync::Result.new
    result2 = ZkAsync::Result.new
    group_result = ZkAsync::Result.new.group([result1, result2])
    result1.set_exception(TestError, "one error")
    assert_equal false, group_result.set?
    result2.set(2)
    assert_equal true, group_result.set?
    assert_raises(TestError) do
      group_result.get
    end
  end
end
