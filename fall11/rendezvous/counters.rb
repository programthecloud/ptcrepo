require 'rubygems'
require 'bud'

class TheCount #Blühhhhh
  include Bud
  
  state do 
    table :counter, [:value]
    scratch :tickle_me_elmo, [] => [:value]
  end
  
  bootstrap do
    counter << [0]
  end
  
  bloom do
    stdio <~ counter {|f| ["at #{budtime}, f is #{f.inspect}"]}
    # stdio <~ counter {|f| ["at #{budtime}, tickle_me_#{tickle_me_elmo.first.inspect}"]}

    # replace is done by insert and delete
    counter <+- (counter * tickle_me_elmo).pairs {|c, t| [c.value+1]}
  end
end

countie = TheCount.new
10.times {countie.tick}
countie.tickle_me_elmo <+ [[:amber]]
countie.tick
countie.tickle_me_elmo <+ [[:amber]]
countie.tick
countie.tick
countie.tickle_me_elmo <+ [[:amber]]
countie.tick
