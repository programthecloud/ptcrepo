# Review: Operations on State
Recall our discussion from 2 weeks ago:

* Communication as Rendezvous: sender vs. receiver persist.  Storage is sender persist!
* Evolution of state in storage:
 * immediate update-in-place
 * deferred update-in-place (private copy)
 * version histories
 
A traditional approach

1. What are the operations on state?
2. What orders matter for these operations?  
    * Definitions of orders: [Schedules/Histories](http://en.wikipedia.org/wiki/Schedule_(computer_science)
3. Various traditional definitions of acceptable orderings: 
    * [sequential consistency](http://en.wikipedia.org/wiki/Sequential_consistency)
    * [linearizability](http://en.wikipedia.org/wiki/Linearizability)
    * [serializability](http://en.wikipedia.org/wiki/Serializability)
    * [more...](http://en.wikipedia.org/wiki/Consistency_model)
4. Conflicts.  Assume two clients, one server.  What interleavings of operations do not preserve client views?  
    * R-W and W-W conflicts.
    * Can you imagine more refined notions of "conflict"?
5. Approaches to conflicts
  * Atomicity/exclusion.  2-Phase Locking (2PL).  [CS186 Notes](https://sites.google.com/a/cs.berkeley.edu/cs186-s12/lecture-notes/18-xact-CC.6up.pdf)
  * Copies.  Optimistic Concurrency Control (OCC). (More below)
  * Histories.  Timestamp and Multiversion CC (MVCC). (More below)

Some less-traditional questions to ponder:

1. What if communication is explicit, rather than implicit through storage?
2. Is read/write memory "the right data structure"?  What alternatives do we have?
3. What are some other reasonable orderings besides the traditional ones above?


# Today
* 2PL, OCC, T/O in the bigger picture

## 2PL: The Antijoin Antichamber
* idea: Since communication is rendezvous, let's prevent "inappropriate" rendezvous -- no conflicts!
    * a transaction is like a "team" or a "power"
    * a database record is like a rendezvous "location"
    * certain agents (actions) across "teams" are *conflicts*
* before an agent can "enter" the rendezvous point:
 * check that no conflicting agent is currently granted access to the rendezvous point (not-in = "antijoin").
 * if no conflicting agent granted access, mark yourself (persistently until EOT) as having been granted access. Enter the rendezvous point to do your business
 * if conflict with the granted agents (join), wait in the antechamber
 * when granted transactions depart, choose a mutually compatible group of agents to let into the rendezvous point
* Note that space (distribution) is irrelevant
 * could "move" the rendezvous point in space as long as everyone can find it
 * very easy to do this in Bloom
 
## Optimistic Concurrency Control: antijoin with history
* You can read up on [basic OCC here](05-occ-notes.md) (Wikipedia entry is poor -- fix it!)
* the big idea: persist read history, copy on write, and (try to) antijoin conflicts in time window to ensure commits preserve "conflicts in a particular order"
* OCC antijoin predicates are complicated -- transaction numbers, timestamps for read/write phases, read/write sets:
* Valdating Tj.  Suppose TN(Ti) < TN(Tj).  Serializable if one of the following holds *for all uncommitted Ti* ("for all" is like anti join -- notin(NOT(foo))
     1. **Condition 1**: Ti completes its write phase before Tj starts its read phase. *(no out-of-order conflicts)*
     2. **Condition 2**: WS(Ti) &cap; RS(Tj) = &empty; and Ti completes its write phase before Tj starts its write phase. 
        * No Wi-Rj conflicts since WS(Ti) &cap; RS(Tj) = &empty;
        * In all Ri-Wj conflicts, Ti precedes Tj, since the write phase (and hence the read phase) of Ti precedes that of Tj.
        * In all W-W conflicts, Ti precedes Tj by assumption.
     3. **Condition 3**: WS(Ti) &cap; RS(Tj) = &empty; and WS(Ti) &cap; WS(Tj) = &empty; and Ti completes its read phase before Tj completes its read phase.
        * No Wi-Rj conflicts since WS(Ti) &cap; RS(Tj) = &empty;.
        * No W-W conflicts since WS(Ti) &cap; WS(Tj) = &empty;.
        * In all Ri-Wj conflicts, Ti precedes Tj, since the read phase of Ti precedes the write phase of Tj.
 * GC?
 
Note: the antijoin in OCC is over all uncommitted transactions.  That means that during validation, the set of uncommitted transactions must not change. I.e. only one transaction can be validating at a time.  I.e. implicitly there's an X lock on the "validating" resource.

## Timestamp Ordering (T/O): streaming symmetric join of reads and writes, outputting data and aborts.
[Pretty good discussion in Wikipedia.](http://en.wikipedia.org/wiki/Timestamp-based_concurrency_control)

  Predeclare the schedule.  No waiting!  But restart when reordering detected...

- Keep track of r-ts and w-ts for each object: *single counter rather than full persistence.*
- reject (abort) stale reads.
- reject (abort) delayed writes to objects that have later r-ts (write was already missed).  Can allow (ignore) delayed writes to objects that have a later w-ts tho.
([Thomas Write Rule](http://en.wikipedia.org/wiki/Thomas_write_rule).)


### Multiversion T/O: Even fewer restart scenarios

(Wikipedia discussion is poor -- fix it!)

- Keep sets of r-ts, and <w-ts, value>.  This is symmetric persistence.
- Reads never rejected! (more liberal than plain T/O)
- Write rule on x: interval(W(x)) = [ts(W), mw-ts] where mw-ts is the next write after W(x) -- i.e. Min_x w-ts(x) > ts(W).  If any R-ts(x) exists in that interval, must reject write.  I.e. that read shoulda read this write.  Note more liberal than plain T/O since subsequent writes may "mask" this one for even later reads.
- GC of persistent state: anything older than Min TS of live transactions.

Note: no waiting (blocking, antijoin) in Multiversion T/O.