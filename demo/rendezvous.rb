# Synchronous Rendezvous
module SynchronousRendezvous
  include RendezvousAPI
  bloom {
    hear <= (speak*listen).pairs(:subject=>:subject) {|s,l| [l.ident, s.subject, s.val]}
  }
end

# Speaker Persists (a.k.a. Buffered Messages)
module SpeakerPersist
  include RendezvousAPI
  state {
    table :spoken, [:subject, :val]
  }
  bloom :speaker_persist {
    spoken <= speak
  }
  bloom {
    hear <= (spoken*listen).pairs(:subject=>:subject) {|s,l| [l.ident, s.subject, s.val]}
  }
end

# Listener persists (a.k.a. Subscriptions)
module ListenerPersist
  include RendezvousAPI
  state {
    table :listening, [:ident, :subject]
  }
  bloom :listener_persist {
    listening <= listen
    hear <= (speak*listening).pairs(:subject=>:subject) {|s,l| [l.ident, s.subject, s.val]}
  }
end

# Both Persist (Symmetric Join)
module BothPersist
  include RendezvousAPI
  include SpeakerPersist
  include ListenerPersist
end

module MutableSpeakerPersist
  include RendezvousAPI
  state {
    table :spoken, [:subject, :val]
  }
  bloom :persist {
    spoken <+ speak
    spoken <- (speak * spoken).rights(:subject => :subject)
    hear <= (spoken*listen).pairs(:subject=>:subject) {|s,l| [l.ident, s.subject, s.val]}
  }
end
