  1. Introduction and course overview
    * purpose, goals and nongoals
    * examination setup
  2. Order in distributed systems
    * necessary vs. convenient orders
    * happens-before relation and causality
    * variety of order guarantees (FIFO, causal, total)
  3. Communication & Storage: Dualities and Differences
    * rendezvous
    * storage
    * mutability
  4. Concurrency Control
    * Connection to Comm/Storage dualities
    * Visibility mechanisms
      * locking
      * versioning
    * Standard protocols: 2PL, OCC, TCC
    * Deadlock
    * Recovery
  5. Replication
    * rationale: 
      * performance vs fault tolerance
      * failure models
      * reliability, availability etc.
      * MTTR / MTBF
    * fundamental tradeoffs: CAP theorem
    * consistency concerns / anomalies
    * quorums
    * session guarantees
    * propagation mechanisms: epidemics, “read repair”
    * Case study: NoSQL store (guest lecture?)
  6. Parallelism
    * Scale-up vs. Scale-out
    * Partitioning
    * Ramifications for concurrency control
      * locking
      * deadlock
    * Relationship to replication
    * Case studies: SQL and Hadoop (guest lecture?)
  7. Distributed agreement
    * two generals
    * atomic commitment
    * consensus and atomic broadcast
    * protocols: 2PC, Paxos, leader election, failure detectors
    * Case study: Zookeeper (guest lecture?)
  8. Minimizing Coordination
    * semantics of eventual consistency
    * ACID 2.0: lattices
    * monotonicity and the CALM theorem
    * Bloom program testing
    * Case study: eCommerce realities (guest lecture?)
  9. Advanced topics
    * Distributed storage
      * DHTs, emphasis on chord
      * consistent hashing
      * soft state
      * routing and indexing
    * ``Big Data’’
      * programming models for data analysis
      * parallel SQL
      * mapreduce
    * Transactional Consistency
      * 3 degrees of locking and consistency
      * declarative definitions
  10. Wrapup

Optional Textbook: [Tannenbaum](http://www.amazon.com/Distributed-Systems-Principles-Paradigms-2nd/dp/0132392275)
