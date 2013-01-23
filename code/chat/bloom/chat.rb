require 'rubygems'
require 'bud'
require_relative 'chat_protocol'
require_relative 'chat_pretty'

class ChatClient
  include Bud
  include ChatProtocol

  def initialize(nick, server, opts={})
    @nick = nick
    @server = server
    super opts
  end
  
  bootstrap { connect <~ [[@server, [ip_port, @nick]]] }

  bloom :messages do
    chatter <~ stdio { |s| [@server, [ip_port, @nick, Time.new.strftime("%I:%M.%S"), s.line]] }
    stdio <~ chatter { |m| [pretty_print(m.val)] }
  end  
  
  bloom :disconnect do
    disconnect <~ stdio {|s| [@server, [ip_port,@nick]] if s.line == 'quit'}
    halt <= disconnect{|d| [:halt]}
    halt <= connect{|c| [:halt] if c.val[0] == "error"}
  end

  bloom :niceties do
    stdio <~ connect {|c| ["Welcome to the chat, #{c.val[1]}.  Type 'quit' to disconnect."] unless c.val[0] == "error"}
    stdio <~ connect {|c| ["Error: " + c.val[1] + ".  Exiting."] if c.val[0] == "error"}
    # stdio <~ signals {|s| [pretty_print([nil, "\nNOTICE", Time.new.strftime("%I:%M.%S"), "got SIG#{s.key}; disconnecting..."])]}
    stdio <~ disconnect {|d| ["Bye, #{d.val[1]}."]}
  end
end



server = (ARGV.length == 2) ? ARGV[1] : ChatProtocol::DEFAULT_ADDR
puts "Server address: #{server}"
program = ChatClient.new(ARGV[0], server, :stdin => $stdin, :signal_handling=>:bloom)
program.run_fg
