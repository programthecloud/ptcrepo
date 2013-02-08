require 'rubygems'
require 'bud'
require '../../lib/delivery/delivery.rb'

module ReliableDelivery
  include DeliveryProtocol
  import BestEffortDelivery => :bedeliv
  
  state do
    table :buffer, pipe_in.schema
    periodic :tic, 0.002 # tic has a thing in it every 2 seconds
    channel :acks, [:@dst, :ident]
  end
  
  bloom :sender do
    # store
    buffer <= pipe_in
    stdio <~ pipe_in{|p| ["msg to be sent with id #{p.ident}"]}
    # send
    bedeliv.pipe_in <= pipe_in
    # retry every time tic has something in it
    bedeliv.pipe_in <= (tic*buffer).rights
    # report success and delete from buffer on ack
    temp :acked <= (acks*buffer).rights(:ident => :ident)
    pipe_sent <= acked
    buffer <- acked
    stdio <~ acked {|a| ["ack received for #{a.ident}"]}
  end
  
  bloom :receiver do
    # receive!
    pipe_out <= bedeliv.pipe_out
    # send ack
    acks <~ pipe_out { |p| [p.src, p.ident] }
  end
end
