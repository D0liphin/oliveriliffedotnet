# Item-scoped Unsafe Code

This document is a first? draft. Things might not be worded as
accurately as I would like, but I am trying my best!

## Axiomatically Unsafe Operations

Rust defines "the only things that you can do in unsafe code" as (reordered):

- Dereference a raw pointer
- Access or modify a mutable static variable
- Access fields of unions
- Call an unsafe function or method
- Implement an unsafe trait

This definition is accurate, but it's more from a code semantics
perspective, as opposed to a soundness perspective. When I say that
something is "axiomatically unsafe", that means that it can _never_ be a
safe operation without first checking preconditions.

For examlpe "calling an unsafe function or method" is not axiomatically
unsafe, since you can prove soundness without checking any
preconditions.

```rust
/// # Safety
/// always safe
unsafe fn puts(s: &str) {
    println!("{}", s);
}

// SAFETY: always safe
unsafe {
    puts("Hello, world!");
}
```

I can prove this program is sound, without checking any preconditions.
It is always sound to call `puts`, in any form. Therefore although it is
"unsafe" to call `puts`, it is _never unsound_. That is to say: there is
no way I can invoke undefined behaviour with a call to `puts` in an
otherwise safe environment.

This is not the case for what I would call "axiomatically unsafe
operations". For example, dereferencing a raw pointer always has a
safety contract. We couuld define this as a function (though it's not
really) with a safety contract, but we could not define it as a function
_without_ a safety contract, without that being unsound.

```rust
/// # Safety
/// - pointer is non-null
/// - pointer must be within the bounds of the allocated object
/// - the object must not have been deallocated (this is different from never having been
///   allocated. e.g. dereferencing a `NonNull::<ZST>::dangling()` is fine)
/// -
unsafe fn deref<T>(*const T) -> T;
```

There are ways we could restrict `T`, such that this operation would be
valid, but that would be a different operation.

Basically all compiler intrinsic unsafe functions are "axiomatically
unsafe". For example, `std::intrinsics::offset<Ptr, Delta>(Ptr, Delta)`
as on operation cannot be defined without a safety contract. However the
safety contract that rust defines for this operation, is slightly
different in its scope.

```rust
/// Note: in reality, the type of `Ptr` is enforced by the compiler when we use stabilized 
/// methods. So we ignore this. 
/// 
/// # Safety 
/// - `Ptr` and `Ptr + Delta` must be either in bounds or one byte past the end of an allocated 
/// object 
/// - if the following invariants are not upheld, further use of the returned value will result in 
///  undefined behavior: 
///  - `Ptr` and `Ptr + Delta` must be within bounds (isize::MAX) 
///  - `Ptr + Delta` must not overflow unsafe fn
fn offset<Ptr, Delta>(Ptr, Delta) -> Ptr;
```

**Important-ish note:** I'm actually very much unsure what these docs
mean. The actual notes in `core` are

> any further use of the returned value will result in undefined behavior

So is `offset(ptr, usize::MAX)` safe? It shouldn't produce a pointer
that is out of the allocated object if overflow is allowed, but I don't
see why they wouldn't enforce the same rules as `unchecked_add` here.
For the purposes of this theoretical point, I will assume that overflow
works as you would expect.

So, we can read this as "it's not undefined behavior, but using the
value afterwards _is_". This makes it considerably different from the
previous safety contract. Here, I can prove a call to this function is
sound, but I might not be able to prove that my whole program is sound
after this:

```rs
let n: *const i32 = alloc::<i32>();
if random::<bool>() {
    // assignment is (probably) unsound actually...
    n = unsafe {
        // sound operation
        offset(n, usize::MAX);
    };
}
// unsound. Maybe UB, who knows?
println!({n:?});
```

We could structure the code differently and check if we invalidated the
pointer every single time we want to 'use' it. However, the point of
this document is to prove that this kind of safety contract is _never_
(well, almost never) required. We can do everything at what I call
"item-scope" (with the addition of `unsafe` fields, or the the allowance
of a few exceptions to the rule, that we can provide in a library).

## What is Item-scope?

not written this bit yet.

## Implications

A longer explanation to come. The idea is to uphold the invariants of
the struct **at all times**, instead of just when they might actually
cause UB. Basically, trying to make `unsafe` code really, really simple
to prove safety.

That's why all my code has `# Safety` contracts and `SAFETY:` contract
clearances at every `unsafe` call-site (I think).

It's also why I use `len: UnsafeWrite<usize, 0>`. So that I cannot
accidentally set the length to an invalid value without using `unsafe`,
which reminds me to clear the safety contract i might be violating.

And why I can't `impl Drop`, because otherwise a semantically
simultaneous write (not realy true, but it's good enough) is impossible
for `capacity` and `buf`. E.g. this code would become impossible (I need
to write both `capacity` and `buf` 'at the same time', so that
`LongString` is never invalid.

```rust
/// free the buffer of this string, setting the `len` and `capacity` to `0`
pub fn free(&mut self) {
    let capacity = self.capacity();
    *self = unsafe {
        Self {
            // SAFETY: 0 always satisfies len's invaraints
            len: UnsafeWrite::new(0),
            // SAFETY: the buffer is dangling and the capacity is 0, which is a valid
            // state for LongString
            capacity: UnsafeWrite::new(0),
            buf: UnsafeWrite::new(
                self.buf
                    .own()
                    // SAFETY: capacity is the exact size of the buffer
                    .dealloc(capacity)
                    .expect("should be the exact capacity"),
            ),
        }
    };
}
```