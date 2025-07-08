# Background Report 

## Introduction

Practically all modern computing devices have a tiered memory design. A
tiered memory is one that has non-uniform access patterns for different
memory regions. Most well-known is a CPU's cache hierarchy. Modern Intel
CPUs incorporate four memory tiers (see Figure 1) [cite]. The 'highest'
tier (DDR-attached memory) has a considerably higher access latency
compared to an access from L1. Data is moved between various tiers `of
the memory hierarchy at runtime, with the aim of having it be accessible
as fast as possible. This is a job that the hardware may do opaquely, or
by the compiler or programmer, using hints available as part of the
instruction set.

![Figure 1](image.png)

Similar designs exist for many different microarchitectures, for
different Instruction Set Architectures (ISAs) and for different
accelerator types [cite many]. The design is only more relevant today,
with the adoption of Compute Express Link (CXL), an open standard
cache-coherent interconnect. CXL aids in the construction of larger and
more diverse memory hierarchies in the data centre.

Tiered memory is an inevitable design of modern compute architectures.
It reduces the need for costly, fast memory such as SRAM, which is the
technology behind most caches, while maintaining good performance
[cite]. However, cost is not the only driver of this design. Smaller
caches have lower access latencies for microarchitectural reasons, e.g.
requiring fewer bits to index, or less complex tag-match logic. There
also fundamental physical limitations to do with how the on-die size of
the cache affects wire delays. For distributed systems, the physical
limitations become even more pronounced, one could reasonably measure
rack-to-rack optical fibre latency in hundreds of nanoseconds (hundreds
to thousands of times slower than effective CPU cache access latency).

While in many respects a good design, memory access patterns (the order
and timing of memory accesses for a specific workload) are often hard to
predict. As a result, certain programs will perform comparitively
poorly, as many of their accesses will be from lower memory tiers. The
functional units (parts of the CPU that do computation) are
undersupplied with data due to frequent pipeline stalls, and the program
throughput will be slow. It is the expected case that our data will be
in L1d, and so we call any access to L2 an "L1d miss". The penalty of a
miss is very high. L1d cache hits will resolve in 4-5 cycles, L2 in ~12
cycles and L3 in ~36 cycles. Worst of all is an access to DRAM, which
might take 200 cycles to resolve [cite]. The impact on throughput is
worse still as access to lower memory tiers put pressure on
microarchitectural units that do not expect frequent slow memory
accesses e.g. the store buffer or re-order buffer [cite].

Graph workloads form a vital component of many modern systems. Social
platforms use follower graphs to serve recommendations, navigation
engines traverse road networks for shortest-path queries, and search
engines may use graph-heavy page ranking algorithms to determine the
ordering of results. Today, graph workloads are especially relevant as
they form the basis of many machine learning algorithms.

Graph workloads are especially ill-suited to tiered memory designs. When
traversing a graph, you’d want the next sequence of nodes already
sitting in cache. But to know which nodes to promote to a faster tier,
you first have to fetch and read the current node’s data to discover its
neighbors.

```rust
struct Node<T> {
    data: T,
    adjacent: [Ptr<Node>],
}
```

Subjectively, procedural programming languages make it difficult to
avoid programming in a style that minimizes the miss-rate of graph
programs. Compilers can restructure programs to try hide the latency,
but they often fall short. The reason for this is two-fold. Firstly,
correctness is more important to a compiler than performance, so
practically they are limited to peephole optimizations of short scopes
and fail to find ways to optimize sufficiently aggressively. Secondly,
procedural languages give the user many guarantees about program
ordering, creating more instruction dependencies and more opportunities
for stalls. Consider the following example code that computes the sum of
all the nodes in a tree:

```rust
struct Node<T> {   
    data: T,
    // equivalent to `std::unique_ptr<Node<T>> left;` in C++
    left: Option<Box<Node<T>>>,
    right: Option<Box<Node<T>>>, }

fn sum(node: Option<&Node<i32>>) -> i32 {   
    match node {   
        // equivalent to a nullptr test in C++ 
        Some(node) => {   
            let sum_left = sum(node.left.as_deref());
            let sum_right = sum(node.right.as_deref());
            node.data + sum_left + sum_right }, // Rust implicitly returns
        None => 0, }}
```

Here, we must first fetch the `Node<i32>` in order to get its data and
child pointers. Then, we can do the same for the left child. Notice how
the program order requires that the left subtree be evaluated first
because of the strict evaluation order. While the Rust compiler can
reason that the addition of integers is commutative, and `Box` carries
semantic information that both children must be unique, there is no
clear optimization path to hide latency here that would not be seriously
confusing for a programmer (e.g. when debugging) and obviously
beneficial from the compiler's perspective. As of Rust 1.86, on the most
aggressive optimization target for x86-64, the compiler generates code
that suffers from the exact bad access pattern mentioned earlier; in
order to fetch the next data element, we must first completely resolve
the previous one.

Figure 2 shows that this can theoretically be avoided for this case with
a more optimal scheduling policy, assuming that multiple in-flight
memory requests can be supported by the hardware (which they typically
can). Notice that this schedule preserves the program semantics due to
the commutativity of modulo addition. This is explored further in later
sections of the report.

![alt text](image-1.png)

![alt text](image-2.png)

It is clear that tiered memory designs are pervasive across a wide range
of domains, from CPUs, to accelerators and even data centres.
Furthermore, we have shown that common programming paradigms make it
difficult to emit code that takes full advantage of the memory resources
in a tiered system. 

The goal of this research is to create clear programming constructs that
improve the performance of graph workloads on tiered memory
architectures. The scope allows for any modification of the programming
style or paradigm, e.g. through the addition of asynchronous operations,
or the requiring of the programmer to add access pattern hints to their
code. The optimization target of the research is limited to the x86-64
architecture on GNU/Linux. While we will only test on this architecture,
it is an aim of this project that what we learn is transferable to a
range of possible targets. The implementation scope is as wide as we
like, modification of the compiler, runtime or operating system are all
permitted; we are unlikely to make hardware changes. The success
criteria of this project is as follows:

1. **Primary**: Does this system show a clear performance improvement
   (throughput) for a variety of graph workloads, as compared to current
   implementations in procedural languages?

2. **Secondary**: Is the system intuitive and programmable for a wide
   range of graph workloads?

Many graph problems have been extensively researched and have excellent,
albeit very complex implementations in common systems languages. If the
system approaches the performance of these implementations, while still
providing a _general_ programming abstraction that can be used for a
wide range of graph workloads, it should be considered a huge success.
We do not believe this is an excessively optimistic goal.

## Related Work

We aim to create an effective runtime that improves the utilization of
tiered memory on a multicore system. Thus, we should analyse literature
covering software techniques to improve memory performance in these
tiered architectures. It is also equally important to analyse the
hardware mechanisms that are employed to improve memory performance, so
that our software can best exploit them.

### Overview

Broadly, the literature focuses on optimization policies that can be
split into a few categories. First, is the type of optimization, either
spatial or temporal. Spatial optimizations involve restructuring of the
data layout so that it utilizes the hardware's memory structure more
effectively. A classic example here is "array-of-structs" (AoS) vs
"struct-of-arrays" (SoA). An AoS approach is good for access patterns
that use the entire struct's data for batch operations, an SoA approach
is better for access patterns that use just a couple fields. 

```cpp
struct SoA {
    std::vector<ShortString> name;
    std::vector<uint32_t>    age;
    std::vector<Address>     address; };

struct AoSInner {
    ShortString name;
    uint32_t    age;
    Address     address; };

using AoS = std::vector<AoSInner>;
```

Temporal optimizations attempt to adjust the timing of memory accesses
so that they hit data _when_ it is in cache. An example would be
fetching data that we expect to be in cache in the future, or performing
loop interchange.

```cpp
for (size_t i = 0; i < array.size(); ++i) {
    use(array[i]);
    prefetchw(&array[i] + PREFETCH_DISTANCE); }
```

Second is the data that we use to motivate this optimization. There are
two methods for this, metrics-guided or programmer hints. Metrics 
guided optimization can be either done at compile time e.g. what is
done by LLVM [cite], or at runtime, e.g. what is done by JIT compilers
using performance counters [cite]. Programmer hints are explicit markers
from the programmer about some hidden state that they believe is likely.
For example, a programmer issuing a `PREFETCHW` explicitly is a *hint*
that they believe that the data they are prefetching has high temporal
locality.

The system we are aiming to build is based on the programming paradigm
of BoC [cite], the runtime of Microsoft's Verona project [cite]. BoC's
goal is to unify parallelism and coordination under a single primitive
that stays simple enough for programmers to use practically. BoC works
by decomposing the program's mutable state into isolated 'concurrent
owners' (cowns). Behaviors declare up fron the exact set of cowns that
they need.

```cpp
when (src, dst) { // single atomic transfer
    src.balance -= amt;
    dst.balance += amt; }
```

The runtime guarantess a specific ordering of these behaviors, and that
they will not deadlock. BoC shows a near-linear scaling up to 75 cores
and a 2-5x speedup over actor or lock-based basedlines. BoC is clearly
expressive in terms of parallelism, but we observe that its programming
paradigm also works well as a hint for temporal locality. The programmer
is explicitly notifying the runtime of what data it will use and for a
specific window. The runtime is then free to readjust the schedule of
those behaviors to optimize for locality. Thus, our primary 'hint' is
this programming mechanism.

### Compiler Guided Optimizations

Many implementations attempt to modify the compiler to improve the
performance. For example, Unal et al. revisit tiered-memory management
in the CXL era and argue for combining latency-reduction (page
migration) with latency-tolerance (prefetching) [cite]. Their prototype,
Linden, instruments the application at compile time to mark
"prefetchable regions" then lets a runtime decide—per region and per
core—whether to (1) migrate the pages, (2) tune software-prefetch
distance, or (3) throttle / disable hardware prefetchers when the slow
tier’s link is congested. Notably here, there is a good point to be made
about memory bandwidth limitations. A single core benchmark on LLC may
provide little value when considering how our runtime impacts the
bandwidth of that memory under load from many cores. LLC may have a 400
GiB/s bandwidth [cite], which is enough for 3.35 billion 128-byte sized
updates per second. This cannot be reached by just one core, but a
multicore can likely exceed this bandwidth.

For our purposes, there are cases where we cannot carry over optimizations
made by Linden. Mainly, Linden's benefits hinge on access patterns that
an offile compiler can characterize. Highly irregular pointer-chasing
as is common in graph workloads may yield low prefetchability ratios,
which would result in a fallback to classic migration and gain little.

Ainsworth & Jones build an LLVM pass that walks the SSA graph in loops,
finds an induction-variable whose future value can be computed cheaply,
and clones the address-generation instructions to issue a prefetch some
iterations ahead [cite]. The prefetch distance here is determined based
on the specific microarchitecture. They see only speedups across a range
of benchmarks for this strategy (10% to 170%). In-order cores see a much
greater speed improvement. 

Primarily interesting in the Ainsworth and Jones paper is (1) the
adaptive prefetch distance and (2) the drastic improvement on in-order
cores. The target of our research is x86-64, which is an ISA primarily
implemented by Intel's and AMD's microarchitectures [cite]. Both
companies produce CPUs that are aggressively out of order and
superscalar, so short prefetch distances really are unlikely to make a
difference for even relativley large workloads, if they see enough
locality to fit in L3. Furthermore, the adaptive prefetch distance is
important depending on both the microarchitecture and the DRAM module
that is being used, since DRAM modules vary greatly in their latency
[cite].

More basic strategies on predictable access patterns have been
implemented at the compiler level with great success, for example, as
part of the Intel C compiler [cite]. 

As mentioned in the introduction, compiler guided optimizations often
fail to be aggressive enough (see Ainsworth & Jones' 1.2x speedup on OOO
machines), because of the inherent dependent structure of many
procedural langauges. While regular imperative code can clearly be
instrumented either at compile time or runtime by to improve the
performance of relevant workloads (e.g SPEC)
[cite https://dl.acm.org/doi/pdf/10.1145/2133382.2133384], it is
beneficial to adjust the programming model to achieve greater benefit.

### Dynamic Rescheduling

Many memory technologies show batching to be a great way to amortize the
cost of memory accesses. For example, remote direct memory access (RDMA)
performs per byte considerably better for big chunks of data (4096
bytes) than it does for small data [cite]. Furthermore, as we have seen,
compiler-guided prefetching works best for scenarios where the access
pattern can be unrolled (Ainsworth & Jones) or are obvious (Intel's C
compiler). For workloads that resolve their access patterns dependently,
we cannot use this optimization so well.

Rescheduling is a common trick to increase throughput while 'hiding'
latency. Both of the above optimizations are possible using this
methodology. Consider Grappa, a software distributed shared memory (DSM)
implementation [cite]. Grappa uses a lightweight user-threading layer to
oversubscribe each core and every global address is "owned" by some
core. Remote accesses run by delegating a tiny closure (delegate) to
that owner, so the operation can execute locally and return only the
result. While stated as DSM, Grappa actually makes significant
modifications to the programming paradigm to be feasible. Notably, their
`delegate` closures are quite similar to BoC's `when` declarations.
Here, the 'cowns' are pointed-to data that the closure executes on,
instead of objects that need exclusive access. 

Grappa works by moving this closures to the 'home core' responsible for
the data. Its model wins in a few big ways

1. It does not need to constantly move data across caches. Instead, it
   reschedules the core that will be executing the closure operating on
   that data.

2. Atomicity is easy, because each core _owns_ the data it works on, so 
   mutation only happens on one core.

3. By assigning data to cores, you can avoid other problems associated
   with data ping-ponging like TLB thrashing.

4. Using lots of small units of work that are design to be executed 
   concurrently, Grappa can batch transfers to get a better latency per
   byte from a big RDMA request.

5. Most importantly, Grappa can tolerate the very high latency of memory
   accesses by *oversubscribing* cores with work to do. While memory
   operations are inflight, there is always more useful work.

Grappa has fantastic performance benefits for the kind of workloads it
targets (distributed, graph-like workloads). It achieves over 1
billion remote updates/sec, outperforms Spark by 10× (MapReduce),
GraphLab by 1.3×, and Shark by 12.5× with minimal code. Gains are
smaller for well-partitioned or bulk workloads. Grappa has a 
considerable performance *decrease* in some cases, likely the cost of 
its generality.

There is much to be learned from Grappa, as it targets a similar problem
to us. However, the primary concern is that Grappa is dealing with the
microsecond latency of RDMA [cite], whereas this research aims to
deliver at the nanosecond scale. This means that Grappa can make more
advanced scheduling decisions, or find more work to fill a batch
transfer with in a reasonable time frame (which is larger).

### Hardware 

[todo]

## Current Technical Experimentation

We have already completed extensive technical experimentation. This
involves a feasability study, as well as many experiments to identify
implementation bottlenecks.

The design ideas we explore are based on the behavior-oriented design
found in BoC. BoC is a programming paradigm where the programmer defines
behaviours that operate each on a set of objects, called 'cowns' (read
'cones'). There is a partial order implicit, based on the order the
blocks are declared. Behaviors are then scheduled with respect to this
partial order, so that each behaviour is guaranteed exclusive ownership
on its cown-set while running. Further guarantees are made, such as
deadlock-freedom. This method of defining concurrent code is already
very expressive and intuitive, as is shown by the BoC paper.

```cpp
when (a, b) {   
    /* we have exclusive access to a AND b */
    when (a) { /* only have access to a */ }
    foo(b); }
/* scheduled after the previous */
when (a) { /* behavior */ }
```

This model also encapsulates a great deal of what we need in order to
make our own implementation successful. Notably each behavior may access
only the cowns that are explicitly marked. This allows us to know
exactly a closure's working set. Consider our tree sum from the
introduction. We can transform this to use a boc-like model like below:

```rust
fn sum(node: Option<&Node<i32>>, total: &mut i32) {   
    match node {   
        Some(node) => {   
            when! (node.left, total) { /* b1 */
                sum(node.left.as_deref(), total); };
            when! (node.right, total) { /* b2 */
                sum(node.right.as_deref(), total); };
            node.data + sum_left + sum_right },
        None => 0, }}
```

In this instance, the runtime is aware that the working set for each
behavior is just the `total` and the left or right node. While this
setup guarantees that `b2` must execute after the `b1`, it defines no
ordering relation between the behaviors spawned by `b1` or `b2`, which
we shall call `b1.b1`, `b1.b2` and so on. For example, a possible
scheduling could see these behaviors in the order `b1`, `b2`, `b1.b1`,
`b2.b1`, `b1.b2` and `b2.b2`, for a tree of height two. Figure N shows a
diagram of the ordering relation.

![alt text](image-3.png)

### On a Single Core

Following this model, we create a baseline on a single-core which we can
use to develop a more complex system for a multi-core. The design aims
to hide latency by dynamically adjusting the schedule of behaviors. The
single core case is vastly simpler, as it eliminates the possibility of
race conditions. The scheduling policy is simple: When a behavior is
spawned...

1. schedule it on the back of a fixed-size deque
2. attempt to do one unit of work from the front of the deque

It is clear that this preserves the partial order I defined by example
earlier, a more formal proof would follow in the final report. This
simple design, when implemented carefully with respect to
microarchitectural bottlenecks, allows for significant speedup of a
range of programs. Each behavior has a context, made explicit by the
user; they must specify data that they believe to be in far memory and
data that should simply be available by copy when the closure is
executed. This is a solution that is based on _timing_ only, and does
not concern itself with placement at all. Figure N shows an example of
this tool in use. A macro-wrapper has also been made to allow slightly
more expressive code, but is omitted in this example. 

```rust
impl Node {
  fn bocmr_insert(&mut self, val: i32) {
    if val < self.val {
      match self.left {
        Some(ref mut left) => {
          bocmr::v2::When::exclusive(left.as_mut(), val, |left, val| unsafe {
            let val = val.acquire();
            (*left).bocmr_insert(val); }).schedule(&SCHED); }
        None => self.left = Some(Box::new(Node::new(val))),
      }
    } else {
      match self.right {
        Some(ref mut right) => {
          bocmr::v2::When::exclusive(right.as_mut(), val, |right, val| unsafe {
            let val = val.acquire();
            (*right).bocmr_insert(val); }).schedule(&SCHED); }
        None => self.right = Some(Box::new(Node::new(val))), }}}}

let mut tree = Node::new();
for i in gen_randoms(1000) {
    tree.bocmr_insert(i);
    // A
}
```

Even without a helper macro, the adjustment to the original program is
minimal. Compared to the original, we only mark that the behavior
captures both `left` and `val`. A closure taking those two values as
parameters is then defined, which executes at a later date. Besides the
ability to define behaviours, a `flush()` function is included to create
stricter happens-before relationships. For example, inserting a flush 
at `A` would ensure that each insertion finishes completely before the
next is scheduled.

This system has been benchmarked on both binary-search-tree and random
access programs. The binary search tree (BST) program inserts a sequence
of pseudo-random values into a binary search tree, then finds the sum of
the tree. The random memory access (RMA) program repeatedly probes a
buffer in pseudo-random locations, summing the result. Both cases are
examples of programs with terrible locality. We find that the BST
program sees a 0.6x to 2.5x speedup, depending on tree size, while the
RMA program ranges from 0.8x to 3x in its improvement using bocmr. These
findings are in line with optimistic expectations of performance --
small data structures that are completely resident in fast cache can
have their access latency hidden by out-of-order hardware, while
accesses to DRAM benefit greatly from rescheduling. We vary the size of
the deque to increase prefetch distance and find that for both programs,
prefetch distances of 20 to 80 behaviors all perform well. Prefetch
distances below 20 do not complete in time and stall Prefetch distances
above 80 have a higher likelihood of the data being evicted by the time
the behavior is executed, the data structure holding the behaviors'
contexts also puts more and more pressure on the cache.

We observe also that the relative performance of bocmr decreases when
handling data structures that do not fit in the L2 TLB. Performance
counter measurements indicate that this is due to the program being DRAM
bound. It is difficult to know for certain what the cause of this is,
but the following explanation seems reasonable: An access that misses
the TLB must perform a manual page walk. A manual page walk involves up
to five accesses to DRAM. Thus, the pressure on memory bandwidth is five
times higher. Consider that the best performing variant of RMA takes
879ms to complete 250 million writes of 64 bytes each. This is around
16.9GiB/s, which is 3.3x slower than the maximum throughput of the DRAM
on the test system (~56GiB/s). While the first one or two levels of the
page table are likely to be in cache, the remaining two are likely to
put further pressure on DRAM. We are unable to determine a placement
strategy for this program that alleviates pressure on the TLB. When
using huge pages, no performance impact can be noticed even for these
very large programs. It would seem pointless to try and do something
that the hardware is already completely capable of doing.

The conclusions and benefits of this experiment are as follows:

1. We have shown reasonable best case performance for this system on a
   single core. From this we can deduce a best-case performance increase
   of 3n where n is roughly the number of physical cores.
   
2. We have identified clear performance bottlenecks for test cases. For
   example, we have shown that huge pages must be used for many test
   programs, as well as having identified and resolved instruction level
   code generation optimisations.

## On a Multicore

Following from the success of the first implementation, a multicore
extension has been trialed. Much of what has been learned about the
performance of the first proves to be difficult to transfer to a
multicore CPU, so a suite of experiments has been performed, with the
results informing further development. A nice ideal would be to use the
same deque based scheduler as before, but with a multi-producer,
multi-consumer (MPMC) implementation. Then we can have all cores doing
work. Of course, the naive implementation of this breaks our ordering
semantics -- thread 1 might take some work off the mpmc deque, then get
put to sleep, thread 2 then takes further work off that has a
happens-after relation with the work thread 1 ought to be doing. A
system that avoids this is described as follows:

* Divide the memory space into slabs of 16KiB. The 'slab index' is
  computed as the address' value divided by the slab size. Pointers may
  only reference data that does not overlap slabs.
  
* Behaviors may now only reference a single object for writes. Other
  objects can be carried as part of the context for reads.

* Use one multi-producer, *single*-consumer deque per core, each
  behavior is allocated to a specific core based on a fair,
  deterministic function of the slab index (e.g. modulo the core count).

This makes the system slightly less programmable, but is overall still
expressive. The system performs very poorly even when many adjustments
are made to decrease cache-line contention. We find that it is throttled
by throughput issues. In particular, there are limits to how fast
one can transfer data from one core to another. In this case, the mpsc
deque is written to by one core, then read by another, which requires 
a cache-to-cache transfer (e.g. through L3). We can show the
microarchitectural bottlenecks through simple experiment. 

1. A core performs memory operations on a buffer smaller than the size 
   of L1 cache, then sets a flag. We call the memory operation done here
   the 'contention'. 
   
2. Another core waits for this flag to be set, then performs memory 
   operations on the same buffer. 

3. The test is repeated many times without flushing caches

|                                                      | no contention | load contention | store contention | load & store contention |
|:----------------------------------------------------:|:-------------:|:---------------:|:----------------:|:-----------------------:|
|                      load qword                      |     181ns     |      182ns      |      3424ns      |         3609ns          |
|                     store qword                      |     189ns     |      772ns      |      2892ns      |         2954ns          |
|             store qword, then load qword             |     197ns     |     1100ns      |      3258ns      |         3291ns          |
|             load qword, then store qword             |     199ns     |     1152ns      |      3485ns      |         3488ns          |
|                    load 8 qwords                     |     637ns     |      676ns      |      3371ns      |         3492ns          |
|                    store 8 qwords                    |     643ns     |     1036ns      |      3455ns      |         3326ns          |
|             prefetch, then load 8 qwords             |     904ns     |      865ns      |      3681ns      |         3504ns          |
|        load and store 8 qwords (interleaved)         |    1060ns     |     1613ns      |      3413ns      |         3629ns          |
| prefetch, then load and store 8 qwords (interleaved) |    1338ns     |     1532ns      |      3573ns      |         3637ns          |

The column header shows the type of contention. The type of contention
is significant -- for example, 'load' contention will not invalidate the
cache line in the other cache, but will update its state. 'store'
contention will likely not allocate in the contending cache's L1. The
row header shows the memory operation. No use of prefetching improves
any of these benchmarks. A summary of what can be learned from these
experiments is this 

* Contexts for the same destination must be shared on the same cache 
  line, and ideally only _after_ the cache line is completely full.

* Reducing context size by compression is likely a performance benefit.

* Basic prefetching strategies do not work, as they cannot snoop.

We show that use of the relatively new `CLWB` (cache-line write-back)
instruction can allow us to see benefits from prefetching. A simple
benchmark is devised: one core performs loads and stores of the buffer
sequentially*. Once it has finished, it records the time taken, then
sets a flag to indicate that the other core ought to take over. It busy
waits for the flag to be reset, before repeating this process. Thus, the
two cores ping-pong this buffer between their local caches. The mean of
the recorded times is found to be:

```
EXPERIMENT 1
C1 averaged 9615 cycles, 3.452µs
C2 averaged 9624 cycles, 3.455µs
```

C1 now executes CLWB after each cache line is no longer needed. C2
executes PREFETCHW instructions to data at a reasonable forward offset
as part of its load+store sequence. The times are now recorded as

```
EXPERIMENT 2
C1 averaged 10893 cycles, 3.909µs
C2 averaged 3312 cycles, 1.204µs
```

It should be noted that C2's time is now only marginally worse than what
can be expected for purely local operation on the buffer (~1.0μs). This
seems like great news, but if we mirror the operations on both cores, so
that they both perform the PREFETCHW and CLWB instructions, we get an
average time of

```
EXPERIMENT 3
C1 averaged 10178 cycles, 3.654µs
C2 averaged 10203 cycles, 3.664µs
```

This experiment is replicated on Tigerlake, Alderlake and Meteorlake
architectures. We cannot currently devise any reasonable theoretical
explanation for this discrepancy, but this is part of the ongoing
research. Interestingly, since the total runtime is lowest in EXPERIMENT
2, we are able to perform the `CLWB` for each odd cache-line index on
one core and each even cache-line index on the other, prefetching on
both. This gives us an overall increase in throughput of

```
EXPERIMENT 4
C1 averaged 6127 cycles, 2.209µs
C2 averaged 6068 cycles, 2.188µs
```

This gives us a lowerbound of ~9 cycles of runtime overhead per behavior
(push cold context, pop hot context). This assumes that a context is 32
bytes. If a context is compressed to 16 bytes, we see only 5 cycles
overhead per behavior. For certain graph workloads (e.g. the tree sum)
discussed in the introduction, this would have a benefit for workloads
that frequently miss L2, but not workloads that fit in L1/L2.

## Project Plan

Given that I have made considerable progress on both literature review
and feasibility studies and experimentation, I am confident that the
stated goals of the project can be achieved. The project now involves
refining the described design to ensure that it is semantically
expressive (specifically so that multiple pointers can be accessed) and
then implementing that design in-light of the completed experiments. I
suspect this will take no longer than one month. Then, the design should
be evaluated under a variety of test conditions. We will need to decide
on suitable baselines, GAP seems to be frequently used. This will likely
take another month. In the final month, the report can be written up.