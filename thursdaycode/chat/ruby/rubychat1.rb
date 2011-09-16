# taken from http://www.rubyinside.com/advent2006/10-gserver.html
require 'gserver'

class ChatServer < GServer
  def initialize(*args)
    super(*args)
    
    # Keep an overall record of the client IDs allocated
    # and the lines of chat
    @@client_id = 0
    @@chat = []
  end
  
  def serve(io)
    # Increment the client ID so each client gets a unique ID
    @@client_id += 1
    my_client_id = @@client_id
    my_position = @@chat.size
    
    io.puts("Welcome to the chat, client #{@@client_id}!")
    
    # Leave a message on the chat queue to signify this client
    # has joined the chat
    @@chat << [my_client_id, ""]
    
    loop do 
      # Every 5 seconds check to see if we are receiving any data 
      if IO.select([io], nil, nil, 5)
        # If so, retrieve the data and process it..
        line = io.gets

        # If the user says 'quit', disconnect them
        if line =~ /quit/
          @@chat << [my_client_id, ""]
          break
        end

        # Shut down the server if we hear 'shutdown'
        self.stop if line =~ /shutdown/

        # Add the client's text to the chat array along with the
        # client's ID
        @@chat << [my_client_id, line]      
      else
        # No data, so print any new lines from the chat stream
        @@chat[my_position..-1].each_with_index do |line, index|
          io.puts("#{line[0]} says: #{line[1]}")
        end
        
        # Move the position to one past the end of the array
        my_position = @@chat.size
      end
    end
    
  end
end

server = ChatServer.new(1234)
server.start

loop do
  break if server.stopped?
end

puts "Server has been terminated"