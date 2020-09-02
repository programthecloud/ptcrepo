require 'rubygems'
require 'bud'
require './rendezvous_api'
require './rendezvous'

module Debug
  bloom do
    stdio <~ hear.inspected
  end
end

class Synchronous
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

class Mutable
  include Bud
  include MutableSpeakerPersist
  include Debug
end

class Versioned
  include Bud
  include VersionedSpeakerPersist
  include Debug
end

l = Synchronous.new
l.speak <+ [["news", "this is the first!"]]

l.listen <+ [["peter", "news"]]
l.tick

# # uncomment me for mutable or versioned KVS
# l.speak <+ [["news", "and this is the second."]]
# l.tick

# l.listen <+ [["paul", "news"]]
# l.tick
