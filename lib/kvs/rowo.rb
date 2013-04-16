require 'rubygems'
require 'bud'
require 'membership/membership'
require 'kvs/kvs'
require 'kvs/quorum_kvsproto'

module ReadOneWriteOne
  include StaticMembership
  include QuorumKVSProtocol
  import BasicKVS => :kvs

  state do
    table   :qconfig, [] => [:r_fraction, :w_fraction]
    channel :kvput_chan, [:@dest, :from] + kvput.key_cols => kvput.val_cols
    channel :kvdel_chan, [:@dest, :from] + kvdel.key_cols => kvdel.val_cols
    channel :kvget_chan, [:@dest, :from] + kvget.key_cols => kvget.val_cols
    channel :kvget_response_chan, [:@dest] + kvget_response.key_cols => kvget_response.val_cols
    channel :kv_acks_chan, [:@dest, :reqid]
    scratch :chosen, [:host]
  end

  bootstrap do
    quorum_config <+ [[0, 0]]
  end

  bloom :config do
    qconfig <+ quorum_config.notin(qconfig)
  end

  bloom :routing do
    # since this is ROWO, we do unicast routing.  We let the "choose" aggregate
    # decide on the destination each tick.
    chosen <= member.group([], choose(:host))
  end

  # requests are re-routed to "chosen" destination(s)
  bloom :requests do
    kvput_chan <~ (chosen * kvput).pairs{|m,k| [m.host, ip_port] + k.to_a}
    kvdel_chan <~ (chosen * kvdel).pairs{|m,k| [m.host, ip_port] + k.to_a}
    kvget_chan <~ (chosen * kvget).pairs{|m,k| [m.host, ip_port] + k.to_a}
  end

  # receiver-side logic for re-routed requests
  bloom :receive_requests do
    kvs.kvput <= kvput_chan{|k| k.to_a.drop(2) }
    kvs.kvdel <= kvdel_chan{|k| k.to_a.drop(2) }
    kvs.kvget <= kvget_chan{|k| k.to_a.drop(2) }
    kv_acks_chan <~ kvput_chan{|k| [k.from, k.reqid] }
    kv_acks_chan <~ kvdel_chan{|k| [k.from, k.reqid] }
    kvget_response_chan <~ (kvget_chan * kvs.kvget_response).outer(:reqid => :reqid) do |c, r|
      [c.from] + r.to_a
    end
  end

  # forward responses to the original requestor node
  bloom :responses do
    kvget_response <= kvget_response_chan{|k| k.to_a.drop(1)}
    kv_acks <= kv_acks_chan {|k| [k.reqid] }
  end
end
