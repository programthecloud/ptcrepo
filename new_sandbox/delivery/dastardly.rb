require 'delivery/delivery'

#randomly reorders messages, but reports success upon first send
#may delay messages up until max_delay timesteps if no other messages are sent

module DastardlyDeliveryControl
  state do
    interface input, :set_max_delay, [] => [:delay]
  end
end

module DastardlyDelivery
  include DeliveryProtocol
  include DastardlyDeliveryControl

  state do
    table :max_delay, [] => [:delay]
    table :buf, [:msg, :whenbuf]

    channel :pipe_chan, [:@dst, :src, :ident] => [:payload]

    periodic :clock, 1
  end

  bootstrap do
    max_delay <= [[5]]
  end

  bloom :control do
    max_delay <+- set_max_delay
  end

  bloom :queue do
    buf <+ pipe_in { |m| [m, @budtime] }
  end

  bloom :done do
    # Report success immediately
    pipe_sent <= pipe_in
  end

  bloom :snd do
    temp :do_send <= (buf.argagg(:choose_rand, [], :whenbuf)*max_delay).pairs do |b,d|
      if (buf.length != 1) || (@budtime - b.whenbuf >= d.delay)
        b
      end
    end

    buf <- do_send
    pipe_chan <~ do_send { |s| s.msg }
  end

  bloom :rcv do
    pipe_out <= pipe_chan
  end
end
