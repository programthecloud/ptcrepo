require 'rubygems'
require 'bud'
require 'time'
require 'membership/membership'
require 'alarm/alarm'
require 'delivery/delivery'
require 'delivery/reliable_delivery'

# @abstract HeartbeatManagerProtocol is the abstract interface for a server
# that detects heartbeats from a set of nodes.
module HeartbeatManagerProtocol
  include DeliveryProtocol
  include MembershipProtocol

  state do
    # This input takes the amount of time between hearbeats, which will be sent
    # to any members that the manager is tracking. Any module implementing this
    # must boostrap this value.
    # @param [Number] time is the amount of time between heartbeats
    interface input, :heartbeat_time, [] => [:time]

    # The heartbeat manager exports a table, updated each bud time tick, that 
    # gives the most recent heartbeat time and the most recent payload for each
    # node being tracked.
    # @param [String] node is the ip:port of this node
    # @param [Number] time is the most recent heartbeat from this node
    # @param [Object] payload is the message payload sent over the heartbeats channel
    interface output, :heartbeat_log, [:node] => [:time, :payload]
  end
end

# A basic heartbeat manager that tracks a single set of nodes.
module HeartbeatManager
  include HeartbeatManagerProtocol
  include ReliableDelivery

  state do
    table :log, heartbeat_log.schema
    table :notified, member.schema
    scratch :uninitialized, member.schema
  end

  bloom :init_heartbeat do 
    heartbeat_time <+ heartbeat_time
    uninitialized <= member.notin(notified)
    pipe_in <= (heartbeat_time * uninitialized).pairs {|h, m| [m.host, ip_port, 1, h.time]}
    notified <+ uninitialized
  end

  bloom :receive_hbeat do
    log <= pipe_out do |m|
      t = Time.now
      [m.src, t.usec, m.payload]
    end
    heartbeat_log <= log
  end
end

# A basic heartbeat client that accepts requests for heartbeats and sends back
# empty payloads at each time interval. Any class implementing this module must
# boostrap its payload value for it to function.
module HeartbeatClient
  include RecurringAlarm
  include ReliableDelivery

  state do
    table :server, [:src]
    table :payload, [] => [:payload]
  end

  bloom :setup do
    server <+ pipe_out {|m| [m.src]}
    set_alarm <= pipe_out {|m| [m.src, m.payload]}
  end

  bloom :beat do
    pipe_in <= (server * alarm * payload).combos {|m, a, p| [m.src, ip_port, 1, p.payload] if s.src == a.name}
  end
end
