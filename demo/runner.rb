require 'rubygems'
require 'colorize'
require 'bud'
require './rendezvous_api'
require './rendezvous'

module Debug
  bloom do
    stdio <~ hear {|h| ["hear: #{h}".white]}
    stdio <~ listen {|l| ["listen: #{l}".blue]}
    stdio <~ speak {|s| ["speak: #{s}".red]}
  end
end

class Sync
  include Bud
  include SynchronousRendezvous
  include Debug
end

class SP
  include Bud
  include SpeakerPersist
  include Debug
end

class LP
  include Bud
  include ListenerPersist
  include Debug
end

class Both
  include Bud
  include BothPersist
  include Debug
end

class MSPBoth
  include Bud
  include MutableSpeakerPersist
  include ListenerPersist
  include Debug
end  


l = Sync.new
l.run_bg()

puts "tick #{l.budtime}: speak and wei listens"
l.sync_do{ 
  l.speak <+ [["#mountain", "1st msg sent at time #{l.budtime}"]]
  l.listen <+ [["wei", "#mountain"]]
}

puts "tick #{l.budtime}: ashima listens"
l.sync_do{
  l.listen <+ [["ashima", "#mountain"]]
}

puts "tick #{l.budtime}: speak"
l.sync_do{
  l.speak <+ [["#mountain", "next msg sent at time #{l.budtime+1}"]]
}