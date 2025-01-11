# Oli's Little Guide to Competititve Programming

This is a guide to competitive programming idioms that I find in C++.

By the way, for competitive programming, I always prioritise in this 
order

1. Algorithm time complexity
2. Clarity of code
3. Brevity of code 
4. Execution speed within a complexity class

## Priority Queues

These come up a lot, occasionally, `std::priority_queue` is sufficient,
but it doesn't handle duplicates. What we often need instead is to
order items by a `priority()` function, but also not include any 
duplicate keys. Effectively, a map organised by the priority of the 
underlying value _not_ the key.

### DST

We need a `std::unordered_map` for our regular `key → val` associative 
array. 

```cpp
std::unordered_map<key_t, val_t> dict;
```

Then we maintain an ordered list of sets using `std::map`.

```cpp
std::map<prio_t, std::unordered_set<key_t>> prio;
```

### Insertion

Insertion is nice and simple:

```cpp
key_t k; val_t v; // insert this pair

prio[priority(v)].insert(k);
dict[k] = v;
```

### Removal

Removal is longer, but still easy

```cpp
key_t k; // erase this key 

if (dict.count(k)) {
    prio_t p = priority(dict[k]);
    auto &ks = prio[p];
    if (ks.size() == 1) {
        prio.erase(p);
    } else {
        ks.erase(k);
    }
    dict.erase(k);
}
```

### Popping

Popping is slightly more complex, but probably doesn't need its own
function still since the operation is obvious.

```cpp
// pop O(1)
auto &[p, ks] = *prio.begin();
key_t k = *ks.begin();
// notice this is the same as remove(p, k)
if (ks.size() == 1) {
    prio.erase(p);
} else {
    ks.erase(k);
}
dict.erase(k);
```

### Selecting the top ≤ N, without removing

This one's pretty obvious, too.

```cpp
std::vector<key_t> selected;
int i = 0;
for (auto &[_, ks] : prio) {
    for (key_t k : ks) {
        selected.push_back(k);
        if (++i == N) break;
    }
    if (i == N) break;
}
```

### Normal Case

What I would normally do is something like this

```cpp
void solution() 
{
    std::map<prio_t, std::unordered_set<key_t>> prio;
    std::unordered_map<key_t, val_t> dict;

    auto pq_erase = [&](key_t k) {
        if (!dict.count(k)) return;
        auto p = priority(dict[k]);
        auto &ks = prio[p];
        if (ks.size() == 1) {
            prio.erase(p);
        } else {
            ks.erase(k);
        }
        dict.erase(k);
    };
    
    // then i can derive further operations really fast, and my 
    // correctness only really depends on pq_erase() being correct
    auto pq_pop = [&]() {
        key_t k = *prio.begin()->second.begin();
        pq_erase(k);
        return k;
    };

    auto pq_insert = [&](key_t k, val_t v) {
        prio[priority(v)].insert(k);
        dict[k] = v;
    };
}
```