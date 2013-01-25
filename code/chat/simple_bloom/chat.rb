require 'rubygems'
require 'bud'

SERVER_PORT = 12345
SERVER = 'localhost:'+SERVER_PORT.to_s

class ChatClient
  include Bud
  
  state do
    channel :connect
    channel :chatter
  end

  bootstrap do
    connect <~ [[SERVER, [ip_port, ARGV[0]]]]
  end
  
  bloom do
    chatter <~ stdio {|s| [SERVER, [ip_port, ARGV[0], s.line]]}
    stdio <~ chatter {|c| [c.val.inspect]}
  end
end

client = ChatClient.new(:stdin => $stdin)
client.run_fg
