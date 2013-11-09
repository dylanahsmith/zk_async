class ZkAsync::Locker::Exclusive < ZkAsync::Locker::Base
  LOCK_PREFIX = "ex".freeze

  def blocking_locks(lock_children)
    lower_lock_names(lock_children)
  end

  def lock_prefix
    LOCK_PREFIX
  end
end
