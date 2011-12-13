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
    add_member <= me { |m| [m.host, m.host] }
  end

  state do
    table :leader, [] => [:host]
    table :me, [] => [:host]

    scratch :not_a_leader, leader.schema
    scratch :new_leader, leader.schema
    scratch :leader_vote, [:src, :host]
    scratch :new_member, [:host]
    scratch :really_new_member, new_member.schema
    scratch :member_list, [:src, :members]

    scratch :members_to_send, [:host]
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

  bloom :add_member do
    really_new_member <= new_member.notin(member, :host => :host)
    add_member <= really_new_member { |n| [n.host, n.host] }
  end

  bloom :node_elect do
    new_member <= leader_vote { |u| [u.src] }
    new_member <= leader_vote { |u| [u.host] }

    new_leader <= (leader_vote * leader).pairs do |lv, l|
      if lv.host < l.host
        [lv.host]
      end
    end
    leader <+- new_leader

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

    new_member <= member_list { |m| m.members.map { |mem| [mem] } }
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
