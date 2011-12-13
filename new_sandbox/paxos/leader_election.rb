require 'rubygems'
require 'bud'
require 'membership/membership'
require 'multicast/multicast'
require 'counter/sequences'
require 'delivery/delivery'

# @abstract LeaderMembership is the module for Paxos leader election.
# A given node in Paxos should include this module.
module LeaderMembership
  include MembershipProtocol
  include MulticastProtocol
  include SequencesProtocol
  include DeliveryProtocol

  # Each node believes it is its own leader when it first starts up.
  bootstrap do
    me <= [[ip_port]]
    leader <= me
    add_member <= me { |m| [m.host, m.host] }
  end

  state do
    # Currently known leader
    table :leader, [] => [:host]
    # My own address
    table :me, [] => [:host]

    # Scratches for potential new leaders
    scratch :new_leader, [] => [:host]
    scratch :potential_new_leader, [:host]
    scratch :temp_new_leader, leader.schema

    # Scratches for potential new members
    scratch :potential_member, [:host]

    # Scratches to maintain if we received a leader vote message or
    # a list of members
    scratch :leader_vote, [:src, :host]
    scratch :member_list, [:src, :members]

    scratch :members_to_send, [:host]
  end

  # Each node, when receiving a message from pipe_out, needs to determine
  # the type of message. Messages are determined by the following: the
  # payload looks like [:vote, :host] or [:members, [:mem1, :mem2, ...]]
  # Because of the different types of messages, we need to demultiplex
  # the messages into the appropriate scratches.
  bloom :demux do
    leader_vote <= pipe_out do |p|
      if p.payload[0] == :vote
        [p.src, p.payload[1]]
      end
    end
    member_list <= pipe_out do |p|
      if p.payload[0] == :members
        [p.src, p.payload[1]]
      end
    end
  end

  # From leader_vote messages, add the source and the host to a scratch of
  # potential members. Those who are not in the member list should be
  # added.
  bloom :add_member do
    potential_member <= leader_vote { |u| [u.src] }
    potential_member <= leader_vote { |u| [u.host] }
    add_member <= potential_member { |n| [n.host, n.host] }
  end

  # Changes the leader under one of two conditions:
  # 1. I get a leader_vote proposing a leader with a lower host
  # 2. Another node has joined without notifying me and its host is
  # lowest in my list of members.
  bloom :change_leader do
    potential_new_leader <= (leader_vote * leader).pairs do |lv, l|
      if lv.host < l.host
        [lv.host]
      end
    end
    temp_new_leader <= member.group([:host], min(:host))
    potential_new_leader <= temp_new_leader.notin(leader, :host => :host)
    new_leader <= potential_new_leader.group([:host], min(:host))
    leader <+- new_leader
  end

  bloom :node_elect do
    increment_count <= new_leader { |n| [:mcast_msg] }
    get_count <= [[:mcast_msg]]
    temp :did_add_member <= added_member.group([], count(:ident))
    mcast_send <= (return_count * 
                   new_leader *
                   did_add_member).combos do |r, n, d|
      if r.ident == :mcast_msg
        [r.tally, [:vote, n.host]]
      end
    end

    increment_count <= leader_vote { |l| [:unicast, l.host] }
    get_count <= leader_vote { |l| [:unicast, l.host] }
    pipe_in <= (return_count * leader_vote * leader).combos do |r, lv, l|
      if lv.host > l.host and r.ident == [:unicast, lv.host]
        [lv.src, ip_port, r.tally, [:vote, l.host]]
      end
    end

    potential_member <= member_list { |m| m.members.map { |mem| [mem] } }
  end

  bloom :leader do
    members_to_send <= member { |m| [m.host] }
    increment_count <= did_add_member { |n| [:mcast_msg] }
    get_count <= [[:mcast_msg]]
    mcast_send <= (return_count * 
                   did_add_member * 
                   leader * me).combos(leader.host => 
                                       me.host) do |r, d, l, m|
      if r.ident == :mcast_msg
        [r.tally, [:members, members_to_send.flat_map]]
      end
    end
  end

end
