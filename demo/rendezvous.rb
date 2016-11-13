module RendezvousAPI
  state do
	  interface input, :speak, [:subject, :val]
  	interface input, :listen, [:ident, :subject]
  	interface output, :hear, [:hear_id, :subject, :val]
  end
  bloom do
  	stdio <~ hear.inspected
  end
end

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
  bloom do
    listening <= listen
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
