# How Enumerate Works

I was recently tasked with enumerating all possible trees. The trees can
be of any type -- regexes, binary trees etc. Specifically, I need to
be able to associate every integer with a unique tree. Here is the 
entire code for this

```hs
rdigits b 0 = [0, 0 ..]
rdigits b n = n `mod` b : rdigits b (n `div` b)

perms ns 0 = 0
perms ns d = sum $ nodePerms ns d

nodePerms ns d = (perms ns (d - 1) ^) . fst <$> ns

perm ns d i = n children
  where
    l = reverse $ zip (scanl (+) 0 (nodePerms ns d)) ns
    (g, (_, n)) = head $ dropWhile ((i <) . fst) l
    children = perm ns (d - 1) <$> rdigits (perms ns (d - 1)) (i - g)
```

`perm ns d i` takes some node constructors `ns`, a maximum depth `d` 
and an integer `i` and produces the same tree every time. It is 
guaranteed that for all `i`, the tree is different or does not exist.

## Digits

This is understood best by example. Take `549` that we wish to convert
to base-10 digits. `549 % 10` is `9` and `549 / 10` is `54`. It is
clear, we can define a recursive function based on the update rule
`digits(n / base) :+ n % base`.

```hs
rdigits b 0 = [0, 0 ..]
rdigits b n = n `mod` b : rdigits b (n `div` b)
```

This function returns the reversed digits, since we later do not care
about the order the digits are in. It is also quite convenient that the
digits are ordered least-significant to most significant, because it
allows us to concatenate an infinite list of `0`s onto the end.

## Perms 

All parameters `ns` contain a list of "node constructors". A node 
constructor is a tuple `(childCount, constructor)`. `childCount` 
naturally describes how many children the node has. `constructor` 
is a function that takes a list of child nodes and constructs a node 
with these as children.

The function `perms` takes a list of node constructors and a maximum 
depth and returns the number of possible permutations up to this depth.

```hs
perms :: [(Int, [a] -> a)] -> Int -> Int
```

To compute it, we consider the number of permutations for a tree rooted
at node `p`, `∀p ∈ ns`. The sum of all these is the result. Of course,
there are no trees of depth `0`.

```hs
perms ns 0 = 0
perms ns d = sum $ nodePerms ns d
```

The helper function `nodePerms` maps each node constructor `p` to the 
number of permutations of trees rooted at `p`. Each child can have 
`perms ns (d - 1)` children, so the total permutations is 
`perms ns (d - 1) ^ p.childCount`. Recall that the child count is the 
`fst` element of the tuple.

```hs
nodePerms ns d = (perms ns (d - 1) ^) . fst <$> ns
```

A fun property here is that for `d = 1`, we are effectively counting 
the number of nodes with 0 children, or all the leaf nodes. A previous
implementation considered leaf and branch nodes differently, but this 
property of exponents comes in very handy here!

## Perm

Recall the original task of ordering all possible tree permutations
and accessing the `i`ᵗʰ one. Well, what should be the `i`ᵗʰ permutation?
This is best understood by example. Consider the nodes used in regular
expressions. You do not need to know what they do, but comments are 
provided.

```hs
data Reg 
    = Eps         -- the empty string ε
    | Sym Char    -- a single character
    | Seq Reg Reg -- a sequence of two regular expressions
    | Alt Reg Reg -- either of two regular expressions
    | Rep Reg     -- a regular expression, repeated at least 0 times
```

Consider the alphabet `{'a', 'b'}`. For trees up to depth 3, we can 
generate the number of permutations for trees rooted at each of these 
nodes. For `Eps`, this is obviously just `1`, but the others can grow 
double-exponentially.

```plaintext
| tree root | # trees with this root |
|:---------:|:----------------------:|
|    Eps    |           1            |
|  Sym 'a'  |           1            |
|  Sym 'b'  |           1            |
|    Rep    |           24           |
|    Alt    |          576           |
|    Seq    |          576           |
```

We could say that tree `0` starts with `Eps`, tree `1` starts with 
`Sym 'a'`, tree `10` starts with `Rep`, tree `700` starts with `Seq`
etc. etc. One can see this is related to the prefix sum. In Haskell,
this is

```hs
scanl (+) 0 (nodePerms ns d)
```

The prefix sum for the above case is `[0,1,2,3,27,603,1179]` Consider we
take the `300`ᵗʰ term. This is the `300 - 27`ᵗʰ term of `Alt`. We
acquire the node constructor `n` and the previous group start index `g`
like this

```hs
l = reverse $ scanl (+) 0 (nodePerms ns d) `zip` ns
(g, (_, n)) = head $ dropWhile ((i <) . fst) l
```

We go in reverse, selecting the first one that is greater than or 
equal to `i`. The associated node is zipped with a sheer of one to the
left, so we also have the correct node constructor. For the above 
example, `l` is 

```
[(0, Eps), (1, Sym 'a'), (2, Sym 'b'), (3, Rep), (27, Alt), (603, Seq)]
```

So, we want the `i - g`ᵗʰ child of `Alt`. We can get this by considering
each child of `Alt` as a digit in a base-`perms ns (d - 1)`
representation of `i - g`. The intuition for this is that each child has
`perms ns (d - 1)` permutations. We use our function from earlier,
`rdigits`. This gives an index for the tree of each child, which we can
map to a concrete permutation.

```hs
children = perm ns (d - 1) <$> rdigits (perms ns (d - 1)) (i - g)
```

Finally, we construct the node with the node constructor acquired 
earlier, `n`.

```hs
perm ns d i = n children
```

To actually use the code, we have to define our node constructors and 
whatnot...

```hs 
data Tree
  = L1
  | L2
  | B1 Tree Tree
  | B2 Tree Tree
  deriving (Show)

ns =
  [ (0, const L1),
    (2, \(l : r : _) -> B1 l r),
    (2, \(l : r : _) -> B2 l r)
  ]
```

## Issues

The issue is that the number of permutations of a tree grows
double-exponentially with the depth. As a result, the algorithm runs in
worse than exponential time (but not double-exponential) with respect to
the tree depth. I only managed to compute the values for trees of depth
12 before I got too bored to wait. There's no a lot to do about this,
since the task requires compactly assigning an integer to every tree.