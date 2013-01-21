# Previous lectures

* ordering: per agent/channel, across agents/channels
* single-server concurrency control
* replication and quora

# We have some leftover concurrency topics to cover

* Deadlocks
* Degrees of consistency (Isolation Levels)

# Also Today: Add partitioning, synthesize with replication, locking.

* Data partitioning: routing, skew handling
* Partitioning + replication
* Partitioning + locking/deadlocks

# Deadlocks
* Necessary conditions:
  * mutex
  * hold and wait
  * no preemption
  * circular wait
* Prevention:
  * pre-declare locks (no hold and wait)
  * impose a (partial) order on resources (no circular wait)
* Avoidance
  * lock protocol causes "eager" abort on risk of deadlock, via a priority scheme, Older (O) > Younger (Y).
      * Be sure not to reassign age on restart!
  * *Wound-Wait* vs. *Wait-Die*.  Naming scheme is O-Y
<pre>
                       | Wait-Die   | Wound-Wait |
                       ===========================
  O wants lock from Y: |  O waits   |   Y dies   |
  Y wants lock from O: |  Y dies    |   Y waits  |
</pre>

* Detection
  * form waits-for graph, test for cycles
  * abort one transaction on cycle.
  * most cycles length 2
  
# Degrees of Consistency

Varying degrees of consistency in a transactional database, became SQL standard "isolation levels". [Originally defined](http://scholar.google.com/scholar?cluster=8086123144151165991) in terms of relaxed 2-phase locking protocols.  Enshrined in SQL spec.  [Adya and Liskov](http://scholar.google.com/scholar?cluster=12975897967422539576) generalized to a schedule-oriented view, which generalizes to optimistic/timestamp concurrency.

* Degree 0: Atomic Writes
  * Locks: short write locks
* Degree 1: Read Uncommitted 
  * Locks: 2-phase writes, no read locks
  * Adya: no ww cycles
* Degree 2: Read Committed
  * Locks: 2-phase writes, short reads
  * Adya: no circular information flow.  also no aborted reads, no "intermediate" reads
* "Degree 2.99": Repeatable Read
  * Locks: 2PL reads/writes on data (not predicates).  Phantoms!
  * Adya: Degree 2 + no cycles with *item*-anti-dependency edges
    * Anti-dependency: overwrite somebody else's read
* Degree 3: Serializable
  * Locks: 2PL on data and predicates
  * Adya: Degree 2 + no cycles with anti-dependency edges

* Snapshot Isolation (Oracle & others)
  * all reads of a xact are from a single snapshot (at xact start)
  * commit only if no write-write conflicts.  unlike optimistic CC, only track writes.
  * implemented via MVCC
  * "write skew": two xacts read overlapping stuff, write different stuff.  end-result may not "add up" (example: can't enforce constraint that checking+savings >= 0)
  * recent results to generalize this
  
# Data partitioning

* Scalability buzzwords
  * "Speedup": same job goes faster proportional to parallel resources
  * "Scaleup": # jobs per unit grows proportional to parallel resources
  * "Scaleout": Scaleup, but using distributed HW
  
* Scaleout: Want to partition computation?  Sure, but more often partition data first, computation "follows".
  * How?  
     * Random, Round-robin, hash-partition, range-partition
     * Load-balancing concerns?
         * range-partitioning is a prob
         * dups/hotspots are a prob
         * one standard trick to ameliorate: "virtual nodes", "oversampling", etc.
  * Need to rendezvous computation and data?  A distributed indexing (or routing) problem.
     * broadcast
     * static global info
         * lookup structure (table, index)
         * hash function
     * dynamic global info
         * like a routing "overlay"
         * see work on Distributed Hash Tables ([Chord](http://pdos.csail.mit.edu/papers/ton:chord/), [CAN](http://berkeley.intel-research.net/sylvia/cans.pdf), [Kademlia](http://pdos.csail.mit.edu/~petar/papers/maymounkov-kademlia-lncs.pdf), etc.)
  * OMG! What about computations that span nodes?
      * On-the-fly Redistribution BW is cheap within a rack, not so bad in a datacenter
          * theme of 2 decades of DB work, then MapReduce
      * But latency not so great.
      * Repartitioning suitable for "dataflow parallelism" with sizable jobs.  
      * Not good for fine-grained parallelism.
    
* Locking in a partitioned system?
  * Easy-peasy!
  * Well, except for 
      * Two-phase Commit (next week!)
      * Distributed deadlock detection (below)
  
* What about replicating partitions?
  * Should be easy too
  * But what about load balancing?
      * Especially under failure?
  * One idea: [Chained Declustering](http://scholar.google.com/scholar?cluster=10345968159835311656&hl)
      * Imagine your nodes are in a ring 0-(N-1)
      * Partition your data as you normally would
      * If item I is on node n, store the replica on node (n+1)%N
      * More generally on multiple "successor" nodes
      * This scheme can balance work even under failure by "shifting" load 
          * requires some fancy routing!
          * at large scale maybe doesn't matter much (see DHT work)
<pre>
       Node # |    0     |    1    |    2     |    3    |
       ==================================================
              | P(0)     |  XXXXX  | 1/3 P(2) | 2/3 P(3)
              | 1/3 B(3) |  XXXXX  | B(1)     | 1/3 B(3)
</pre>

* Distributed Deadlocks, Deadlock Detection
  * Need to find cycles in a graph
  * The graph data is ... where?
  * Solutions?
  * PS: Bloom is gonna make this Easy-Peasy Lemon Squeezy!
      * Transitive closure of graphs is really nice in Bloom.
      * Bloom is disorderly by default.  
          * As a matter of healthy exercise, we've been struggling all semester to do "the hard stuff": ordering in Bloom.
          * Does TC(graph) require ordering?