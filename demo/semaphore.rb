require 'rubygems'
require 'bud'
require './rendezvous'

class Semaphore
  include Bud
  include SynchronousRendezvous
end

l = Semaphore.new
l.speak << ["greet", "hello from tick " + l.budtime.to_s]
l.listen << ["alice", "greet"]
l.tick
puts "Finishing at clock tick " + l.budtime.to_s