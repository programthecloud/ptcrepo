# simple mapreduce
# run "ruby simple_reduce.rb localhost:23456" in one window
# run "ruby simple_reduce.rb localhost:23457" in another

require 'rubygems'
require 'bud'

module SimpleReducerMod
  state do
    channel     :shuffle, [:@addr, :key, :value]
    table       :in_channel, [:key, :value]
    scratch     :near_final, [:key] => [:value]
    scratch     :final, [:key] => [:value]
  end
  
 bloom do
    in_channel <= shuffle {|r| [r.key, r.value]}

    near_final <= in_channel.reduce({}) do |memo, t|
      memo[t.key] ||= @reducer.init(t)
      memo[t.key] = @reducer.iter(memo[t.key], t)
      memo
    end
    
    stdio <~ near_final.inspected
  end
end

class Counter
  def init(t)
    0
  end
  
  def iter(curval, t)
    curval+1
  end
  
  def final(finalval)
    finalval
  end
end

class SimpleReducer
  include Bud
  include SimpleReducerMod

  def initialize(reducer, opts)
    @reducer = reducer
    super opts
  end
end

source = ARGV[0].split(':')
ip = source[0]
port = source[1].to_i
program = SimpleReducer.new(Counter.new, :ip => ip, :port => port, :print_wiring=>true)
program.run_bg
program.sync_do
sleep 40
