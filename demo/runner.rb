require './rendezvous'

module Debug
  bloom do
    stdio <~ hear.inspected
  end
end

class Luck
  include Bud
  include SimpleRendezvous
  include Debug
end

class SP
  include Bud
  include SenderPersist
  #include Mutable
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
