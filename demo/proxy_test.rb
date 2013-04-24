require 'rubygems'
require 'bud'
require './rendezvous.rb'
require './proxy.rb'

class RendezvousAgent
  include Bud
  include RendezvousAtProxy
end

class SpeakerPersistProxyAgent
  include Bud
  include Proxy
end


proxy = SpeakerPersistProxyAgent.new(:port=>SERVERPORT)
proxy.run_bg

speaker = RendezvousAgent.new
speaker.run_bg
listener = RendezvousAgent.new
listener.run_bg

speaker.sync_do do |s|
  speaker.speak <+ [['fire', speaker.budtime]]
end

listener.sync_do do |l|
  listener.listen <+ [['peter', 'fire']]
end
sleep 2

