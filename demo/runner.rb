require 'rubygems'
require 'bud'
require './rendezvous'

module Debug
  bloom do
    stdio <~ hear.inspected
  end
end

class Luck
  include Bud
  include SynchronousRendezvous
  include Debug
end

class SP
  include Bud
  include SpeakerPersist
  #include MutableSpeakerPersist
  include Debug
end


l = Luck.new
l.speak << ["hello", l.budtime]
l.listen <+ [["peter", "hello"]]

l.tick
puts l.budtime

# add me later if you get to mutable KVS
#l.speak <+ [["hello", l.budtime]]

l.listen <+ [["paul", "hello"]]
l.tick
puts l.budtime
