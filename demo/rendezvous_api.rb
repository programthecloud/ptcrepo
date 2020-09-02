module RendezvousAPI
  state {
	interface input, :speak, [:subject, :val]
  	interface input, :listen, [:ident, :subject]
  	interface output, :hear, [:hear_id, :subject, :val]
  }
end