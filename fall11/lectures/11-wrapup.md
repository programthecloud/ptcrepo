# Bloom Feedback

- Break into groups. Each group to come up with 2 "critiques" and 2 "WIBNIs" (Wouldn't It Be Nice If…)  To help, go back to project code and read it through for the parts that felt awkward. Try to construct code samples for these 4.  Prioritize 

Examples:

    # Critique: missing if/else construct.
    
    out1 <= inny {|i| i if i.c < 4 and i.d > 2}
    out2 <= inny {|i| i if i.c>=4 or i.d <=2}

    # WIBNI there was operator autocomplete in an editor 
    # (e.g. <~ when channel on lhs)

Discuss top critique from each group, then top WIBNI from each group.  Then any remaining.

- Go round again, ask for reflection on common sources of Bloom code bugs and how to debug them.  Examples if at all possible.

# Bloom Lessons to live by
What have we learned that you can take away into other languages?

  - All state uniformly treated as disorderly collections of data.
    - Remember: no distinction between variables and data in Bloom
    - all in *collections*, so reorderable, partitionable by default.
    - Example: filesystem metadata in KVS.  
    - Partition?  yes
    - Replicate?  Multi-master? yes.
      - No real difference between replicated *state* and replicated *processes*!
      - Note that caching is a form of (partial) replication.
    - Can you do this in a traditional PL?  Sure you can!
  
  - Space-Time Rendezvous as a key construct:
    - Remember
      - sender-persist, receiver-persist, both-persist
      - storage is implicit sender-persist communication.  "Implicitness" often leads to rigid thinking
        - always think of concurrency/consistency issues w.r.t. communication ordering!
    - Uses
      - data joins: table/table rendezvous
      - msg handlers = channel/table rendezvous
      - timeout logic = periodic/table rendezvous
      - heartbeats = periodic/table rendezvous
    - Manipulating the rendezvous of 2 scratches (channels, periodics)
      - example: request/response pattern
      - persisting one scratch, the other scratch, or both
      - when to "garbage collect" the persisted data?
	- When do you *need* time? (<+ or <~)
	  - asynchronous tasks (<~)
	  - non-monotonicity (esp. with cycles -- recursion):
	
	<code>kvs <+- (del_msg*kvs).rights(:key=>:key)</code>
		
    - Understanding rendezvous makes it easy to switching between traditional programming metaphors
      - storage vs. communication: e.g. shared memory vs. "IPC".
      - sync vs. async: e.g. function call vs. RPC
      - state "at endpoints", "at proxies", "stateless" (carried in packets)
      - can you apply state-as-data tricks uniformly across these metaphors?  I think so!
    - What of this can you take away into other languages?
      - lightweight event handlers instead of threads: not so hard?
      - stream query implementation: not so hard?
    
  - monotonicity analysis (CALM)
    - monotonic code is eventually consistent
      - set accumulation
      - increment integers
    - beware of non-monotonicity downstream of asychrony.
	  - delete, replace, set minus
	  - aggregation 
		- though sometimes you can convince yourself it's monotonic, e.g. (ints, +, max, <)
    - non-monotonicity, when guarded by coordination, becomes eventually consistent!
		- what kind of coordination will control the reordering you worry about?
			- global atomic broadcast?
			- FIFO point-to-point channels?
			- actions vs. transactions?
	- remember our 2 shopping carts
		- even though we didn't avoid coordination, the disorderly cart *moved* it to a less frequent dataflow transition (checkout).
	- can you think about this in a traditional PL?  Yes! (Though it's up to you to prove and maintain.)
	
# Some stuff that's hiding (or should be) in the Bloom runtime
  - Making this high-level language work requires two things
    - fast single-node stream-query (relational) processing
      - network event handler
      - indexes, pipelined/symmetric hash-joins and hash-groups
      - Bud has a long way to go on this front!
        - but we know what to do
    - sophisticated "query optimizer"
      - e.g. rewrite programs to only populate collections as needed ("magic sets")
      - e.g. rewrite programs to share common sub-expressions across rules
      - e.g. choose orders of operation for stuff like multi-way joins
      - e.g. intelligently "garbage collect" persisted tuples that can no longer join with anything
      - Again, Bud has a long way to go on this front!
        - we know how to do some of this
        - we know how to build a nice framework for this
        - there will be research!
        
# If you like this stuff:
  - please keep using it!  
    - even if your job requires another lang, Bloom is great for design/prototype
  - we'd love your continuing feedback
    - don't be shy with criticism!
  - you may want to do research
    - stay in touch!
  - you may want to work in distributed systems and/or big data and/or PL.
    - stay in touch!

# Thank you and congratulations!

  - You are the best Bloom programmers in the world.  
  - You are enlightened distributed system designers.  
  - We salute you.

    
      