require 'rubygems'
require 'bud'
require 'membership/membership'
require 'multicast/multicast'
require 'counter/sequences'
require 'delivery/delivery'

module LeaderMembership
  include MembershipProtocol
  include MulticastProtocol
  include SequencesProtocol
  include DeliveryProtocol

  bootstrap do
    me <= [[ip_port]]
    leader <= me
    add_member <= me { |m| [m.address, m.address] }
  end

  state do
    table :leader, [] => [:host]
    table :me, [] => [:address]

    scratch :not_a_leader, leader.schema
    scratch :new_leader, leader.schema
    scratch :leader_vote, [:src, :address]
    scratch :unknown_leader_vote_src, leader_vote.schema
    scratch :unknown_leader_vote_addr, leader_vote.schema
    scratch :new_member, [:host]
    scratch :member_list, [:src, :members]
  end

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

  bloom :elect do
    unknown_leader_vote_src <= leader_vote.notin(member, :src => :host)
    unknown_leader_vote_addr <= leader_vote.notin(member, :address => :host)
    new_member <= unknown_leader_vote_src { |u| [u.src] }
    new_member <= unknown_leader_vote_addr { |u| [u.address] }
    add_member <= new_member { |n| [n.host, n.host] }

    not_a_leader <= leader.notin(me, :host => :address)
    new_leader <= (not_a_leader * leader_vote * leader).combos do |n, lv, l|
      if lv.address < l.host
        [lv.address]
      end
    end
    leader <+- new_leader

    increment_count <= new_leader { |n| [:mcast_msg] }
    get_count <= [[:mcast_msg]]
    mcast_send <= (return_count * new_leader).pairs do |r, n|
      if r.ident == :mcast_msg
        [r.tally, [:vote, n.host]]
      end
    end

    increment_count <= leader_vote { |l| [:unicast, l.address] }
    get_count <= leader_vote { |l| [:unicast, l.address] }
    pipe_in <= (return_count * leader_vote * leader).combos do |r, lv, l|
      if lv.address > l.host and r.ident == [:unicast, lv.address]
        [lv.src, ip_port, r.tally, [:vote, l.host]]
      end
    end
    
  end

end
