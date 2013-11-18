require 'benchmark'
require 'ruby-prof'

require_relative 'zk_runner'

RUNS = 10
RubyProf.measure_mode = RubyProf::CPU_TIME

def run(obj)
  obj.prepare
  RubyProf.start
  obj.run
  result = RubyProf.stop
  puts "Results for #{obj.class.name}:"
  printer = RubyProf::FlatPrinter.new(result)
  printer.print(STDOUT)
end

run(AsyncBatchLock.new(RUNS))

