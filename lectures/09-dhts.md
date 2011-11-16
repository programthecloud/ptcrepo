# Distributed Hash Tables
Lessons from the p2p days.

## A little history
It's useful to think back to the early days of p2p filestealing.

- Napster: centralized server.  peers can post their list of files to centralized server, which indexes.  peers can also send queries to centralized server.  centralized server looks up peers with matches, orchestrates transfer.
  - minor wrinkle: firewalls and NATs can prevent unsolicited inbound traffic to a peer, so orchestration involves telling *both* peers to contact each other and open the gates.
  - pros & cons?
  
  
- Gnutella: flooding.  no centralized server.  each peer is connected to a modest number *n* of other "neighbor" peers.  queries are routed to each neighbor up to a distance of *h* hops.  each query visits *n^h* nodes.  search answers are routed back to querier.  (*n* = 5, *h* = 7, *n^h* = 78,125).
  - how is neighbor topology set up?  connect to any one node, flood a request for neighbors, pick the first *n* that come back.  high locality to original node.
  - pros & cons w.r.t. Napster?

- Gnutella, improved: flooding over super-peers.  a small subset of nodes are "super-peers" connected in a traditional Gnutella network (*n* = 32, *h* = 3, 32^3 = 32768).  other nodes are connected to a small number *k* of superpeers (*k* = 3, *kn^h* = 98,304).  superpeers chosen based on uptime, IIRC.
  - what's better than original Gnutella?
  - what's still broken?
  
## Enter the Distributed Hash Table
Questions:

  - Can we build a napster-like index, but distribute it in the network?
  - I.e. a perfect equality search, but allow nodes to come and go autonomously?
  - What's the relationship between data indexing (Napster) and query routing (Gnutella)?

Baseline:

  - Hash-partitioned database.  Easy enough!  Queriers shoot requests according to hash function.
  - Now how to deal with nodes coming and going?
      - Think about deleting a node.  Implications for data storage?  For querying?

### Building block: Consistent Hashing
Karger, et al.  This was a key piece of founding technology at Akamai.

  - We'd like a hash function in which the removal of "buckets" only requires moving the data in that bucket.
  - Think about storing object *o* at node *h(o)* mod *n*.  Removing a node changes *n*, and all the data reshuffles.
  - Instead, we'll hash both data values *and machines* to numbers on a circle.  Store the data item at the next highest value on the circle that has a machine on it.
  - Upon (clean) machine join or leave, reshuffling involves moving data from only one node.
  
      
### Chord
Stoica, et al.

Full Ring case:

  - First, imagine implementing consistent hashing among peers.  Start by assuming we have 2^*i* peers, and 2^*i* hash values (a "full" Chord ring).
  - Each peer knows its successor and predecessor on the ring.
  - Each peer also has *i*-1 *fingers*: pointers to nodes at distance 2^*f* for *f* = {1,2, ..., *i*-1}.
  - Draw the topology for a small *i*, say 3.  Try drawing all the *i* = 1 fingers,  All the *i* = 2 fingers, etc. [You will see some nice patterns.](chord-topology.pdf)  
  - Routing proceeds by choosing the finger that gets you closest to your target node.
  - Note symmetries here -- doesn't matter how you "rotate" the ring, the routes look the same.  What is Chord doing?
    - How many hops in a lookup?
    - Roots in Group Theory!
  
Ring Emulation:

  - In practice we don't have a full ring, as in Consistent Hashing.
  - Instead, each node covers a range of values that precede it, and has successor/predecessor pointers to nodes some distance ahead/behind.  (The "ring".)
  - From these we can find fingers that are successors of the finger we'd have in the full ring -- they are responsible for the key value of the finger.
  - Search works as before.
  
Ring maintenance under "churn":

  - This is a tricky concurrent distributed data structure problem.
  - We'd like to make it simple!
  - Join:
    - correctness invariants: data in the right place, successors must be right.  Predecessors and fingers are just "hints" and can be wrong!!
    1. new node claims an ID, does lookups to get the right successor pointer and fingers.
      - can copy fingers from successor as a bootstrap
    2. link into ring: lookup predecessor and ask to set yourself as successor
    3. lazily announce your presence to anybody whose finger should point to you
  - No explicit leave protocol
  - *Stabilization*: periodically fix successors/predecessors
    1. ask your successor to name its predecessor
    2. if not you, then link to new successor and notify it that you're the predecessor.
  - *Finger Fixing*: lazily/periodically fix fingers
    - lookup the value of a fingers and update.
    - can do this on detecting error, and/or periodically

Correctness/Performance

  - Assertion: successor relation is eventually consistent, so messages get delivered
  - Theorem: If finger fixing happens reasonably often (more often than #nodes doubling), lookups remain *O*(log *n*)
  
Tolerating Failure

  - Replicate data at log *n* successors on the ring, and incorporate into stabilization.
  
Load Balancing

  - With random assignment, you can have skew as bad as *O*(log *n*) times the average load.
  - Solution: Each node runs *O*(log *n*) "virtual nodes", which are independently placed on the ring; this spreads things out more evenly.
  
  
## Other DHTs
  - Similar tricks, tend to vary in the way that "fingers" and "routing" are done (and terminology differs)
  - Not all fall back on the "ring" as the base (but this is now common)
  - Much discussion of which topology is best:
      - Different topologies have different abilities to 
          - choose neighbors flexibly (or not).  not available in basic Chord.
          - choose next hops during routing flexibly (or not).  not done in basic Chord.
  - Some DHT names to know: CAN, Kademlia, Tapestry, Pastry

## Soft State
Chord gives us rendezvous in space.  What about rendezvous in time?  Usual answer: *soft state*.

Soft state is a persistence contract between a producer and a proxy.

  - The proxy promises to hold a copy of the item for a fixed window of time.
  - The producer is responsible to "refresh" the item within that window.
  - Typically this goes on indefinitely via periodic refresh.

Nice properties of soft state?
  - vs. "hard" state in which the proxy value must be actively deleted?

## Routing and Indexing again.
So remind me:

  - What is the difference between indexing data and routing queries?
    - Was this clear in Napster?  Gnutella?  Chord?
  - Relationship to smoke signals?

Everything interesting in distributed computing is about rendezvous in space and time.

  - DHT is "supposed" to enable a level of indirection in space
  - Do they solve the problem of rendezvous in time?  Weak spots?
    - atomicity of join/leave, stabilization, etc.
    - replica management
    - recall soft state: index is just a "proxy", not the data source
    - atomicity of data update w.r.t. the above
    - others?
 
## Some questions about Chord and DHTs in general

  - We described how to maintain the routing.  How about maintaining data under updates?
  - Chord was designed for an ad-hoc p2p network with lots of churn.  What might you change in a more stable managed environment like a datacenter?