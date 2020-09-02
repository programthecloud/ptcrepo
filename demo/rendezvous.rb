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
  bloom :speaker_persist do
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
  bloom :listener_persist do
    listening <= listen
  end
  bloom do
    hear <= (speak*listening).pairs(:subject=>:subject) {|s,l| [l.ident, s.subject, s.val]}
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
