require 'rubygems'
require 'bud'
require 'membership/membership'
require 'kvs/kvs'

module ReadOneWriteOne
  include StaticMembership
  include KVSProtocol
  import BasicKVS => :kvs

  state do
    interface input, :quorum_config, [] => [:r_fraction, :w_fraction]
    table   :qconfig, [] => [:r_fraction, :w_fraction]
    channel :kvput_chan, [:@dest, :from]+kvput.key_cols => kvput.val_cols
    channel :kvdel_chan, [:@dest, :from]+kvdel.key_cols => kvdel.val_cols
    channel :kvget_chan, [:@dest, :from]+kvget.key_cols => kvget.val_cols
    channel :kvget_response_chan, [:@dest]+kvget_response.key_cols => kvget_response.val_cols    
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
    kvput_chan <~ (chosen*kvput).pairs{|m,k| [m.host, ip_port] + k}
    kvdel_chan <~ (chosen*kvdel).pairs{|m,k| [m.host, ip_port] + k}    
    kvget_chan <~ (chosen*kvget).pairs{|m,k| [m.host, ip_port] + k}
  end

  # receiver-side logic for re-routed requests
  bloom :receive_requests do
    kvs.kvput <= kvput_chan{|k| kvput.schema.map{|c| k.send(c)}}
    kvs.kvdel <= kvdel_chan{|k| kvdel.schema.map{|c| k.send(c)}}    
    kvs.kvget <= kvget_chan{|k| kvget.schema.map{|c| k.send(c)}}
    kvget_response_chan <~ (kvget_chan*kvs.kvget_response).outer(:reqid => :reqid) do |c, r|
      [c.from] + r
    end
  end

  # forward kvget responses to the original requestor node
  bloom :get_responses do
    kvget_response <= kvget_response_chan{|k| kvget_response.schema.map{|c| k.send(c)}}
  end  
end