require './rendezvous_api'
require './rendezvous'
require './proxy_api'

HOST = '127.0.0.1'
SERVERPORT = '12345'
SERVER = HOST + ':' + SERVERPORT

module RendezvousAtServer
  include ProxyProtocol
  include RendezvousAPI
  bloom :wire_client do
    speakToServer <~ speak {|s| [SERVER] + s.to_a}
    listenToServer <~ listen {|l| [SERVER] + l.to_a}
    hear <= rcvFromServer
  end
end

module JoinServer
  include ProxyProtocol
  import SynchronousRendezvous => :sp
  # import SpeakerPersist => :sp
  # import MutableSpeakerPersist => :sp
  # import VersionedSpeakerPersist => :sp
  bloom :wire_server do
    sp.speak <= speakToServer {|s| [s.key, s.val]}
    sp.listen <= listenToServer {|f| [f.ident, f.key]}
    rcvFromServer <~ sp.hear
  end
end
