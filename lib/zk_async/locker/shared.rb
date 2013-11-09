class ZkAsync::Locker::Shared < ZkAsync::Locker::Base
  LOCK_PREFIX = "sh".freeze

  def blocking_locks(lock_children)
    lower_lock_names(lock_children).select do |lock|
      lock.start_with?(ZkAsync::Locker::Exclusive::LOCK_PREFIX)
    end
  end

  def lock_prefix
    LOCK_PREFIX
  end
end
