module SynchronousRendezvous
  include RendezvousAPI
  bloom do
    hear <= (speak*listen).pairs(:subject=>:subject) {|s,l| [l.ident, s.subject, s.val]}
  end
end

module SpeakerPersist
  include RendezvousAPI
  state do
    # demo induction, perhaps, then undo...
    #scratch :spoken, [:subject, :val]
    table :spoken, [:subject, :val]
  end
  bloom :persist do
    spoken <= speak
    #spoken <+ spoken
  end
  bloom do
    hear <= (spoken*listen).pairs(:subject=>:subject) {|s,l| [l.ident, s.subject, s.val]}
  end
end


module ListenerPersist
  include RendezvousAPI
  state do
    table :listening, [:ident, :subject]
  end
  bloom :persist do
    listening <= listen
  end
  bloom do
    hear <= (speak*listening).pairs(:subject=>:subject) {|s,l| [l.ident, s.subject, s.val]}
  end
end

module BothPersist
  include RendezvousAPI
  state do
    table :spoken, [:subject, :val]
    table :listening, [:ident, :subject]
  end
  bloom do
    listening <= listen
    spoken <= speak
    hear <= (speak*listening).pairs(:subject=>:subject) {|s,l| 
      [l.ident, s.subject, s.val]
    }
    hear <= (listen*spoken).pairs(:subject=>:subject) {|l,s| 
      [l.ident, s.subject, s.val]
    }
  end
end

module VersionedSpeakerPersist
  include RendezvousAPI
  state do
    scratch :spoken, [:subject] => [:val]
    lmap :spoken_map
    lmax :ticker
  end

  bootstrap do
    ticker <+ Bud::MaxLattice.new(0)
  end

  bloom :persist do
    ticker <+ (ticker + 1)
    spoken_map <= speak {|s|
      {s.subject => Bud::VersionLattice.new(s.val, Bud::MaxLattice.new(ticker.reveal))}
    }
    spoken <+ spoken_map.to_collection do |k, v|
                  [k, v]
    end
  end
  bloom do
    hear <= (spoken*listen).pairs(:subject=>:subject) {|s,l| [l.ident, s.subject, s.val]}
  end
end

module MutableSpeakerPersist
  include RendezvousAPI
  state do
    table :spoken, [:subject, :val]
  end
  bloom :persist do
    spoken <+ speak
    spoken <- (speak * spoken).rights(:subject => :subject)
  end
  bloom do
    hear <= (spoken*listen).pairs(:subject=>:subject) {|s,l| [l.ident, s.subject, s.val]}
  end
end
