require 'test_helper'

class LockerTest < ZkAsync::TestCase
  def setup
    super
    root_path = "/lock"
    @shared_locker = client.shared_locker(root_path)
    @exclusive_locker = client.exclusive_locker(root_path)
  end

  def test_shared_lock_unlock
    locker = @shared_locker
    assert_equal true, locker.lock(:wait => false).get!
    lock_path = locker.lock_path
    assert_match /\A\/lock\/sh\d+\z/, lock_path
    assert_equal true, locker.locked
    assert_equal true, client.stat(lock_path).get!.exists
    locker.unlock.get!
    assert_equal nil, locker.lock_path
    assert_equal false, locker.locked
    assert_equal false, client.stat(lock_path).get.first.exists
  end

  def test_exclusive_lock_unlock
    locker = @exclusive_locker
    assert_equal true, locker.lock(:wait => false).get!
    assert_match /\A\/lock\/ex\d+\z/, locker.lock_path
    assert_equal true, locker.locked
    locker.unlock.get!
    assert_equal nil, locker.lock_path
    assert_equal false, locker.locked
  end

  def test_shared_lock_returns_false_without_lock_or_wait
    @exclusive_locker.lock(:wait => false).get!
    assert_equal false, @shared_locker.lock(:wait => false).get!
  ensure
    @exclusive_locker.unlock.get!
  end

  def test_exclusive_lock_returns_false_without_lock_or_wait
    @shared_locker.lock(:wait => false).get!
    assert_equal false, @exclusive_locker.lock(:wait => false).get!
  ensure
    @shared_locker.unlock.get!
  end
end
