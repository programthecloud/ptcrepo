# Bloom Demonstration

## Setup
```ruby
  require 'rubygems'
  require 'bud'
```

## Part 1: Communication as rendezvous in time and space.
Communication happens via rendezvous: two agents—a speaker and a listener—appear at the same place at the same time to hand off a message.

Let's begin by defining input interfaces for the agents to request to `speak` and `listen` on various `subject`s. 

`rendezvous_api.rb`
```ruby
  module RendezvousAPI
    state {
      interface input, :speak, [:subject, :val]
      interface input, :listen, [:ident, :subject]
      interface output, :hear, [:hear_id, :subject, :val]
    }
  }
```

If these interfaces are populated on the same node at the same time-tick,
then rendezvous is simply relational join!

`rendezvous.rb`
```ruby
  # Synchronous Rendezvous
  module SynchronousRendezvous
    include RendezvousAPI
    bloom {
      hear <= (speak*listen).pairs(:subject=>:subject) {|s,l| [l.ident, s.subject, s.val]}
    }
  } 
```

The problem, of course, is that both the `speak` and `listen` events
have to arrive at the `RendezvousAPI` at exactly the same time for this to work! This is not something we can count on in a distributed system.

## Part 2: The duality of communication and storage
In general, to handle the unpredictability of arrival times we will
need **persistence** *across* time to ensure that speaking and listening
*coincide*. In Bloom, we can record one of the interfaces in a 
persistent table; the fact that interfaces, tables and communication
channels all share a single API makes this very clean.

The pattern most people think of first is to persist messages,
using some kind of buffer. We'll call it `spoken`:

`rendezvous.rb`
```ruby
  # Speaker Persists (a.k.a. Buffered Messages)
  module SpeakerPersist
    include RendezvousAPI
    state {
      table :spoken, [:subject, :val]
    }
    bloom :persist {
      spoken <= speak
    }
    bloom {
      hear <= (spoken*listen).pairs(:subject=>:subject) {|s,l| [l.ident, s.subject, s.val]}
    }
  }
```

That works! Whenever a listen event arrives, it will pick up all the previously
`spoken` messages that match subjects. One concern here: if the `listen` arrives too early, it won't hear anything that's `spoken`. What can we do about that?

In relational database joins, a query optimizer can choose to persist
either side of the join. What happens if we store the listeners rather
than the messages? This is like keeping a stored list of listeners who
*subscribe* to any messages that may appear on a given `subject`. 
We'll store them in a table called `listening`:

`rendezvous.rb`
```ruby
  # Listener persists (a.k.a. Subscriptions)
  module ListenerPersist
    include RendezvousAPI
    state {
      table :listening, [:ident, :subject]
    }
    bloom {
      listening <= listen
      hear <= (speak*listening).pairs(:subject=>:subject) {|s,l| [l.ident, s.subject, s.val]}
    }
  }
```

That works too. Whenever a message arrives, it is paired with all the subscriptions on that `subject`. The concern here is if the `speak`
message arrives to early, it won't get caught by a late-arriving `listen`er.

To remove any concern about these race conditions, we can have both sides
persist. The `include` "mix-in" Ruby directives copy the code from both `SpeakerPersist` and `ListenerPersist` into the `BothPersist` module. 
In the resulting module, it won't matter whether `speak` or `listen` goes 
first. Convince yourself of that by looking over all the rules being
`include`d -- for each pair of events `speak` and `listen`, one of the two 
rules that populate `hear` will always match the second-arriving event to the
first-arriving event that was persisted! (This is known as a *symmetric join*
in the database literature, and it works well for streaming sources like 
unpredictable event streams.)

`rendezvous.rb`
```ruby
  # Both Persist (Symmetric Join)
  module BothPersist
    include RendezvousAPI
    include SpeakerPersist
    include ListenerPersist
  end
```
### Summing Up
We've seen how communication handoffs involve rendezvous in space and time. In
the examples above, we showed how we can avoid the need for *coincidence* by introducing persistence. We saw how persisting the different roles in the 
communication individually produces different potential race outcomes, and we
saw that persisting both roles removes any concern about races.

## Thinking about Distributed Systems
In the examples above, we "cheated" with respect to rendezvous in space, by assuming that the `speak` and `listen` interfaces were at the same node: in essence the speaker, listener, and rendezvous agents were all on a single node (kind of like the original UNIX `talk` program from the 70's era of timesharing!) Let's relax that outdated assumption—it will be easy!

In Bloom, we can very simply interpose on interfaces and forward their contents across a network—this is how we scale up single-node implementations into distributed systems. To start, let's assume the speaker, listener and rendezvous agents are on 3 different nodes. The rendezvous will happen at a *server* node, which will accept and return messages. The speaker and listener agents don't change their code, they just need to include some `Proxy` logic
to forward their interfaces:

`proxy_api.rb`
```ruby
# ProxyProtocol
module ProxyProtocol
  state do
    channel :speakToProxy, [:@addr, :key, :val]
    channel :listenToProxy, [:@addr, :ident, :key]
    channel :rcvFromProxy, [:@hear_id, :key, :val]
  end
end
```

`proxy.rb`
```
# Forward `speak`/`listen` to the remote `SERVER`
# Forward `rcvFromProxy` to the local `hear` interface
module RendezvousAtProxy
  include ProxyProtocol
  include RendezvousAPI
  bloom :wire_client do
    speakToProxy <~ speak {|s| [SERVER] + s.to_a}
    listenToProxy <~ listen {|l| [SERVER] + l.to_a}
    hear <= rcvFromProxy
  end
end
```

Note how the `speak` and `listen` events are forwarded by the `RendezvousAtProxy` module to the network `channel`s in the `ProxyProtocol`, 
with the destination `SERVER` (a configuration constant). In return, any
messages that arrive on the `rcvFromProxy` `channel` are forwarded back into the `hear` interface.

Another important feature to note above is the use of the characteristic *asynchronous merge* operator of Bloom, `<~`. This is required because a distributed system does not directly control the interleaving and order of messages. So even if we `speak` before we `listen` in physical time, that does not mean that the server will receive those messages in that order!

Note that we can still choose the persistence model for the server. At this point, though, the analogy becomes very clear:

- `SpeakerPersist` is much like a Key-Value Store service, kind of like Cassandra or 
DynamoDB. (Just substitute the verb `PUT` for `speak`, and `GET` for `listen`!) Of course in that model we expect that you cannot expect a successful `GET` before somebody `PUT`s!
- `ListenerPersist` is much like a Publish-Subscribe service, kind of like Kafka. (Just 
substitute the verb `PUBLISH` for `speak` and `SUBSCRIBE` for `listen`.)

These two very different flavors of distributed system are mirror-images of each other—they differ only in the persistence choices for rendezvous. Since stored state and communication share the same API and model in Bloom, that near-symmetry becomes clear and easy to control.

### A Note on Distributed Services
The proxied example we just saw is a distributed system of three nodes, but the rendezvous ``service'' itself is not (yet) distributed. We can extend it to a distributed service in ways that are very similar to what we did above—by interposing on interfaces and forwarding across networks. But before we do that, we need to pause and discuss a deep topic in distributed systems that Bloom makes remarkably simple: the need for coordination protocols.

## Part 3: Assessing the need for coordination protocols

Our `SpeakerPersist` "Key-Value Store" behaves a bit strangely: it appends values rather than replacing them, and doesn't record the order in which the values are `PUT` into the store.  In return for this odd behavior, we get some very nice properties:

 * Regardless of the order of the `PUT`s, if we wait for the system to quiesce then `GET`s will eventually return a single, deterministic result.  Our pseudo-kvs is *Eventually Consistent*.
 * At any time (even during ongoing `PUT`s), `GET`s return a subset of the eventual result.  We need never retract the consequences of a GET.

Bloom is able to detect these eventual consistency properties by analyzing the syntax of the program, which can be visualized in a tool called `budplot`.

       budplot -I . ./proxy.rb JoinServer RendezvousAtServer
       open bud_doc/index.html

<img src=kvs.png width=20%>

The yellow coloring of the graph indicates *unpredictable ordering* of messages along that edge, due to asynchronous communication. As we said above, it's OK in our example to have this unpredictable ordering, because we keep all facts in an unordered set, and get eventual consistency. (Hence the graph has some yellow, but no red!)

If we really want the overwriting (mutable state) semantics of a traditional key/value store, we can implement that by replacing the synchronous
merge (`<=`) of __speak__ into __spoken__ with a pair of rules that atomically ensure that in the next tick, the old value will disappear (`<-`) and the new value will appear (`<+`):
```ruby
  spoken <+ speak
  spoken <- (speak * spoken).rights(:subject => :subject)
```

(In the second line above, the `rights` command keeps only the attributes associated with the right-hand-table of the join of `speak` and `spoken`. So the line identifies the entries in `spoken` that match the subject of `speak`, and scheduled them for deletion before the next tick.)

As you can imagine, mutable stores are sensitive to race conditions: the value on a `GET` is the most recent value that was `PUT`, and all those requests are subject to order uncertainty thanks to the use of `channel`s.

Our analysis confirms the intuiton that a mutable KVS will be sensitive to the order in which requests occur.  The red coloring indicates potentially
non-deterministic contents (as well as orderings) that could occur depending on 
non-deterministic network channel interleavings.

<img src=kvs2.png width=20%>

### Discussion
The `budplot` graphs capture a simple property: if you have order-sensitive logic "downstream" of non-deterministic network communication in your system, you have a non-deterministic system! Bloom's syntax makes this easy to check:

- Bloom's parser requires that the use of network channels is flagged by the `<~` operator. You cannot help but notice the non-determinism of order you are introducing!
- Bloom has a fixed set of operators and functions that are known to be order-insensitive ("monotonic"). This includes the instantaneous (`<=`) and deferred (`<+`) merge operators, as well as many standard relational functions like Join (`*`) and `map`. Other Bloom constructs are order-sensitive ("non-monotonic"): these include the delete operator (`<-`), and functions like `group` and `reduce`.

In many cases where you may feel the need to use non-monotonic, order-sensitive operators. The advanced "lattice" features of Bloom can help you stay monotonic in many cases. While this is beyond the scope of this tutorial, here's a hint: the `lmax` lattice can be used to flag monotonically increasing *versions* of state. Used cleverly, version-based state can avoid the cost of keeping all of history (as in our initial designs above), without introducing non-monotonicity.
