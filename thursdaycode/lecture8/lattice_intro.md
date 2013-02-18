# A Brief Introduction to Bloom Lattices
In this note, we'll go through some examples to understand the intuition behind Bloom's lattices, and use them to 
implement [Lamport timestamps](http://en.wikipedia.org/wiki/Lamport_timestamps).  If you're interested in more detail on Bloom lattices, 
you might like to read [our research paper on the topic](http://db.cs.berkeley.edu/papers/socc12-blooml.pdf).

## Setup
Before working through this, it might be useful to update your version of Bud from the latest in github:

    % cd <somewhere convenient>
    % git clone git@github.com:bloom-lang/bud.git
    Cloning into 'bud'...
    remote: Counting objects: 16378, done.
    remote: Compressing objects: 100% (5405/5405), done.
    remote: Total 16378 (delta 10974), reused 16341 (delta 10945)
    Receiving objects: 100% (16378/16378), 2.36 MiB | 71 KiB/s, done.
    Resolving deltas: 100% (10974/10974), done.
    % cd bud
    % gem build bud.gemspec
    Successfully built RubyGem
    Name: bud
    Version: 0.9.6
    File: bud-0.9.6.gem
    % gem install -l bud-0.9.6.gem 
    Successfully installed bud-0.9.6
    1 gem installed
    Installing ri documentation for bud-0.9.6...
    Installing RDoc documentation for bud-0.9.6...
    % 

## Background: Computing a Count
To get started, we'll look at a simple example of counting up a group of friends using "traditional" Bloom.  

Have a look at this program ([friends.rb](friends.rb)):

    require 'rubygems'
    require 'bud'

    class Friends
      include Bud

      state do
        table :friends, [:name]
        table :happiness, [] => [:cnt] # empty key: at most one item in collection
      end

      bloom do
        # my happiness equals the number of friends I have.
        # empty grouping columns: all items in same group
        happiness <= friends.group([], count)
    
        stdio <~ happiness
      end
    end

    f = Friends.new(:port=>12345, :trace=>true)
    f.friends <+ [['pat'], ['leslie'], ['sam']]
    f.tick

Run this program and it should return what we expect: 3 friends.  But what does `budvis` have to say about it?  Run `budvis` on the DBM directory that was created during your run.  (*You'll need to edit the snippet below to use your DBM directory.  Also, the `open` command is specific to OS X -- you can open the file in any modern web browser.*)

    % ruby friends.rb
    Created directory: DBM_Friends__70311995795420_12345
    Created directory: DBM_Friends__70311995795420_12345/bud_12345
    3
    % budvis DBM_Friends__70311995795420_12345
    % ls DBM_Friends__70311995795420_12345
    0.html			friends_0.html		t_stratum_0.html
    1.html			happiness.html		tm_0.svg
    bud_12345/		happiness_0.html
    friends.html		style.css
    % open -a /Applications/Safari.app DBM_Friends__70311995795420_12345/tm_0.svg 
    
You'll see that the arrow from `friends` to `happiness` is labeled with a circle, indicating that it is "non-monotonic".  If you think about it, that makes sense: adding another item to `friends` would require *retracting* our initial answer to `happiness`.  Said differently *computing the count* of items in a table is non-monotonic.

## Monotonic Counting using Lattices
Now let's modify the program to use an `lset` rather than a table, and an `lmax` as a counter.  Here's the file ([friends_lmax.rb](friends_lmax.rb)):

    require 'rubygems'
    require 'bud'

    class Friends
      include Bud

      state do
        lset :friends
        lmax :happiness
      end
  
      bloom do
        # my happiness equals the number of friends I have.
        happiness <= friends.size()
        stdio <~ [[happiness.inspect]]
      end
    end

    f = Friends.new(:port=>12345, :trace=>true)
    f.friends <+ [['pat'], ['leslie'], ['sam']]
    f.tick

And, after deleting the old DBM directory to avoid confusion, let's re-run things and reexamine the budplot output:

    % rm -rf DBM_Friends*
    % ruby friends_lmax.rb 
    Created directory: DBM_Friends__70126691255180_12345
    Created directory: DBM_Friends__70126691255180_12345/bud_12345
    <lmax: 3>
    % budvis DBM_Friends__70126691255180_12345
    % open -a /Applications/Safari.app DBM_Friends__70126691255180_12345/tm_0.svg 
    %

Note that the output is an encapsulated `lmax` object (we used Ruby to `inspect` it, but it's still encapsulated). Hopefully you'll also see in the `budvis` output that the arrow from `friends` to `happiness` is now lacking a circular label.  This is because the relevant rule 

    happiness <+ friends.size()` 
    
*is* monotonic.  To make sense of this, note two things.  First, the `size()` method is a [monotonic function](http://en.wikipedia.org/wiki/Monotonic_function) from an `lset` to an `lmax`: increasing `friends` always increases `friends.size`.  Second, the merge operation `<=` associated with `lmax`'es is a lattice merge function.  This means it must be Associative, Commutative and Idempotent, and hence implicitly monotonic: it "climbs" the lattice.  Both of these properties of `lmax` methods are known to the `budvis` analysis tool, so it blesses the code as monotonic.

So much for definitions.  But intuitively, what's the difference in this new version of the program?  Well, in this new version of the program we never actually output *the count*, we only output the (encapsulated) *object that is counting*, namely the `lmax` we defined.  

## Computing The Count with a Lattice
In the previous program we sort of cheated by calling Ruby's `inspect` method on the encapsulated lmax object.  (If our bud interpreter wasn't so lenient, it should probably return an error on that call.)  If we want to *properly* produce the state of an `lmax` at some time, we use the `reveal` method.  Replace your most recent bloom block with the following variant, which you'll find in [friends\_lmax\_reveal.rb](friends_lmax_reveal.rb):

    bloom do
      # my happiness equals the number of friends I have.
      happiness <= friends.size()
      stdio <~ [[happiness.reveal()]]
    end

and re-run things on the new version:

    % rm -rf DBM*
    % ruby friends_lmax_reveal.rb 
    Created directory: DBM_Friends__70285672337000_12345
    Created directory: DBM_Friends__70285672337000_12345/bud_12345
    3
    % budvis DBM_Friends__70285672337000_12345/
    % open -a /Applications/Safari.app/ DBM_Friends__70285672337000_12345/tm_0.svg 
    % 

You'll see that the non-monotonic step is in `reveal`-ing the value of the lattice, which is non-monotonic for the same reasons as the `group` method above.

## Lamport Clocks
With that background, let's shift to computing something more interesting: the happens-before relation in a distributed system, as captured by a Lamport clock.  Looking at the [definition of Lamport Clocks in Wikipedia](http://en.wikipedia.org/wiki/Lamport_timestamps), there are three simple rules to follow:

1. A process increments its counter before each event in that process;
2. When a process sends a message, it includes its counter value with the message;
3. On receiving a message, the receiver process sets its counter to be greater than the maximum of its own value and the received value before it considers the message received.

We'll do this in the context of our familiar delivery protocols.  The code from [lamportDelivery.rb](lamportDelivery.rb) is below; the three Wikipedia rules are highlighted in the comments.

    require 'rubygems'
    require 'bud'
    require './ts_delivery'

    module LamportDelivery
      include Bud
      include TSDeliveryProtocol
      import TSBestEffortDelivery => :bed

      state do
        lmax :cloq                 # our local Lamport clock
        scratch :event, []=>[:val] # empty key: at most one event per tick
      end

      bootstrap do
        # initialize clock to 0.  Current Bud version requires us
        # to use the internal constructor for an lmax (to be fixed).
        cloq <+ Bud::MaxLattice.new(0)
      end

      bloom :plumbing do
        # Wikipedia #2:
        # When a process sends a message, it includes its counter value with the message.
        bed.pipe_in <= pipe_in {|p| [p.dst, p.src, p.ident, p.payload, cloq]}
        pipe_out <= bed.pipe_out
        pipe_sent <= bed.pipe_sent
      end

      bloom :lamport do
        # Wikipedia #1:
        # A process increments its counter before each event in that process;
        event <= pipe_in {|c| [true]}
        event <= pipe_out {|c| [true]}
        cloq <+ event{|e| cloq+1}

        # Wikipedia #3:
        # On receiving a message, the receiver process sets its counter to be 
        # greater than the maximum of its own value and the received value before 
        # it considers the message received.
        cloq <+ bed.pipe_out {|p| p.cloq}
        stdio <~ bed.pipe_in.inspected
      end
    end

    class Doit
      include Bud
      include LamportDelivery
    end

    alice = Doit.new(:port => 12345)
    bob = Doit.new(:port => 23456)
    alice.run_bg
    bob.run_bg
    # run the following block 3 times
    (1..3).each do |i|
      alice.async_do do
        alice.pipe_in <+ [["localhost:23456", "localhost:12345", 2*i, "Bob, you're a palindrome!"]]
      end
      sleep 1
      bob.async_do do
        bob.pipe_in <+ [["localhost:12345", "localhost:23456", 2*i+1, "You can't spell malice without Alice"]]
      end
      sleep 1
    end
    sleep 1
