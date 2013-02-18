# just like lamportDelivery.rb, but by keeping a monotonically-increasing 
# log of all received events it is both (a) true to the spirit of Lamport
# clocks, and (b) fully monotonic.

require 'rubygems'
require 'bud'
require './ts_delivery'

module PureLamportDelivery
  include Bud
  include TSDeliveryProtocol
  import TSBestEffortDelivery => :bed

  state do
    lmax :cloq                 # our local Lamport clock
    lset :eventlog
  end

  bootstrap do
    # initialize clock to 0.  Current Bud version requires us
    # to use the internal constructor for an lmax (to be fixed).
    cloq <+ Bud::MaxLattice.new(0)
  end

  bloom :plumbing do
    # Wikipedia #2:
    # When a process sends a message, it includes its counter value with the message;    
    bed.pipe_in <= pipe_in {|p| [p.dst, p.src, p.ident, p.payload, cloq]}
    pipe_out <= bed.pipe_out
    pipe_sent <= bed.pipe_sent
  end

  bloom :lamport do
    # Wikipedia #1:
    # A process increments its counter before each event in that process;
    eventlog <= pipe_in {|c| [c.ident]}
    eventlog <= pipe_out {|c| [c.ident]}
    cloq <+ eventlog.size()

    # Wikipedia #3:
    # On receiving a message, the receiver process sets its counter to be 
    # greater than the maximum of its own value and the received value before 
    # it considers the message received.
    cloq <+ bed.pipe_out {|p| p.cloq}
    stdio <~ bed.pipe_in.inspected
  end
end

class Doit
  include Bud
  include PureLamportDelivery
end

alice = Doit.new(:port => 12345)
bob = Doit.new(:port => 23456)
alice.run_bg
bob.run_bg
# run the following block 3 times
(1..3).each do |i|
  alice.async_do do
    alice.pipe_in <+ [["localhost:23456", "localhost:12345", 2*i, "Bob, you're a palindrome!"]]
  end
  sleep 1
  bob.async_do do
    bob.pipe_in <+ [["localhost:12345", "localhost:23456", 2*i+1, "You can't spell malice without Alice"]]
  end
  sleep 1
end
sleep 1