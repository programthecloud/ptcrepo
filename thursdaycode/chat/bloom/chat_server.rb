require 'rubygems'
require 'bud'
require 'chat_protocol'
require 'chat_pretty'

class ChatServer
  include Bud
  include ChatProtocol

  state do 
    table :nodelist
    scratch :connected
    scratch :disconnected
  end

  bloom :connect do
    connected <= (connect*nodelist).nopairs {|c,n| c.val if c.val[1] == n.val}.map{|c| c[1]}
    connect <~ (connect*nodelist).pairs do |c,n| 
      [c.val[0], [:error, "nickname in use"]] if c.val[1] == n.val
    end
    nodelist <+ connected
    connect <~ connected {|c| [c.key, [:connected, c.val]]}
  end

  bloom :disconnect do
    disconnected <= disconnect.payloads
    nodelist <- disconnected
    disconnect <~ disconnected do |d| 
      (nodelist.include? d) ? [d.key, [:disconnect, d.val]] : [d.key, [:error, "#{d.inspect} not connected"]]
    end
  end
  
  bloom :messages do
    chatter <~ (chatter * nodelist).pairs { |m,n| [n.key, m.val] unless n.key == m.val[0] }
  end
  
  bloom :niceties do
    stdio <~ connected {|c| [pretty_notice(c, :connected)]}
    stdio <~ disconnected{|c| [pretty_notice(c, :disconnected)]}
  end
end

# ruby command-line wrangling
addr = ARGV.first ? ARGV.first : ChatProtocol::DEFAULT_ADDR
ip, port = addr.split(":")
puts "Server address: #{ip}:#{port}"
program = ChatServer.new(:ip => ip, :port => port.to_i)
program.run_fg
