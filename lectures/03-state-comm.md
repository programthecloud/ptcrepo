# Today's topic: Order, State and Communication

Previously, we concerned ourselves with ordered communication.  The goal was to ensure an *acceptable order of events*.  This raises some questions:

* What's an event?
* What's acceptable?
* What (partial) orders arise, who/how to restrict them?

# The Flow for Today's Lecture

1. Per-agent order
2. Inter-agent basics: communication
3. Shared state (persistent storage) and its evolution
4. Putting it together: the standard example -- read/write memories.

# I.  Per-Agent Order
Scenario: Four variations on a Calculator Server.  Alice, the sender, submits inputs to Chanel, the network, who forwards them to Bob.  Bob, the server, receives inputs from Chanel and returns outputs to Chanel, who forwards them to Alice.  Chanel, the transport layer, can reorder and batch messages at will, but eventually delivers them to the proper recipient.

<pre>
  Variation 1: Arithmetic Server.

  Input: A string representing a legal arithmetic expression over Floats, and the binary operators +, -, *, / with the usual binding rules.

  Output: A single Float that is the value of the input expression.

  Example: 
  Input: "2*3*4+5+6"
  Output: 35
  
  ----------------------------------------------------------------------------
  Variation 2: Binary Single-Operator Server.

  Input: A string representing an infix invocation of a binary arithmetic operator over two Floats.

  Output: A single Float that is the value of the input expression.

  Example Sequence:
  Input: "2*3"
  Output: 6
  Input: "6*4"
  Output: 24
  Input: "24+5"
  Output: 29
  Input: "29+6"
  Output: 35
  
  ----------------------------------------------------------------------------
  Variation 3: Memory Cell with Addition:

  Input: A single Float

  Output: Sum so far

  Example Sequence:
  Input: "24"
  Output: 24
  Input: "5"
  Output: 29
  Input: 6
  Output: 35
  
  ----------------------------------------------------------------------------
  Variation 4: Memory Cell with Unary Arithmetic:

  Input: One of the following 2 possibilities:
  	- a Float, indicating that its value should be stored at the server
  	- a pair of a binary arithmetic operator and a Float, indicating that value at the server should be replaced by the value computer by applying the operator to the previously-stored value and the new Float.

  Output: the value stored at the server after handling the input

  Example sequence:
  Input: 2
  Output: 2
  Input: "*3"
  Output: 6
  Input: "*4"
  Output: 24
  Input: "+5"
  Output: 29
  Input: "+6"
  Output: 35
  
</pre>

Upshot: 1) does agent order matter?  2) does server "state" matter?

# II.  Inter-Agent Communication:  Rendezvous/Join
The Ancient Communication Scenario: 1 sender, 1 receiver.

In previous scenario, the "server" didn't make any decisions; it was essentially a single-party computation with delegation.  Let's look at a genuinely 2-party computation, where both parties have "agency". Simplest case: message delivery between Sender and Receiver.

1. __SpatioTemporal Rendezvous__: Timed Smoke Signals on 2 mountaintops.  Agent 1 has instructions to generate a puff at certain time (and place).  Agent 2 has instructions to watch at same time (and place).
2. __Receiver Persist__: Smoke Signal and Watchtower.  Agent 2 *waits* in watchtower for smoke-signal in the agreed-upon place.  Agent 1 puffs at will.  (What if too early?)
3. __Sender Persist__: WatchFires.  Agent 1 can light a watchfire.  Agent 2 checks for the watchfire when convenient.  (What if too early?)
4. __Both Persist__: Watchfire and Watchtower.  Both persist.

Upshot: (1) one-sided persistence allows asynchrony on the other side.   (2) BUT persistent party must span the time of the transient party.  (3) Without any temporal coordination, persistence of both sides is the way to guarantee rendezvous: second arrival necessarily overlaps first.

Next Question: Multiple communications.  Can we guarantee order?  With temporal rendezvous, the agents coordinate ("share a clock").  With receiver persist, receiver can observe/maintain sender order.  Sender persist much more common, but doesn't (organically) preserve order!

***Beware:  In most computing settings, this reasoning is flipped***.  Storage is a given, and ends up being an *implicit* comm channel.  Must control operations on it across agents.

# III: State Evolution
Before we proceed, let's talk about memory/storage -- what we often call the "state" of a computation.  How does state evolve over time?

- Atomic state modification: You Can't Have Your Cake and Eat it Too.
- Copies: Shadow copies.  Copy-on-write.

> "I woke up one morning and looked around the room. Something wasn't right. I
> realized that someone had broken in the night before and replaced everything
> in my apartment with an exact replica. I couldn't believe it...I got my
> roommate and showed him. I said, 'Look at this--everything's been replaced
> with an exact replica!' He said, 'Do I know you?' -- Steven Wright  

- Histories: You Are What You Eat.  
    - Versions -- snapshotted histories.

All these different ways of representing state evolution are in use in practice.  Pros and cons revolve around many issues, including performance, complexity, flexibility...

# IV: Controlling Operations in a Memory

1. What are the operations on state?
2. What orders matter for these operations?  
3. A client's view of the acceptable orderings: sequential consistency, serial schedules, serializability.
4. Conflicts.  Assume two clients, one server.  What interleavings do not preserve client views?  R-W and W-W conflicts.
5. Approaches to conflicts

  * Atomicity/exclusion.  2-Phase Locking (2PL).  [CS186 Notes](http://www.cs186berkeley.net/sp09/browser/lecs/18-xact-CC.6up.pdf)
  * Copies.  Optimistic Concurrency Control (OCC).
  * Histories.  Timestamp and Multiversion CC (MVCC).

# V: Things to Ponder

1. What if communication is explicit, rather than implicit through storage?
2. Is read/write memory "the right data structure"?  How can we get past it?
3. What are some other reasonable orderings besides serializability?