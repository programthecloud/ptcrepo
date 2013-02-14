require 'rubygems'
require 'bud'
require './ts_delivery'

module LamportDelivery
  include Bud
  include TSDeliveryProtocol
  import TSBestEffortDelivery => :bed
  
  
  state do
    lset :msglog
    lmax :cloq
  end
  
  bootstrap do
    cloq <+ Bud::MaxLattice.new(0)
  end
    
  bloom :plumbing do
    bed.pipe_in <= pipe_in
    pipe_out <= bed.pipe_out
    pipe_sent <= bed.pipe_sent
  end
    
  bloom :lamport do
    # A process increments its counter before each event in that process;
    # to do this, we'll keep track of all events: i.e., all msg idents sent or received
    msglog <= pipe_in {|p| [p.ident]}
    msglog <= pipe_out {|p| [p.ident]}
    
    cloq <= msglog.size()
    
    # On receiving a message, the receiver process sets its counter to be 
    # greater than the maximum of its own value and the received value before 
    # it considers the message received.
    cloq <+ bed.pipe_out {|p| p.cloq}
    stdio <~ pipe_out.inspected
  end
end

class Doit
  include Bud
  include LamportDelivery
end

alice = Doit.new(:port => 12345)
bob = Doit.new(:port => 23456)
alice.run_bg
bob.run_bg
(1..3).each do |i|
  alice.async_do do
    alice.pipe_in <+ [["localhost:23456", "localhost:12345", 2*i, "Bob, you're a palindrome!", alice.cloq.current_value]]
  end
  sleep 1
  bob.async_do do
    bob.pipe_in <+ [["localhost:12345", "localhost:23456", 2*i+1, "You can't spell malice without Alice", bob.cloq.current_value]]
  end
  sleep 1
end
sleep 1