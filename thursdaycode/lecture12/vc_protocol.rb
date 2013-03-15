require 'rubygems'
require 'bud'

module VCProtocol
  state do
    interface input, :place_vote, [:prop, :voter_id]
    interface output, :outcome, [:prop] => [:result]
  end
end

module VoteCounter
  include VCProtocol

  THRESHOLD = 1

  state do
    lmap :votes
    lmap :vote_counts
    lmap :vote_results
    lmap :winners
  end
  
  bloom do
    votes <= place_vote {|v| {v.prop => Bud::SetLattice.new([v.voter_id])}}
    vote_counts <= votes.apply(:size)
    vote_results <= vote_counts.apply(:gt_eq, THRESHOLD)
    winners <= vote_results.filter
    outcome <= winners.to_collection { |v| [v.first, "yay"] }
  end
end

class TryMe
  include Bud
  include VoteCounter
  
  bloom do
    stdio <~ outcome.inspected
  end
end

peter = TryMe.new
peter.run_bg
peter.async_do do 
  peter.place_vote <+ [[20, "bob"], [21, "mary"]] 
end
sleep 2