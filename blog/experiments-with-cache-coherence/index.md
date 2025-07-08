Recently, I've been trying to figure out what kind of caching protocol
my CPU uses, and how that affects performance. It's interesting to think
about these things on a microarchitectural level and try and guess how
my CPU may be designed.

Throughout this article, I use Intel syntax for x86. I sometimes need
to specify the types of an operation too, so I use syntax from the docs.
`r32` would mean a 32-bit register, `m64` a 64-bit memory location and 
`imm16` would mean a 16-bit immediate operand.

# How Does `xchg` Work?

`xchg m64, r64` is a rather interesting instruction. It swaps a value
in memory into a register and the value in the register into memory. 
It has an "implicit lock" which basically just means it's atomic.

It can be used to implement a sequentially consistent atomic store. 
Needless to say, being atomic is not sufficient for sequential 
consistency. Here's a classic counter example

```rs
let i = 0;
let x = y = 0;
thread::spawn({
    
});
thread::spawn({

});
```

# What Does a Spinlock Tell Us About How Coherence is Implemented?

Let's consider two spinlock implementations. Both operate on a `bool`
and are unsafe. Usage would look something like this (all code blocks
are pseudocode).

```rs
let mutex = false;

thread::spawn({
    // ...
    lock(mutex);
    // critical section
    unlock(mutex);
    // ...
})
```

The `unlock()` method, in both cases is an atomic store with 
sequentially consistent semantics. All atomic operations shall have 
sequentially consistent ordering in our examples today. 

```rs
unlock(lock: BYTE PTR):
        xchg    al, BYTE PTR [rdi]
        ret
```

