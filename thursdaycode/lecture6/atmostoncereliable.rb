require 'rubygems'
require 'bud'
require './reliable'

module Amoalord
  include DeliveryProtocol
  import ReliableDelivery => :rd

  state do
    table :buffer, [:ident]
  end

  bloom :plumbing do
    rd.pipe_in <= pipe_in
    pipe_sent <= rd.pipe_sent
  end
  
  bloom :receiver do
    pipe_out <= rd.pipe_out.notin(buffer, :ident => :ident)
    buffer <+ rd.pipe_out { |p| [p.ident] }
    stdio <~ pipe_out {|p| ["msg rcvd: #{p.inspect}"]}
  end
end


class Doit
  include Bud
  include Amoalord
end

alice = Doit.new(:port => 12345)
bob = Doit.new(:port => 23456)
alice.run_bg
bob.run_bg
alice.async_do do
  alice.pipe_in <+ [["localhost:23456", "localhost:12345", 1, "BUY FACEBOOK"]]
end
sleep 2