# How Enumerate Works

I have recently been tasked with enumerating every single possible tree
for arbitrary branch types. I produced some rather elegant Scala in the
end and wanted to write a little article about it. Back to the 
hashtables soon, hopefully.*

## Digits

First, we define a function `digits(base)(n)` that converts the number
`n` into a list of digits of the specified base. For example, 
`digits(10)(167)` would produce `[1, 6, 7]`. We also specify a `minLen`
parameter, that pads the front of the list with `0`s, should we need.
This is useful in the case of `digits(_)(0)` which produces the empty
list. 

```hs
digits base minLen n = (reverse $ f n 0, base) where
  f 0 len = replicate ((minLen - len) `max` 0) 0
  f n len = (n `mod` base) : f (n `div` base) (len + 1)
```

This is not super interesting. It is understood best by example. Take
`549` that we wish to convert to base-10 digits. `549 % 10` is `9` and
`549 / 10` is `54`. It doesn't take a genius to see that we can define
a recursive function based on `digits(n / base) :+ n % base`.

## Number of Permutations for a Tree

First, we define the types of nodes that exist in the tree. A node is 
defined by the number of children it takes. Leaves take `0`. This is 
important for our calculations.

The number of permutations up to depth `d` is the sum of the number of
permutations for every parent node.

```scala
case class INodeBundle[T](val nodes: Vector[INode[T]] = Vector()) {
  def perms(d: Int): BigInt = nodePerms(d).sum
}
```

The number of permutations, assuming a parent node is `0` if the tree is
of depth `0`.

The number of permutations, for depth `d` is dependent on the number of
children for that node. Each child has `perms(d - 1)` permutations. The
parent therefore, has `perms(d - 1) ** childCount` permutations. In the
below code `n._1` is the number of children for the node `n`.

```scala
def nodePerms(d: Int): Vector[BigInt] = d match {
  case 0 => Vector()
  case d => nodes.map(n => perms(d - 1).pow(n._1))
}
```

In the case where `d = 1`, `perms(d - 1) = 0`. `0^n` is `0` for all `n`
except for `0`. Leaves have `0` children, so we are effectively counting
the number of leaves. Neat.

We can also think of this algorithm as creating a tree and at each 
branch, we either terminate it with a leaf or we choose a branch and 
continue.

## Specific Permutation

We are given a number `i` and we wish to return the `i`th permutation of
our tree up to depth `d`. We can do this by considering how many 
permutations exist for each node. For example, we are creating trees for
regular expressions. Below is the definition for all the nodes we need 
for regular expressions. Consider an alphabet `{a, b}`. Our leaf nodes
are therefore `Eps`, `Sym('a')` and `Sym('b')`.

```scala
sealed trait Reg
case object Eps                  extends Reg
case class Sym(c: Char)          extends Reg
case class Seq(r1: Reg, r2: Reg) extends Reg
case class Alt(r1: Reg, r2: Reg) extends Reg
case class Rep(r: Reg)           extends Reg
```

For trees of depth 3, we get the following counts for trees starting 
with different nodes

```plaintext
| tree root  | # trees with this root |
|:----------:|:----------------------:|
|   `Eps`    |           1            |
| `Sym('a')` |           1            |
| `Sym('b')` |           1            |
|   `Rep`    |           24           |
|   `Alt`    |          576           |
|   `Seq`    |          576           |
```

Let's say we want tree `0`. We could say this is `Eps`. Tree `1` could
be `Sym('a')`. Tree `13` would be something starting with `Rep`. Tree
`700` would be something starting with `Seq` etc. Let's take tree `750`
as an example. This is tree `147` of `Seq`. 

We can describe the 147th tree of `Seq` by converting `147` to a number
with `Seq.childCount` digits, base `perms(d - 1)`. This counts up the 
trees on the rhs of `Seq` first, then carries over to the lhs and 
continues to count up the right some more. 

Here's the full code for this

```scala
def perm(d: Int, i: BigInt): T = {
  // Select the node where `i` would be 
  val groups = nodePerms(d).scanLeft(BigInt(0))(_ + _)
  val nodeIndex = groups.indexWhere(i < _) - 1
  val node = nodes(nodeIndex)
  // Compute which index _within_ `node` `i` would be
  val j = i - groups(nodeIndex)
  // Split up `j` into digits
  val children = digits(perms(d - 1), node.childCount)(j)
    // ...and choose the permutation corresponding to the digit
    .map(perm(d - 1, _))
  // Construct the node and return it
  node.construct(children)
}
```

All done! 

## Issues

The issue is that the number of permutations of a tree grows
double-exponentially with the depth. As a result, the algorithm runs in
worse than exponential time (but not double-exponential) with respect to
the tree depth. I only managed to compute the values for trees of depth
12 before I got too bored to wait. There's no a lot to do about this,
since the task requires compactly assigning an integer to every tree.

*This whole article uses Scala at the moment, but I wouldn't mind 
updating everything to Haskell when I get a chance.