require 'benchmark'

require_relative 'zk_runner'

def run(obj, bench)
  bench.report("#{obj.class.name}:") do
    obj.prepare
    obj.run
  end
end

RUNS = 10

Benchmark.bmbm do |x|
  run(AsyncBatchLock.new(RUNS), x)
  run(SyncBatchLock.new(RUNS), x)
end

