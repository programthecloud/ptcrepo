## Optimistic Concurrency Control
An attractive, simple idea: optimize case where conflict is rare.

Basic idea: all transactions consist of three phases:

1. **Read**. Here, all writes are to private storage (shadow copies).
2. **Validation**. Make sure no conflicts have occurred.
3. **Write**. If Validation was successful, make writes public. (If not, abort!)

When might this make sense? Low conflict rates!  Three examples:

1. All transactions are readers.
2. Lots of transactions, each accessing/modifying only a small amount of data, large total amount of data.
3. Fraction of transaction execution in which conflicts "really take place" is small compared to total pathlength.


The Validation Phase

* Goal: to guarantee that only serializable schedules result.
* Technique: actually find an equivalent serializable schedule. That is,
    1. Assign each transaction a TN during execution.
    2. Ensure that if you run transactions in order induced by "<" on TNs, you get an equivalent serial schedule.

Consider *some transaction Tj* we are trying to validate.  *For all transactions Ti* such that TN(Ti) < TN(Tj), if one of the following three conditions holds, then Tj is valid:

1. **Condition 1**: Ti completes its write phase before Tj starts its read phase.
2. **Condition 2**: WS(Ti) &cap; RS(Tj) = &empty; and Ti completes its write phase before Tj starts its write phase.
3. **Condition 3**: WS(Ti) &cap; RS(Tj) = &empty; and WS(Ti) &cap; WS(Tj) = &empty; and Ti completes its read phase before Tj completes its read phase.

Is this correct? Each condition guarantees that the three possible classes of conflicts (W-R, R-W, W-W) go one way only.

1. For condition 1 this is obvious (true serial execution!)
2. For condition 2 we have that Ti precedes Tj:
    * No Wi-Rj conflicts since WS(Ti) &cap; RS(Tj) = &empty;
    * In all Ri-Wj conflicts, Ti precedes Tj, since the write phase (and hence the read phase) of Ti precedes that of Tj.
    * In all W-W conflicts, Ti precedes Tj by assumption.
3. For condition 3,
    * No Wi-Rj conflicts since WS(Ti) &cap; RS(Tj) = &empty;.
    * No W-W conflicts since WS(Ti) &cap; WS(Tj) = &empty;.
    * In all Ri-Wj conflicts, Ti precedes Tj, since the read phase of Ti precedes the write phase of Tj.

**Assigning TN's**: at beginning of transactions is not optimistic; do it at end of read phase. Note: this satisfies last part of Condition 3 ("Ti completes its read phase before Tj completes its read phase").

**Note:** a transaction T with a very long read phase must check write sets of all transactions begun and finished while T was active.  This could require unbounded buffer space. 

**Solution:** bound buffer space, toss out when full, abort transactions that could be affected.

* Gives rise to starvation. Solve by having starving transaction write-lock the whole DB!

### Serial Validation

Only checks properties (1) and (2), since writes are not going to be interleaved.

Simple technique: make a critical section around <get xactno; validate (1) or (2) for everybody from your start to finish; write>. Not great if:
    
* write takes a long time
* parallel HW – might want to validate 2 things at once if there’s not enough reading to do

Improvement to speed up validation:

    repeat as often as you want {
        get current xactno.
        Check if you’re valid with everything up to that xactno.
    }

    <get xactno; validate with new xacts; write>.

Note: read-only xacts don’t need to get xactnos! Just need to validate up to highest xactno at end of read phase (without critical section!)

  
### Parallel Validation

Want to allow interleaved writes. 

Need to be able to check condition (3).

* Save active xacts (those which have finished reading but not writing).
* Active xacts can’t intersect your read or write set.
* Validation:
    
        <get xactno; copy active; add yourself to active> 
        check (1) or (2) against everything from start to finish; 
        check (3) against all xacts in active copy 
        If all’s clear, go ahead and write. 
        <bump xact counter, remove yourself from active>.

Small critical section. 

Problem: a member of active that causes you to abort may have aborted

* can add even more bookkeeping to handle this
* can make active short with improvement analogous to that of serial validation