# Bloom, CALM and friends

## Developer questions that deserve answers:

Distributed coordination protocols are hard.  (Let's go shopping!)  They're also a terrible performance and operations drag -- slow and unpredictable.  Can't I get away with something like this:

1. **Ignoring Complexity**: Suppose I ignore the problems of concurrency and failure.  What's the worst that can happen?
2. **Avoiding complexity**: Can I rewrite my programs in a way that avoids the need for coordination?  Always?
3. **Encapsulating complexity**:  Can I solve my distributed systems problems once in a reusable library and hide the complexity?

These are hard questions to answer in general.  Most of the DB and Distributed Systems literature has answered them w.r.t. reads and writes on persistent storage.  The answers go like this:

1. **Ignoring Complexity**: Anything can happen.  Be afraid.
2. **Avoiding complexity**: No way.  Trivial examples occur with read-write and write-write conflicts.
3. **Encapsulating complexity**: Depends who you ask.  Coordinated memory systems (e.g. transactional databases, various cache coherency protocols) can do this for you, but at the expense of availability/latency.

But wait, you say.  I know more about my program's needs than a read/write analysis can understand!  (In fact in many cases you might not even really know your reads and writes very well.)  Can't we go back and answer those questions again through another lens?

> Can my programming environment (language, tools) help me write simple, efficient distributed code, and avoid complicated, expensive distributed protocols?

## Intuitions

This is a pretty old problem, and there are some good ideas floating around as "kitchen wisdom", "best practices", "design patterns", and the like.  Here's some of the basic intuitions:

1. **Commutative Operations**: Suppose I have an object class whose methods all mutually commute.  What problems would that solve?
2. **Idempotent Operations**: Suppose those ops were [idempotent](http://en.wikipedia.org/wiki/Idempotence) too.  What problems would that solve?
3. **Invertable Operations**: Suppose each op had a perfect inverse op.  What might that enable?  

Nice ideas.

Now for the software engineering questions.  Think you can write code like that?  Do you promise that the ops really satisfy those properties?  Do you promise that you'll use them right?  Can I trust you?  Can I trust the people who will inherit your code once you've moved on?

So -- good intuition, but pretty unsatisfying in practice.

### Example: Amazon shopping carts.  Insert/delete/checkout.

* The destructive cart.  For each cartID, a hash of item => quantity pairs.  Each add/delete from the user either changes the set of cartIDs in the hash, or "destructively" modifies the quantity in a particular cartID.  Checkout simply examines cart: it is the bill of sale.
* The disorderly cart.  For each cartID, a log of actions.  At checkout, assemble bill of sale by summing up inserts/deletes per item.

Assume replicated cart state.  

Questions: 

* What operations commute with each other?
* When to coordinate among replicas in each case?  Between client and replicas?  

Asides:

* do we need to ensure idempotence?  it's actually really easy, so no big deal.
* what's the role of invertability here?  it's pretty expensive in general (DB abort).

## Bringing it back to Bloom
OK, you run a team writing distributed software.  How might you ensure that these intuitions really get built right?

Some approaches:

1. Design patterns
2. APIs
3. Little languages (DSLs)
4. Static analysis

I sumbit that the 1st 2 are not viable software engineering solutions!  (No formal checks, no way to maintain compliance, especially over time.)

WRT (3), what are some "little languages" that we know are order-independent and easily parallelizable?  Say it all together now:  MapReduce.  And SQL too.

Well ... Map.  Not Reduce though!  

But guess what: *Join is order-independent too*.  Symmetric hash join: both sides persist.  Oh and don't forget -- this is the same as (fully asynchronous) rendezvous!  I.e. it covers many of the basic communication patterns you want in a distributed system.  We can even have loops/recursion on this!  (Remember deadlock detection?)

So wait, can we think through parallelizable ops like Map and Join and come up with a rich language?

Answer: yes, a large subset of Bloom fits this description.  But to understand this more deeply, let's dig into the roots of Bloom.

### Bloom roots: background on Datalog

Datalog was the favorite language of database theory geeks in the 1980s.  It was scoffed at as irrelevant dancing of angels on the heads of pins for much of the 90's and first half of the '00s.  Resurgence in last 7 years or so in new contexts -- not just us, also in games, compilers, AI, security, etc.

Quick background on Datalog: Think of Bloom restricted as follows:

* the only Ruby blocks allowed are simple Array construction 
* only allow instantaneous merge (<=)
* no use of the following constructs: `reduce`, `notin`, `group`, `argxxx`
* run for only 1 tick.  Contents of scratches at the end of that tick define the "answer".

We'll use Bloom syntax; Datalog is even more compact but most find it harder to read.  Here's the classic links & paths example:

```ruby
    state do
      table :link, [:from, :to] 
      scratch :path, [:from, :to]
    end
    
    bootstrap {link <+ [['a', 'b'], ['a', 'c'], ['b', 'd']]}
    
    bloom do
      path <= link
      path <= (path * link).pairs(:to=>:from) {|p,l| [p.from, l.to]}
    end
```

Basic Datalog is **monotonic**: as you add data and rules to the system, predicates can only grow in cardinality.

Evaluating Datalog (and Bloom) is pretty easy:

* Fixpoint (naive) evaluation: keep applying rules right-to-left like SQL queries until you learn nothing new.  The result is a "fixpoint".
* Semi-naive evaluation: at each iteration, avoid computing already-known stuff.  How?  By making sure you join in deltas.  (Do 2-table example.)
* Datalog programs have a Unique Least Fixed Point, and both these techniques compute it.

That's an *operational* view.
But Datalog is a purely declarative logic programming language.  There is no need to talk about its evaluation at all.  It is defined somewhat informally as follows (see [Ullman's course notes](http://infolab.stanford.edu/~ullman/cs345notes/slides01-8.pdf) for a more thorough description):

* A *model* of a Datalog program on a given EDB is a set of bindings to the variables in the program that "satisfies" the program in a consistent way. We are interested in "minimal" models, which have no subset that is a model
* Theorem: Datalog programs have a Unique Minimal Model.  I.e. a well-defined "outcome", however it may be computed.  This is a *model-theoretic* explanation of the program, has no recourse to any operational semantics.
* Theorem: The LFP of a Datalog program *is* its Unique Minimal Model.  I.e. we can use a natural operational strategy to compute the program's true "meaning".

Now ask yourself: 

* is semi-naive evaluation order-insensitive?
* can we run semi-naive eval in a distributed way?  E.g. hash-partitioned?
* use our symmetric hash join, and you get [pipelined semi-naive](http://db.cs.berkeley.edu/jmh/tmp/dnsigmod06.pdf).

Cool!  Pure datalog is order-insensitive, requires no coordination.

OK, but that's not much of a language is it?  *Amazingly, it is.  [Datalog is PTIME-complete](http://portal.acm.org/citation.cfm?id=802186), so any polynomial algorithm can be written in Datalog.*  It is not known, however, whether this can be made efficient w.r.t. constant factors in general, nor whether programmers will ever learn to write code this way.

### Bloom roots II: Stratified Negation
Suppose we can't deal with simple monotonic Datalog.  We're hungry for stuff like reduce, notin, group, argxxx!

Can we extend Datalog with, say, negated subgoals?  Sure, why not!  Call it Datalog-\neg.

```ruby
    state do
      table :link, [:from, :to] 
      table :hates, [:me, :you]
      scratch :path, [:from, :to]
      scratch :path_buf, [:from, :to]
      scratch :enemies, [:me, :you]
    end
    
    bootstrap do
      link <+ [['a', 'b'], ['a', 'c'], ['a', 'd'], ['a', 'e']. ['a','f']]
      hate <+ [['b', 'e'], ['e', 'c']]
    
    bloom do
      path <= link
      path_buf <= (path * link).pairs(:to=>:from) {|p,l| [p.from, l.to] }
      path <= path_buf.notin(enemies).
      enemies <= hate(A, B).
      enemies <= (enemies*hate).pairs(:you=>:me) {|e,h| [e.me, h.you]}
    end
```
Detail: Closed-World Assumption (negation as failure).

Expressibility: Is this more powerful than Datalog?  Nope, still PTIME.  Just handier.  (This is a [surprising result](http://scholar.google.com/scholar?cluster=1660603149772070343)!)

Any other problem?  Well, negation is *non-monotonic*: additional (say late-arriving) data can result in a deduction needing to "change its mind".  

OK, just introduce an ordering constraints: 

>    don't "make up your mind" until you have "sealed your input".
    
That's the idea behind *stratified negation*.  If you have a rule with a non-monotonic expression in it, just run all its input tables to fixpoint before evaluating the rule.  Minimal model per stratum, compute strata via LFP bottom-up.

Problem?  A la deadlock, we're worried about rules waiting for each other.  Indeed a program with cyclic dependencies through negation is *not stratifiable*.

## Distributed Stratification?
How do we "seal an input" in a distributed system?  Aha!  Coordination!

# CALM
Conjecture: Consistency and Logical Monotonicity.

LM => C.  Monotonic logic produces consistent results regardless of the order of messaging.  Proof seems pretty easy: construction via pipelined semi-naive.

C => LM?  All consistent programs are monotonic?  Well, not on their face anyway.  Let's set that aside.

LM + Coord => C.  If we introduce coordination at the stratification boundaries of a distributed Datalog program, we get an order-insensitive program.  Proof seems pretty easy, again.

And we can check C syntactically!  (Well, we can check it conservatively that way.)

## CRON

[CRON Hypothesis](http://databeta.wordpress.com/2010/12/03/the-cron-principle/): Causality Required Only for Non-Monotonic logic.

Pretty confident conjecture: Monotonic programs don't even require causal orders.  
Conjecture: Non-monotonic programs require casual ordering.

Thought experiments:

1. Consider computing paths in a graph.  Will the computation work out wrong if you learn about a 4-hop path before you've even computed the 2-hop paths?
2. Consider traveling back in time.  Is it a paradox for your great-great-grandparent to meet you?
3. Is it a paradox for you to have a child with your great-great-grandparent?
4. Is it a paradox for you to murder your great-great-grandparent?

1-3 are monotonic.  4 is not (the [Grandfather Paradox](http://en.wikipedia.org/wiki/Grandfather_paradox))

## Fateful Time Conjecture and Barrier Complexity.

Hypothesis: The purpose of time is to seal fate.  Any other use of time is a waste of time.  

We want to measure the cost of a program based on its minimum required number of ticks.  This is the complexity measure for distributed systems.

# Back to the beginning
Let's evaluate the questions at the top, thinking about Bloom/CALM:

  1. **Ignoring Complexity**: Suppose I ignore the problems of concurrency and failure.  What's the worst that can happen?
      * *Answer: no sweat if your program is monotonic.  We can also auto-inject coordination into a user program that is non-monotonic.  Or we can identify the potentially non-monotonic "points of order", and you can augment your program to carry that "taint" if you like.*
  2. **Avoiding complexity**: Can I rewrite my programs in a way that avoids the need for coordination?  Always?
      * *Answer: It appears that we should not need any of those techniaues, in theory, for any polynomial-time (i.e. reasonable) tasks.  Open question whether that's practical.*
  3. **Encapsulating complexity**:  Can I solve my distributed systems problems once in a reusable library and hide the complexity?
      * *Answer: Well, you can guarantee that a module guards all its non-monotonicity with some coordination protocol.  You still have to *use* it monotonically.  
