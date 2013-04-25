<b>Note: This is an initial dump of the interactive coding demo presented at Northern California DB Day 2013.  This in a work in progress: we will flush out the narrative soon. </b>

Talk [Slides](slides.pptx)

## Part 1: Communication as rendezvous in time and space.

Communication: a speaker and a listener

        module Rendezvous
          state do
            interface input, :speak, [:subject, :val]
            interface input, :listen, [:ident, :subject]
            interface output, :hear, [:hear_id, :subject, :val]
          end
          bloom do
            stdio <~ hear.inspected
          end
        end

Rendezvous as join:

        module SynchronousRendezvous
          include Rendezvous
          bloom do
            hear <= (speak*listen).pairs(:subject=>:subject) {|s,l| [l.ident, s.subject, s.val]}
          end
        end

## Part 2: The duality of communication and storage

Speaker persists (AKA shared memory):

        module SpeakerPersist
          include Rendezvous
          state do
            table :spoken, [:subject, :val]
          end
          bloom :persist do
            spoken <= speak
          end
          bloom do
            hear <= (spoken*listen).pairs(:subject=>:subject) {|s,l| [l.ident, s.subject, s.val]}
          end
        end

Listener persists (AKA message passing):

        module ListenerPersist
          include Rendezvous
          state do
            table :listening, [:ident, :subject]
          end
          bloom do
            listening <= listen
            hear <= (speak*listening).pairs(:subject=>:subject) {|s,l| [l.ident, s.subject, s.val]}
          end
        end

Observe that when we distribute SpeakerPersists, it behaves like a key/value store.  
 * Substitute PUT for speak, GET for listen, RESPONSE for hear.

When we distribute ListenerPersists, it behaves like a pub/sub system.


## Part 3: Assessing the need for coordination protocols

But our "key/value store" behaves strangely; it appends values rather than replacing them, and doesn't record the order in which puts occur.  In return
for this odd behavior, we get some very nice properties:

 * Regardless of the order of the PUTs, GETs eventually return a single, determininstic result.  This pseudo-kvs is eventually consistent.
 * At any time, GETs return a subset of the result.  We need never retract the consequences of a GET.

Our analysis and visualization confirms these intuitions.  The yellow coloring of the graph indicates uncertainly about ordering, due to asynchronous
communication.

       budplot -I . ./proxy.rb Proxy RendezvousAtProxy
       open bud_doc/index.html

<img src=kvs.png width=20%>

If we convince ourselves that we really want the overwriting semantics of a traditional key/value store, we can implement them by replacing the synchronous
merge of __speak__ into __spoken__ with a pair of rules that atomically merge the new value and cause the old value to disappear in the very next visible state
of the system:

            spoken <+ speak
            spoken <- (speak * spoken).rights(:subject => :subject)

Again, our analysis confirms the intuiton that a mutable KVS will be sensitive to the order in which PUTs occur.  The red coloring indicates potentially
nondeterministic contents (as well as orderings), in different runs or on different replicas.

<img src=kvs.png width=20%>

Plot of distributed MutableSpeakerPersist (AKA KVS)


<img src=kvs.png width=20%>

