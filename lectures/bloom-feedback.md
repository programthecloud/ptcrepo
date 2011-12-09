# Critiques

- temp's don't have column names.  ("AS")

- lot of effort on "user side" of interfaces in the way we designed them -- e.g. sequence IDs not baked into initial requests.  

- module/mixin system kinda hacky.  really hard to keep track of overwriting names, overloading.  similarly-named bloom blocks can disappear.
	- multiple includes lead to bugs.
	- more than one way to do extension
	- neither of the two ways is enough
	
- block for notin works differently -- can't be used like a "map"
	- can't get projection on notin (block of notin is for notin-ing, rather than projection).
	
- difficult to have different modules run on different timescales!
	- e.g. output only after some number of timesteps
	- related to module/mixin system: modules might want their own "clock rates"

- synchrony vs. asynchrony of modules not obvious
	- asynch requires more work from user of module
	
- bootstrapping default values (e.g. for count) requires too much logic

- debugging is hard.
	- what are best practices?  what mechanisms are available?
	- tracking behavior across timesteps, e.g. asynch rendezvous behavior
	
- budvis dies with multiple threads?

- how many ticks are enuf?
	- for ordering-centric stuff we need to stimulate the system proactively
	- bloom is bad at this?

- hard to reason about randomness
	- e.g. choose m of n for quorum

- testing was really hard.
	- tedious to put in sync_callback_do
	- would be nice to have a declarative testing framework!
	
- more docs!!  cheat sheet is too terse.

- using channel in two different modules is hairy
	- have to make sure you agree on fully-qualified name!
	
- localhost vs. 127.0.0.1!
	- strings for id is bogus!

# Wouldn't It Be Nice If...

- autocomplete documentation for state statements
- distinguish between protocol and implementation +1
	- generics for the language: parameterized polymorphism
- automatic schema inference, and operator chaining
- <~ on scratch should work like <=, not be illegal
- budvis: 
	- color highlighting of diffs across ticks
	- click to expand opens in a new window, then next timestep reopens windows
- from rebl to interactive debugger:
	- import an entire chunk of code, modify, tick, dump, etc.
	- perhaps rebl should extend irb?
- left-side addressing to represent subset of columns to fill in (or overwrite)

```
  foo[col] <= bar {|b| [b.goo]}
  foo[col] <+- bar{|b| [b.goo]} 
  foo[col] <+- bar{|b| [nil]}
```

- bloom as a database/hadoop front-end??
