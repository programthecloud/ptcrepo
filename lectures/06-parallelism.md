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
         * one standard trick to ameliorate: "virtual nodes", "oversampling", etc.  Kinda like hashing ranges.
         * dups/hotspots are a prob
  * Need to rendezvous computation and/or data?  A distributed indexing (or routing) problem.
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
      * So: recast your algorithm in a way that supports dataflow parallelism!
    
* Locking in a partitioned system?
  * Easy-peasy!
  * Well, except for the following (coming soon!):
      * Two-Phase Commit (2PC)
      * Distributed deadlock detection
  
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
          * requires fancier routing!
          * at large scale with adaptivity maybe just tolerate imbalance for a while (see DHT work)
<pre>
       Node #  |    0     |    1    |    2     |    3    |
       ==================================================
       Primary | P(0)     |  XXXXX  | 1/3 P(2) | 2/3 P(3)
       Backup  | 1/3 B(3) |  XXXXX  | B(1)     | 1/3 B(3)
</pre>

# Parallel Programming and Big Data: The current sorry state of affairs

A typical analytic lifecycle:

- Data In DB -> sample.csv -> R -> spec.docx -> custom.java -> DB extract -> scores.csv -> DB Import

- Better: push the functionality of R into the DB or Hadoop cluster
- This is not just a SMOP!
- Need to figure out how to write analytic algorithms in data-parallel style, as SQL or MapReduce code.

## Programming Models
History, various people realized in the 1970's and 1980's that "disorderly" programming allowed for parallelism, one way or another.  Two strands 

- "dataflow" programming (most prevalent in computer architecture) 
- "declarative" programming (basically SQL).  

These two models persist today as the only broadly successful parallel programming paradigms.  Usually called *data-parallel* style of computation.  Usually follow the pattern of *Single-Program-Multiple-Data (SPMD)*.

- The Dead Parallel Computer Society of the 1980's (vs. Teradata)
- Caveat: MPI does exist, and is used some in HPC.

Side note: Bloom in many ways is an extension of the success of this history.  If data-parallelism works for Big Data, why not for fine-grained computing?

### Parallel SQL
Why is SQL good for parallelism?

- Originally, the motivation for the relational model and languages--so called "data independence"--was to enable reorganization of data on disks: new sort orders, indexing, and so on.
- But as we know, storage layouts are just one form of rendezvous in space/time.  Another form is batched I/O, e.g. the partitioned hash join.  And more generally the ability to do query optimization--e.g. to reorder entire batches of work based on high-level reasoning about commutativity and associativity.
- Partitioning and communication are just another spin on this.  E.g. the partitioned symmetric hash join.
- Various research groups and one company--Teradata--figured this out in the 1980's.  

Is SQL a general-purpose "programming" language?

- It was envisioned as a domain-specific language (DSL) for querying databases, though it has quite a lot of expressive power.
- By the time people were looking into parallel SQL, expectations were high: you had to do the whole suite of relational features, especially transactions and automatic query optimization.  
- OTOH, the set of expressions to be evaluated on the data (both scalars and aggregates) were typically fixed. 
- So really confined into being a query language: need to keep it simple to optimize it, etc.  Even though in principle it's quite flexible. 

This legacy still pervades many of the parallel database vendors, but things are changing thanks to pressure from MapReduce.

SQL extensibility

- A big topic in the late 80's and 90's
- At some level, pretty easy to support:
  - UDFs
  - UDAs
  - OO-style UDTs
- DBMS expectations set the bar really high though
  - query optimization & parallelization
  - indexing
  - security
- Meanwhile, language limitations
  - Recursion not usually well treated
  - Cultural (and sometimes practical) aversion to loose structure.  (Why not a table with two columns, key and val!  Why not a table with one column and one row?)
- Result: not very "general-purpose programmer" friendly.  *But*: if your data lives in an SQL database, maybe you should push your code to the data there.
- Would that work?
  - You bet.  See [MADLib](http://madlib.net): ML algorithms implemented in extended SQL running inside the database.

Bloom vs SQL:

  - Bloom is explicitly partitioned and potentially MPMD
  - SQL is auto-partitioned and inherently SPMD.
  - A Thought: compile single-node Bloom down to parallel SQL!?  Could this be the right way to generate complex code like MADlib?  

### MapReduce
A topic that needs little introduction these days.

- A dataflow programming model.  
- Very easy to explain.
- Low bar to entry, in the style of dynamic typing: record splitting and key/val pairs, focus on extensions not the core.
- Also cultural acceptance of text manipulation rather than a type system.  
- Low expectations.  Just parallelize -- no optimization, indexing, security, recursion, transactions...
- Arguably because it's simple, people have been willing to see it as an algorithmic building block.
  - Initial example of PageRank attractively algorithmic.  Followed by various other machine learning algorithms in recent years (see [Mahout](http://mahout.apache.org)).
  - MapReduce has done *wonders* for changing how people think about computing.  Data-centric mindsets, disorderly programming, scale.  
  - "Most interesting thing about MapReduce is that people are interested in it."  This is not pejorative--it's really fascinating and useful.
- On the flip side, quite a low-level interface.  Even simple matching (joins) are a hassle.  Hence evolution of Sawzall/Dremel/Tenzing (Google), Pig/Hive/Impala/HAWQ (Hadoop).  Most production usage is in a SQL variant.

Bloom vs. MapReduce:

  - Again, Bloom explicitly partitioned and potentially MPMD
  - MapReduce auto-partitioned, SPMD
  - Thought 1: compile single-node Bloom down to Hadoop?  Vs. Pig/Cascalog?
  - Thought 2: implement Hadoop in Bloom?  Yes we can! See BOOM Analytics, below.
  - Thought 3: what happens when you combine Thought 1 and Thought 2?!?
  - Thought 4: any reason we didn't discuss this for SQL DBMSs?

## Runtime issues
### Let's review Hadoop.

- JobTracker & TaskTrackers
- Job divided into set of map & reduce tasks
- JobTracker farms out work to TaskTrackers
    - map reads in input chunks from HDFS, splits into records, runs user map code, partitions output k/v pairs to local disk.  
    - Reduce tasks pull buckets from all mappers (shuffle!), which run combiners. then sorts locally, runs user reduce code on each key, stores output in HDFS
- TaskTrackers have fixed # of slots (e.g. 2 maps, 2 reduces), heartbeat their status to JobTracker
- Failure handling, straggler handling 

- Obvious pros: 
    - centralized knowledge and scheduling at JobTracker
    - easy restart/competition of map tasks
    - easy restart of reduce tasks
    - decoupling of scheduling between mappers and reducers, facilitated by big disk buffers

- Obvious cons:
    - SPOF at JobTracker
    - pessimistic checkpointing
    - no pipelining!
    - potentially inefficient coordination between producers and consumers

### Your basic SQL engine

- Coordinator node, usually with hot standby, does scheduling, query optimization.
- Worker nodes with storage, index and query processing capability
- Data pre-partitioned and replicated across workers (hash/range/random)
- Query optimizer chooses algorithms, order of ops, materialization points vs pipelining at each stage.  Other components determine admission control, memory utilization, multiprogramming level...
- Comm patterns include: local processing, all-to-all shuffling using hash and sort, "broadcast" joins, tree-based aggregation

- Obvious pros:
    - High-level queries and query optimization can make a big difference in productivity
    - No overhead for checkpointing required
    - Pipelining is easy and quite common: huge perf benefits over Hadoop

- Obvious cons:
    - restart from the beginning only
    - straggler handling is not standard
    - hence higher variance in performance: fast runs should trump Hadoop, but rare slow runs can be very bad.

### The BOOM Analytics Story
[Boom Analytics Research Paper](http://db.cs.berkeley.edu/papers/eurosys10-boom.pdf)

How much cleaner/easier would it be if we reimplemented HDFS and Hadoop in Overlog (the precursor to Bloom)?

- BFS + Redo Hadoop scheduler
- BFS redundancy and scale-out
- Hadoop JobTracker scheduling

### The MapReduce Online Story
[MapReduce Online Paper](http://db.cs.berkeley.edu/papers/nsdi10-hop.pdf)

- Can we have Hadoop-style checkpointing and SQL-style pipelining?
    - E.g. for "online aggregation" or infinite stream queries?
- You bet we can.
- Tricks:
    - Maps push to (live) reducers to couple the pipeline when they can, reducers pull the rest
    - Batch up pushes and run combiners before pushing.
    - Reduce publishes "snapshot" outputs for speculative consumption by subsequent maps
- Fault tolerance
  - Map failure:
      - Reducers keep track of which mapper produced each spill file
      - Reducers treat incoming task outputs as tentative until told completion is done.  tentative stuff can only merge with stuff from same task.
  - Reduce failure:
      - Mappers have to save their buffers until reducer completes.