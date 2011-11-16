require 'rubygems'
require 'bud'

# @abstract VoteCounterProtocol is the interface for vote counting.
# A vote counting protocol should subclass VoteCounterProtocol.
module VoteCounterProtocol
  state do
    # On the client side, tell the vote counter to start counting
    # votes for a specific ballot.
    # @param [Object] ballot_id the unique id of the ballot
    # @param [Number] num_votes the number of votes that will be cast
    # (this number will remain static throughout the vote)
    interface input, :begin_vote, [:ballot_id] => [:num_votes]

    # On the client side, send votes to be counted
    # @param [Object] ballot_id the unique id of the ballot
    # @param [Object] agent agent that is casting the vote
    # @param [Object] vote specific vote
    # @param [String] note any extra information to provide along with 
    # the vote
    # TODO: Do we want to rename :vote to something less confusing?
    interface input, :cast_vote, [:ballot_id, :agent, :vote, :note]

    # Returns the result of the vote once
    # @param [Object] ballot_id the unique id of the ballot
    # @param [Symbol] status status of the vote, :success, :fail, :error
    # @param [Object] result outcome of the vote, contents depend on 
    # :vote field of cast_vote input
    # @param [Array] votes an aggregate of all of the votes cast
    # @param [Array] notes an aggregate of all of the notes sent
    interface output, :result, [:ballot_id] => [:status, :result, 
                                                :votes, :notes]
  end
end

# CountVoteCounter is an implementation of the VoteCounterProtocol in which
# a certain number of required votes for a "winning" candidate is provided 
# directly.
# @see CountVoteCounter implements VoteCounterProtocol
module CountVoteCounter
  include VoteCounterProtocol
  state do
    # On the client side, tell the vote counter how many votes are required
    # for a winning vote. Note that the ballot must already be initialized
    # via begin_vote before sending this in.
    # @param [Object] ballot_id the unique id of the ballot
    # @param [Number] num_required the number of votes required for a 
    # winning vote (ex. unanimous = number of total votes)
    interface input, :num_required, [:ballot_id] => [:num_required]

    # Table to keep track of ballots that have been initialized via
    # begin_vote, but have not had a required number of votes sent in yet.
    table :pre_ballots, begin_vote.schema

    # Table to keep track of ballots that 1) have been initialized
    # via begin_vote and 2) have the required number of votes set.
    # TODO: Include status of the ballot? (e.g. 'in-progress')
    # @param [Object] ballot_id the unique id of the ballot
    # @param [Number] num_votes see :num_votes in begin_vote
    # @param [Number] num_required number of votes required to declare a winner
    table :ongoing_ballots, [:ballot_id] => [:num_votes, :num_required]

    # _Note_: It may be the case that there are votes for ballot_ids
    # that are not yet in :ongoing_ballots, and vice versa due to
    # network delay, so this information must be stored in tables.
    # Similarly for num_required.

    # Table to hold votes received for ballots.
    table :votes, cast_vote.schema

    # Table to hold num_required received for ballots.
    table :required, num_required.schema

    # Scratch to hold summary data for a ballot, including total number
    # of votes cast, an array of those votes, and an array of notes.
    scratch :ballot_summary, [:ballot_id] => [:cnt, :votes, :notes]

    # Scratch to hold number of votes cast for each vote/response for a ballot.
    scratch :grouped_vote_counts, [:ballot_id, :vote, :cnt]

    # Scratch to hold completed ballot_ids and accumulated data.
    scratch :completed_ballots, [:ballot_id, :num_votes, :votes, :notes]

    # Scratch to hold the winning vote of a completed ballot, if one exists.
    # _Note_: There can only be one winner for a ballot. 
    # Duplicate key error will be thrown if num_required is set improperly
    # such that there can be multiple winners.
    # This constraint stems from the fact that the output interface result 
    # has [:ballot_id] as its key, indicating 
    # at most one winner per ballot_id.
    scratch :winning_vote, [:ballot_id] => [:vote]

    # TODO: We could consider supporting multiple winners by grouping them
    # together in the :result column.
  end

  # Since we have two "rounds" of initializing a ballot (one that matches
  # the VoteCounterProtocol, and that one that passes in the number of
  # required votes for a "winning" candidate), we need two tables
  bloom :add_ballot do
    # Persist the num_required inputs for each ballot
    required <= num_required

    # Beginning a ballot
    pre_ballots <= begin_vote
    ongoing_ballots <= (pre_ballots * required).pairs(:ballot_id => :ballot_id) {
      |p, r| [p.ballot_id, p.num_votes, r.num_required]     
    }

    # Clean up
    pre_ballots <- (pre_ballots * ongoing_ballots).lefts(:ballot_id => :ballot_id)
    required <- (required * ongoing_ballots).lefts(:ballot_id => :ballot_id)
  end

  # Accumulate votes (and associated notes) as they appear on :cast_vote.
  # _Note_: Logic enforcing the allowed number of votes per agent should
  # be handled before a vote is put onto :cast_vote.
  bloom :gather_votes do
    # Store incoming votes in votes table.
    votes <= cast_vote
    
    # Additional processing for usage in :process_data.
    # Summarize vote data for each :ballot_id at each timestep.
    ballot_summary <= votes.group([:ballot_id], count(:vote), 
                                  accum(:vote), accum(:note))
    
    # Calculate number of votes for each [:ballot_id, :vote] combination 
    # at each timestep.
    grouped_vote_counts <= votes.group([:ballot_id, :vote], count)
  end

  # Check for completed ballots and whether or not they have winners. A 
  # ballot is completed when the expected number of votes has been received.
  bloom :process_data do
    # Put a ballot's data into completed_ballots if the count in 
    # ballot_summary equals num_votes in ongoing_ballots for that ballot.
    completed_ballots <= (ballot_summary * ongoing_ballots).pairs(:ballot_id => :ballot_id, :cnt => :num_votes) do |s, b|
      [b.ballot_id, b.num_votes, s.votes, s.notes]
    end
    
    # Process ballots to determine there is a winner (success) or
    # not (fail), or if voting is still in progress.
    
    # Step 1: Check grouped_vote_counts for all ongoing_ballots to 
    # see if there exists a count that >= the votes needed for that ballot.
    # If there is, store it in winning_vote.
    winning_vote <= (ongoing_ballots * grouped_vote_counts).pairs(:ballot_id => :ballot_id) do |b, gc|
      # Return a winning result if we have one.
      if gc.cnt >= b.num_required
        [gc.ballot_id, gc.vote]
      end
    end

    # Step 2: For all completed ballots, return a fail response if the minimum
    # vote threshold was not met.
    result <= (completed_ballots * winning_vote).outer do |b, v|
      if b.ballot_id != v.ballot_id
        [b.ballot_id, :fail, nil, b.votes, b.notes]
      end
    end

    # Step 3: For all ballots where the vote threshold was met (completed or not),
    # return a success response.
    # _Note_: The accumulated votes/notes may not be accurate if the ballot ends
    # prematurely.
    result <= (ballot_summary * winning_vote).pairs(:ballot_id => :ballot_id) { |b, v|
        [b.ballot_id, :success, v.vote, b.votes, b.notes]
    }
    
    # Step 4: Cleanup. Remove completed ballots from tables.
    ongoing_ballots <- (ongoing_ballots * result).lefts(:ballot_id => :ballot_id)
    votes <- (votes * result).lefts(:ballot_id => :ballot_id)
  end
end


# RatioVoteCounter is an implementation of the VoteCounterProtocol in
# which a floating point ratio is provided to specify what ratio of
# the total number of votes is needed for a "winning" vote. Note: the
# calculation is rounded up, ex. votes_needed = ceil((ratio) *
# num_votes).
# @see RatioVoteCounter extends CountVoteCounter
module RatioVoteCounter
  include CountVoteCounter

  state do
    # On the client side, tell the vote counter what ratio to set. This 
    # ratio must be set before the vote starts.
    # @param [Object] ballot_id the unique id of the ballot
    # @param [Number] ratio floating point number for the percentage of 
    # votes needed for a candidate to "win"
    interface input, :ratio, [:ballot_id] => [:ratio]
  end

  bloom :ratio_delegate do
    num_required <= (ratio * pre_ballots).pairs(:ballot_id => :ballot_id) { 
      |r, b| [r.ballot_id, (r.ratio * b.num_votes).ceil]
    }
  end

end

# UnanimousVoteCounter is a specific case of RatioVoteCounter, 
# where the ratio is 1.
# @see UnanimousVoteCounter extends RatioVoteCounter
module UnanimousVoteCounter
  include RatioVoteCounter

  bloom :unanimous_delegate do
    ratio <= begin_vote {|bv| [bv.ballot_id, 1]}
  end
end

# MajorityVoteCounter is an implementation of the VoteCounterProtocol,
# where the number of votes needed for a majority is floor(0.5 *
# num_members) + 1
# @see UnanimousVoteCounter extends CountVoteCounter
module MajorityVoteCounter
  include CountVoteCounter

  bloom :majority_delegate do
    num_required <= begin_vote {|bv| [bv.ballot_id, (bv.num_votes * 0.5).floor + 1]}
  end
end
