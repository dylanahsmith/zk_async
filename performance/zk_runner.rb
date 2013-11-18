require 'zk_async'

class ZkRunner
  def initialize(count)
    @count = count
  end

  def prepare
    @zk = ZK.new
    @client = ZkAsync::Client.new(@zk)
  end
end

BATCH_SIZE = 1000

class SyncBatchLock < ZkRunner
  def run
    n = BATCH_SIZE * @count
    (1..n).each_slice(BATCH_SIZE) do |lock_nums|
      lockers = lock_nums.map{ |i| ZK::Locker::SharedLocker.new(@zk, "bm#{i}", "/lock") }
      lockers.each do |locker|
        locker.lock or raise "lock already taken"
      end
      lockers.each(&:unlock)
    end
  end
end

class AsyncBatchLock < ZkRunner
  def run
    n = BATCH_SIZE * @count
    (1..n).each_slice(BATCH_SIZE) do |lock_nums|
      lockers = lock_nums.map{ |i| @client.shared_locker("/lock/bm#{i}") }
      @client.result_group(lockers.map{ |locker| locker.lock(:wait => false) }).chain do |lock_paths|
        lockers.map(&:unlock)
      end.get
    end
  end
end
