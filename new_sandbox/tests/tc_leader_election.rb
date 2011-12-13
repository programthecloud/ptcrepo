require 'rubygems'
require 'bud'
require 'test/unit'
require 'paxos/leader_election'
require 'membership/membership'
require 'delivery/delivery'
require 'multicast/multicast'
require 'counter/sequences'

class LM
  include LeaderMembership
  include Membership
  include ReliableDelivery
  include ReliableMulticast
  include Counter
  include Bud
end

class TestLM < Test::Unit::TestCase
  def make_LMs(ports)
    ports.map do |p|
      lm = LM.new(:port => p)
      lm
    end
  end

  def test_simple
    ports = [3001, 3002, 3003]
    hosts = ports.map { |p| "127.0.0.1:#{p}" }
    lms = make_LMs(ports)
    puts "We have 3 hosts: #{hosts.inspect}"

    q = Queue.new
    10.times { q.push(true) }
    respondedp = {}

    lms.each do |lm|
      lm.add_member <+ hosts.zip(hosts)
      respondedp[lm] = false
    end

    lms.each do |lm|
      lm.run_bg
      lm.tick
    end

    lms.each do |lm|
      lm.register_callback(:leader) do |cb|
        cb.each do |row|
          if row.host == "127.0.0.1:3001" and !respondedp[lm]
            q.pop
            #respondedp[lm] = true
          end
        end
      end
    end

    while !q.empty? do
    end
  end
end
