require 'rubygems'
require 'bud'
require './rendezvous_api.rb'
require './rendezvous.rb'
require './proxy.rb'

class RendezvousAgent
  include Bud
  include RendezvousAtServer
end

class SpeakerPersistServer
  include Bud
  include JoinServer
end


server = SpeakerPersistServer.new(:port=>SERVERPORT)
server.run_bg

speaker = RendezvousAgent.new
speaker.run_bg
listener = RendezvousAgent.new
listener.run_bg

speaker.sync_do do |s|
  speaker.speak <+ [['greet', "Hello from " + speaker.port.to_s + ' at tick ' + speaker.budtime.to_s]]
end

listener.sync_do do |l|
  listener.listen <+ [['alice', 'greet']]
end
sleep 2

