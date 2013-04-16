require 'rubygems'
require 'bud'

module QuorumKVSProtocol
  state do
    interface input, :quorum_config, [] => [:r_fraction, :w_fraction]
    interface input, :kvput, [:client, :key] => [:reqid, :value]
    interface input, :kvdel, [:key] => [:reqid]
    interface input, :kvget, [:reqid] => [:key]
    interface output, :kvget_response, [:reqid] => [:key, :value]
    interface output, :kv_acks, [:reqid]
  end
end
