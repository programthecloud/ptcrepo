# Last Time: Single-site Concurrency

* Per-Agent order (calculator server): assess commutativity of operations, ensure appropriate channels
* Communication as Rendezvous: sender vs. receiver persist.  Storage is sender persist!
* Evolution of state in storage:
 * immediate update-in-place
 * deferred update-in-place (private copy)
 * version histories
* Concurrency Control over storage: 2PL

# Today
* The bigger picture: communication as rendezvous
* Distributed Commit (2PC)
* 2PL, OCC, T/O in the bigger picture

# First, an aside about Bloom and communication
* Bloom communication is done via join.  I.e. rendezvous is natural in Bloom, easy to navigate the design space.
  * e.g., modify persistence by choosing `scratch` or `table`
  * e.g. interpose middlemen into the communication
  
      ``
      out <= (senders*rcvrs).lefts(:dest=>:addr) {|s| s.payload}
      ``

      becomes
  
      ``
      proxied_senders <~ (senders*proxies).pairs(:dest=>:orig_dest) do |s,p|
        [p.orig_dest, s.payload}
      end
      out <= (proxied_senders*rcvrs).lefts(final_dest=>:addr){|p| p.payload}``
     
  * e.g., hash-partition rendezvous locations
      ``
      out <= (senders*rcvrs).lefts(:dest=>:addr) {|s| s.payload}
      ``
      
      becomes
      
      ``
      hashed_senders <~ senders {|s| [s.hash]+s}
      hashed_rcvrs <~ rcvrs {|s| [s.hash]+s}
      out <= (hashed_senders*hashed_rcvrs).lefts(:dest=>:addr) {|s| s.payload}
      ``

# Concurrency Control: Preventing or Identifying Conflicting Rendezvous
* recall R-W and W-W conflicts.  if such conflicts are acyclic, then things are serializable.
* locking avoids cycles by allowing conflicts in only one direction: lock-point order.
* alternative is to allow conflicts and "fix up" later via undo

## locking as the "antijoin antechamber"
* idea: Since communication is rendezvous, let's prevent inappropriate rendezvous -- no conflicts!
* before you can "enter" the rendezvous point:
 * check that no conflicting action is currently granted access to the rendezvous point (not-in = "antijoin").
 * if no conflict granted access, mark yourself (persistently until EOT) as having been granted access. Enter the rendezvous point to do your business
 * if conflict with the granted actions (join), wait in the antechamber
 * when granted transactions depart, choose a mutually compatible group of transactions to let into the granted group.
* some games we can play with space
 * could "move" the rendezvous point in space as above
 * could further delay rendezvous in time based on other considerations

## optimistic concurrency: antijoin with history
* go through [basic OCC](http://redbook.cs.berkeley.edu/redbook3/lec10.html)
* idea: persist read history, copy on write, and try to antijoin over time window on commit to ensure "conflicts in a particular order"
* OCC antijoin predicates are complicated -- transaction numbers, timestamps for read/write phases, read/write sets:
 * Valdating Tj.  Suppose TN(Ti) < TN(Tj).  Serializable if one of the following holds *for all uncommitted Ti* ("for all" is like anti join -- notin(NOT(foo))
   1. Ti completes writes before Tj starts reads (prevents rw and ww conflicts out of order).
   2. WS(Ti) \cap RS(Tj) = empty, Ti completes writes before Tj starts writes  (no rw conflicts in order, prevent ww conflicts out of order)
   3. WS(Ti) \cap RS(Tj) = empty, WS(Ti) \cap WS(Tj) = empty, Ti finishes read before Tj starts read (no ww conflicts, prevent backward rw conflicts).
 * GC?
 
Note: the antijoin in OCC is over all uncommitted transactions.  That means that during validation, the set of uncommitted transactions must not change. I.e. only one transactions can be validating at a time.  I.e. implicitly there's an X lock on the "validating" resource.

## timestamp ordering (T/O): streaming symmetric join of reads and writes, outputting data and aborts.
T/O.  Predeclare the schedule.  No waiting!  But restart when reordering detected...

- Keep track of r-ts and w-ts for each object: *single counter rather than full persistence.*
- reject (abort) stale reads.
- reject (abort) delayed writes to objects that have later r-ts (write was already missed).  Can allow (ignore) delayed writes to objects that have a later w-ts tho.
(Thomas Write Rule.)


Multiversion T/O: Even fewer restart scenarios

- Keep sets of r-ts, and <w-ts, value>.  This is symmetric persistence.
- Reads never rejected! (more liberal than plain T/O)
- Write rule on x: interval(W(x)) = [ts(W), mw-ts] where mw-ts is the next write after W(x) -- i.e. Min_x w-ts(x) > ts(W).  If any R-ts(x) exists in that interval, must reject write.  I.e. that read shoulda read this write.  Note more liberal than plain T/O since subsequent writes may "mask" this one for even later reads.
- GC of persistent state: anything older than Min TS of live transactions.

Note: no waiting (blocking, antijoin) in Multiversion T/O.