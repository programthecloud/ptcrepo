require 'rubygems'
require 'bud'

class Mutex_Bloom
  include Bud
  state do
    table :spot, [] => [:val]
    table :wanters, [:candidate]
    scratch :front, [] => [:candidate]
  end
  
  bloom do
    # SELECT choose(candidate) FROM wanters;
    front <= wanters.group([], choose(wanters.candidate))
    spot <+ front.notin(spot)
    wanters <- front.notin(spot)
    stdio <~ spot.inspected
  end
end

m = Mutex_Bloom.new
m.wanters << [:peter]
m.wanters << [:alexander]
m.wanters << [:alvaro]
m.tick
m.tick
m.tick
