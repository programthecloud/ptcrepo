require 'rubygems'
require 'bud'
require 'delivery/reliable_delivery'

module FIFODelivery
  include ReliableDelivery
  import BestEffortDelivery => :bed
  
  state do
    channel :pipe_chan, [:@dst, :src, :ident] => [:payload]
    table :que, pipe_chan.schema
    table :cnt, [:snd] => [:ct]
    scratch :mins, que.schema
    scratch :mess, que.schema
  end
  
  bloom :receive do
    que <= bed.pipe_chan
    temp :formated <= que.notin(cnt, :src => :snd)
    cnt <+ formated {|p| [p.src, 0]}
    mins <= que.argmin([:src], :ident)
    mess <= (mins * cnt).pairs(:src => :snd) {|l,r| l if l.ident == r.ct}
    pipe_chan <~ mess
	  que <- mess
    cnt <+- (cnt * mess).pairs(:snd => :src) {|l,r| [l.snd, l.ct + 1]}
  end
end
    
    