require 'rubygems'
require 'bud'
SERVER_PORT = 12345

class ChatServer
  include Bud
  
  state do
    table :nodelist
    channel :connect    
    channel :chatter
  end
  
  bloom do
    nodelist <= connect.map {|c| c.val}
    chatter <~ (chatter*nodelist).pairs do |chat,node|
      [node.key, chat.val]
    end
  end
end

server = ChatServer.new(:port=>SERVER_PORT)
server.run_fg
