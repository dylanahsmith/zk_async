require 'test_helper'

class LockerTest < ZkAsync::TestCase
  def setup
    super
    @root_path = "/lock"
    @shared_locker = client.shared_locker(@root_path)
    @exclusive_locker = client.exclusive_locker(@root_path)
  end

  def test_shared_lock_unlock
    locker = @shared_locker
    assert_equal true, locker.lock(:wait => false).get
    lock_path = locker.lock_path.get
    assert_match /\A\/lock\/sh\d+\z/, lock_path
    assert_equal true, client.stat(lock_path).get.exists
    locker.unlock.get
    assert_equal nil, locker.lock_path
    assert_equal ZK::Exceptions::NoNode, client.stat(lock_path).exception.class
  end

  def test_exclusive_lock_unlock
    locker = @exclusive_locker
    assert_equal true, locker.lock(:wait => false).get
    assert_match /\A\/lock\/ex\d+\z/, locker.lock_path.get
    locker.unlock.get
    assert_equal nil, locker.lock_path
  end

  def test_shared_lock_with_other_shared_lock
    lock2 = client.shared_locker(@root_path)
    lock2.lock(:wait => false).get
    assert_equal true, @shared_locker.lock(:wait => false).get
  ensure
    @shared_locker.unlock.get
    lock2.unlock.get
  end

  def test_shared_lock_returns_false_without_lock_or_wait
    @exclusive_locker.lock(:wait => false).get
    assert_equal false, @shared_locker.lock(:wait => false).get
  ensure
    @exclusive_locker.unlock.get
  end

  def test_exclusive_lock_returns_false_without_lock_or_wait
    @shared_locker.lock(:wait => false).get
    assert_equal false, @exclusive_locker.lock(:wait => false).get
  ensure
    @shared_locker.unlock.get
  end

  def test_wait_for_shared_lock
    @exclusive_locker.lock(:wait => false).get
    lock_result = @shared_locker.lock(:wait => true)
    client.set(@shared_locker.lock_path.get, 'force re-watch').get
    assert_equal false, lock_result.set?
    @exclusive_locker.unlock.get
    assert_equal true, lock_result.get
  end

  def test_wait_for_exclusive_lock
    blocking_lock = client.exclusive_locker(@root_path)
    blocking_lock.lock(:wait => false).get

    lock_result = @exclusive_locker.lock(:wait => true)
    client.set(@exclusive_locker.lock_path.get, 'force re-watch').get
    assert_equal false, lock_result.set?
    blocking_lock.unlock.get
    assert_equal true, lock_result.get
  end
end
