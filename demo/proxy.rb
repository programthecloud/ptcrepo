require './rendezvous'

HOST = '127.0.0.1'
SERVERPORT = '12345'
SERVER = HOST + ':' + SERVERPORT

module ProxyProtocol
  state do
    channel :speakToProxy, [:@addr, :key, :val]
    channel :listenToProxy, [:@addr, :ident, :key]
    channel :rcvFromProxy, [:@hear_id, :key, :val]
  end
end

module RendezvousAtProxy
  include ProxyProtocol
  include RendezvousAPI
  bloom :wire_client do
    speakToProxy <~ speak {|s| [SERVER] + s.to_a}
    listenToProxy <~ listen {|l| [SERVER] + l.to_a}
    hear <= rcvFromProxy
  end
end

module Proxy
  include ProxyProtocol
  import SpeakerPersist => :sp
  #import MutableSpeakerPersist => :sp
  bloom :wire_proxy do
    sp.speak <= speakToProxy {|s| [s.key, s.val]}
    sp.listen <= listenToProxy {|f| [f.ident, f.key]}
    rcvFromProxy <~ sp.hear
  end
end
