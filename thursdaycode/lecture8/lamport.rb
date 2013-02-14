require 'rubygems'
require 'bud'

class LamportClock
  include Bud
  
  state do
    scratch :to_send, [:to, :from, :payload]
    channel :chan, [:@to, :from, :payload] => [:fromctr]
    lmax :ctr
  end

  bootstrap do
    ctr <+ Bud::MaxLattice.new(0)
  end
    
  bloom do
    # A process increments its counter before each event in that process;
    ctr <+ chan {|c| ctr + 1}
    
    # When a process sends a message, it includes its counter value with the message;
    chan <~ to_send {|t| [t.to, t.from, t.payload, ctr]}
    
    # On receiving a message, the receiver process sets its counter to be 
    # greater than the maximum of its own value and the received value before 
    # it considers the message received.
    ctr <+ chan {|c| c.fromctr + 1}
    stdio <~ chan.inspected
  end
end

p = LamportClock.new(:port => 1234)
p.tick
p.to_send <+ [['localhost:1234', 'localhost:2345', "zero"]]
p.tick
p.tick
p.to_send <+ [['localhost:1234', 'localhost:2345', "one"]]
p.tick
p.tick
p.tick
p.tick
p.tick
