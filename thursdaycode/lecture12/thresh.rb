require 'rubygems'
require 'bud'

module SimpleThreshold
  THRESHOLD = 3
  
  state do
    interface input, :goodvotes, [:voter_id]
    interface output, :win, [:result]
    lset :vote_buf
  end
  
  bloom do
    vote_buf <= goodvotes
    win <= vote_buf.size.gt_eq(THRESHOLD).when_true{ [["yay!"]] }
  end
end

class TryMe
  include Bud
  include SimpleThreshold
  
  bootstrap do
    goodvotes <+ [[1],[2],[3]]
  end
  
  bloom do
    stdio <~ win.inspected
  end
end

hmm = TryMe.new
hmm.tick

