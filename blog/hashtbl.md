# Yet Another Hashtable

This article details how my hashtable implementation evolves over time.
First, I will detail my high-level logic and version 0.1.0. Hopefully
things will get a lot faster over time.

The hashtable is being built as part of a hashtable drag-race. The
participants are `std::unordered_map`, FFHT (by 
[this guy](www.rubensystems.com)) and me. Mine is just called `HashTbl`.

## High-level Design

My table is a probing table, 0.1.0 currently does linear probing. 
Entries are stored as `(key, value)` pairs in a big pool, with only one 
allocation for the lifetime of the table.

## Memory Layout 

The single allocation is laid out like this:

```plaintext
 ┌───────────────────┐
 │                   │
 │    metadata       │
 │                   │
 ├───────────────────┤
 │                   │
 │    data           │
 │                   │
 └───────────────────┘
```

Very innovative. The `data` section is just an array of `Entry`s. Where
an `Entry` is 

```cpp
struct HashTbl<Key, Val>::Entry {
    size_t hash; // precomputed hash
    Key key;
    Val val;
};
```

The metadata section ought to store some kind of information that lets
us figure out what entries are valid. For this, we use an array of 
bytes, we will call this `ctrlbytes`. Essentially, we have this set up
such that `ctrlbytes[i]` stores a byte of metadata about `entries[i]`.

Each byte can be either `CTRL_EMPTY` (the slot is free, no need to 
probe), `CTRL_DEL` (the slot is deleted) or stores 7 bits of hashcode
so that we can quickly check if we should even bother looking in the 
main buffer. This is obviously inspired by swisstable's SIMD lookup,
which lots of hashtables use now (e.g. 
[`std::collections::HashMap`](https://doc.rust-lang.org/std/collections/struct.HashMap.html)
).

## Lookup

We have one function that does all the heavy lifting here -- 
`get_slot()`.

```cpp
bool get_slot(size_t h, Key const &key, Entry *&slot, char *&ctrl_slot)
```

This function just returns a pointer to the slot where we can put an 
entry with key `key`, and tells us if that slot is empty or already
occupied. From this, we derive both `insert()` and `get()`. 

Ctrl bytes are arranged in aligned chunks. These chunks currently are 16
bytes wide. Typically, we would iterate over each byte in the chunk,
but hopefully doing a few SIMD instructions will let us do this faster.
What's exciting is I made the whole thing generic over a chunk size and 
an underlying generic SIMD vector type... Incoming comparison of 
different vector sizes. My hardware supports AVX-512, so that should be
fun.

The only SIMD instruction we need to understand is 
`simd<vector_t>::movemask_eq`.

```cpp
template <typename T> struct simd
{
    using movemask_t = typename usimd<T>::movemask_t;

    /**
     * Construct a mask, where each high bit represents an equality match
     * of the byte `b`.
     */
    static movemask_t movemask_eq(T v, char b)
    {
        T const splat = usimd<T>::splat_i8(b);
        T const eqmask = usimd<T>::cmpeq_i8(splat, v);
        return usimd<T>::movemask_i8(eqmask);
    }
};
```

As the docs above say, we are constructing a bitmask, with 1 bit for 
each byte in the vector type, where the bit at index `mask[i]` is `1` 
iff the byte at index `v[i]` is equal to `b`. E.g. a `i8x4` vector type
would map (remember, little-endian)

```plaintext
simd<i8x4>::movemask_eq(0xab12ab34, 0xab) -> 0b0101
```

For SSE, this is done as follows:

1. Splat `b` 

```

```