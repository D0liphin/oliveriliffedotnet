# `SsoString` in Rust

Small string optimisation for Rust. This works with both the new `allocator_api` and the old 
`GlobalAlloc` style allocation. If you want to use the new `allocator_api` set the `nightly` feature
to be active.

**Note that this does not mean, `SsoString` is generic over a global allocator yet, sadly.**

Small string optimisation is done only for strings of length 23 or less. The goal is for this to
be a drop in replacement for `std::string::String`.

Small string optimisation is only available on
`#[cfg(all(target_endian = "little", target_pointer_width = "64"))]`. Otherwise, `sso::String` is
just an alias for `std::string::String`.

I am in the process of implementing every `std::string::String` method for `sso::SsoString`, there
are declarations for every method, but most of them are just `todo_impl!()`s. One method, 
`as_mut_vec` is impossible... but who uses that anyway? 

All the methods I think are useful are implemented.

## SAFETY WARNING

I think due to use of `ptr::copy_non_overlapping` on `SsoString::clone`, we actually don't mark
the region as initalised, causing UB on some internal methods? I'm really not sure though. It only
happens in `long.as_mut_str().mask_ascii_lowercase()`... I'll have to investigate this more.

# Can I use this?

This is an imaginary conversation I am having with a person who will never exist, but I would
recommend strongly that you do not use this, unless perhaps you can guarantee that the exported type
is actually `std::string::String` hehe.

But seriously, although tested a little, it's not rigorously safe yet. Once I add debug assertions
about unsafe preconditions, I'll be more confident that it is safe to use.

For now, everything _appears_ to be safe, but nothing is as it seems in the land of `unsafe`!

## Usage

#### Basic String Operations

```rust
use sso::String;

let mut s = String::new();
s += "Hello, world!";
assert_eq!(&s, "Hello, world!");

let exclamation_mark = s.pop();
assert_eq!(exclamation_mark, Some('!'));
```

#### Automatic Upgrading between String Types

```rust
use sso::String;

let mut s = String::from("Hello, world!");
assert!(s.is_short());
assert!(!s.is_long());
assert_eq!(&s, "Hello, world!");

s += " My name is Gregory :)";
assert!(s.is_long());
assert!(!s.is_short());
assert_eq!(&s, "Hello, world! My name is Gregory :)");
```

Use of `is_short()` and `is_long()` functions should be prefaced with the following conditionl
compilation options:

```rust
#[cfg(all(target_endian = "little", target_pointer_width = "64"))]
```

#### Matching Internals

`sso::String` is best for code that doesn't do a lot of mutating. If you have a lot of mutations
and don't want to branch, you can match the internal string. For example

```rust
use sso::String;

let s = String::new();
// upgrade this string, note that any additional capacity will upgrade this string, because the 
// minimum capacity is 23.
s.reserve(100); 
#[cfg(all(target_endian = "little", target_pointer_width = "64"))]
{
    assert!(s.is_long());
    match s.tagged_mut() {
        TaggedSsoString64Mut::Long(long) => {
            for _ in 0..1000 {
                long.push_str("something");
            }
        }
        TaggedSsoString64Mut::Short(..) => unreachable!(),
    }
}
#[cfg(not(all(target_endian = "little", target_pointer_width = "64")))]
{ unimplemented!() }
```

This is a bad idea though. The API is unstable and it's no long replaceable by `std::string::String`
on non-optimized architectures.

## Why is your code weird?

A longer explanation to come. The idea is to uphold the invariants of the struct **at all times**,
instead of just when they might actually cause UB. Basically, trying to make `unsafe` code really,
really simple to prove safety.

That's why all my code has `# Safety` contracts and `SAFETY:` contract clearances at every `unsafe`
call-site (I think).

It's also why I use `len: UnsafeWrite<usize, 0>`. So that I cannot accidentally set the length to an
invalid value without using `unsafe`, which reminds me to clear the safety contract i might be
violating.

And why I can't `impl Drop`, because otherwise a semantically simultaneous write (not realy true,
but it's good enough) is impossible for `capacity` and `buf`. E.g. this code would become impossible
(I need to write both `capacity` and `buf` 'at the same time', so that `LongString` is never
invalid.

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

# Item-scoped Unsafe Code

This document is a first? draft. Things might not be worded as accurately as I would like, but I am
trying my best!

## Axiomatically Unsafe Operations

Rust defines "the only things that you can do in unsafe code" as (reordered):

- Dereference a raw pointer
- Access or modify a mutable static variable
- Access fields of unions
- Call an unsafe function or method
- Implement an unsafe trait

This definition is accurate, but it's more from a code semantics perspective, as opposed to a
soundness perspective. When I say that something is "axiomatically unsafe", that means that it can
_never_ be a safe operation without first checking preconditions.

For examlpe "calling an unsafe function or method" is not axiomatically unsafe, since you can prove
soundness without checking any preconditions.

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

I can prove this program is sound, without checking any preconditions. It is always sound to call
`puts`, in any form. Therefore although it is "unsafe" to call `puts`, it is _never unsound_. That
is to say: there is no way I can invoke undefined behaviour with a call to `puts` in an otherwise
safe environment.

This is not the case for what I would call "axiomatically unsafe operations". For example,
dereferencing a raw pointer always has a safety contract. We couuld define this as a function
(though it's not really) with a safety contract, but we could not define it as a function _without_
a safety contract, without that being unsound.

```rust
/// # Safety
/// - pointer is non-null
/// - pointer must be within the bounds of the allocated object
/// - the object must not have been deallocated (this is different from never having been
///   allocated. e.g. dereferencing a `NonNull::<ZST>::dangling()` is fine)
/// -
unsafe fn deref<T>(*const T) -> T;
```

There are ways we could restrict `T`, such that this operation would be valid, but that would be a
different operation.

Basically all compiler intrinsic unsafe functions are "axiomatically unsafe". For example,
`std::intrinsics::offset<Ptr, Delta>(Ptr, Delta)` as on operation cannot be defined without a safety
contract. However the safety contract that rust defines for this operation, is slightly different in
its scope.

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

**Important-ish note:** I'm actually very much unsure what these docs mean. The actual notes in
`core` are

> any further use of the returned value will result in undefined behavior

So is `offset(ptr, usize::MAX)` safe? It shouldn't produce a pointer that is out of the allocated
object if overflow is allowed, but I don't see why they wouldn't enforce the same rules as
`unchecked_add` here. For the purposes of this theoretical point, I will assume that overflow works
as you would expect.

So, we can read this as "it's not undefined behavior, but using the value afterwards _is_". This
makes it considerably different from the previous safety contract. Here, I can prove a call to this
function is sound, but I might not be able to prove that my whole program is sound after this:

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

We could structure the code differently and check if we invalidated the pointer every single time we
want to 'use' it. However, the point of this document is to prove that this kind of safety contract
is _never_ (well, almost never) required. We can do everything at what I call "item-scope" (with the
addition of `unsafe` fields, or the the allowance of a few exceptions to the rule, that we can
provide in a library).

## What is Item-scope?

not written this bit yet.