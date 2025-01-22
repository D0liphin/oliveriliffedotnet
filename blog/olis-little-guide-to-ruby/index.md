# Oli's Little Guide to Ruby

This is about the 1986 HDL Ruby, made by [Mary Sheeran](https://www.cse.chalmers.se/~ms/).

## Basic Relations

- Ruby defines blocks with a domain and range.
- Domain variables are read bottom-to-top, left-to-right and are on the
  left or top of the block.
- Range variables are read left-to-right, bottom-to-top and are on the
  bottom or right of the block.
- Blocks might perform computation.

![A square labelled lowercase f has an incoming arrow from the left 
  and outgoing arrow to the right.](image.png)

In ruby we can describe this as follows:

```
f = VAR a . a $rel a.
```

If `f` performs a function `g` on its input, we can write:

```
f = VAR a . a $rel (`g` a).
```

`f` can be used as a function. For example, it is valid to declare a 
new block `e == f == g`: 

```
e = VAR a . a $rel (`f` a).
```

If we have multiple range/domain variables.

![As before, but now with two incoming/outgoing arrows on both sides of 
  f](image-1.png)
  
```
f = VAR a b . <a, b> $rel <a, b>.
```

Or, with computation:

```
f = VAR a b . <a, b> $rel <(`inc` a), (`inc` b)>.
```

Tuples/lists are defined with angle brackets. 

The left/right sides of `$rel` can be either inputs or outputs.

```
f = VAR a b . <(`inc` a), b> $rel <a, (`inc` b)>.
```

![f has a left-incoming wire and a right-outgoing wire, but also two 
  arrows flowing in the other direction, underneath the left-to-right 
  arrows](image-2.png)

With `VAR` we declare the inputs, in this case `a` and `b`.

## Running things

This is dependent on your compiler. You will pass your `.rby` file into
a compiler and execute it with another program and some inputs. These 
are passed to the `current` block in your program. For me this looks 
like:

```
rc mycode.rby && re "a b"
```

You can pass symbols for symbolic execution, or concrete values.

## One input, lots of input wires

`$wire` is a shorthand for `$rel` without explicit inputs. 

Consider 

```
id = a $wire a.
```

Obviously, `` `id` 5 `` is just `5`. But what about `` `id` <5, 5> ``? 
This is `<5, 5>`. Consider a more useful example.

```
fork = a $wire <a, a>.
```

`` `fork` a `` is `<a, a>`, and `` `fork` <a, a> `` is 
`<<a, a>, <a, a>>`.

## Defining Blocks Without `$rel`

We can sequence (compose) blocks with `;`. E.g. `f ; g` 

![Two blocks labeled f and g are connected in sequence. g is positioned
to the right of f. An incoming arrow from the left enters f. From the
right of f, an outgoing arrow enters the left-side of g. g has a single
outgoing arrow to the right.](image-3.png)

We can define blocks in parallel with `[]`. E.g. `f = [id, inc]`.

![An outer block f with two inputs and two outputs surrounds the inc and
id blocks from which it is composed](image-4.png)

A more complex example might be the following

![An adder and a multiplier are both supplied the same two inputs
through forked wires. The entire system has two inputs and two outputs,
one representing the output of the multiplier and one the
adder.](image-5.png)

The 4-input part after the forking is clearly 

```
<<a, b>, <a, b>> ; [mult, add]
```

`<<a, b>, <a, b>>` is equivalent to `fork <a, b>`. Thus the entire 
block is representable as

```
f = fork ; [mult, add].
```

Here's another example 

```
add3 = [id, add] ; add.
```

## Higher-order Functions

You can pass arguments to your functions. Here's an example

```
fst R = [R, id].
```

`R` is a block, so is `id`. Thus `fst R` is a 2-input, 2-output block.
A flipped version, `snd` also exists. We could therefore define `add3`
like so:

```
add3 = fst add ; add.
```

We could do `map` too. But we need to specify the input vector size.
We'll learn how to write it ourselves later.

```
squared n = map n (fork ; mult).
current = squared 3.
```

```sh
$ re "1 2 3"
    0 - <1,2,3> ~ <1,4,9>
```

## Inverse

The inverse of a component is defined in the prelude. We write the 
inverse of `R` as `R^~1`. 

![A diagramatic representation of the inverse function](image-7.png)

```
R^~1 = x $wire <a, a, x> ; [id, R, id] ; <b, y, y> $wire b.
```

`pi1` and `pi2` are common selection operators.

```
pi1 = <a, b> $wire a.
pi2 = <a, b> $wire b.
```

They are also frequently inverted. 

## Constants 

Ruby has constant values. For example, if we wish to ignore the input
to a block and output a constant instead.

```
fourtytwo = VAR x . x $rel 42.
```

A constant is also a component that has a an output on the range and the
domain.

![A block with '42' inside has an outgoing arrow on both its left and
right sides.](image-6.png)

This component can be described as a function of a constant with the
tools we have discussed. But a component with a single output and no
input does not make sense in Ruby.

```
splitIgnore x = VAR a . <a, x> $rel x.
const x = pi2^~1 ; splitIgnore x.
```

Diagrams just show what circuit things represent. In this case, the 
diagram is not a circuit you would ever build.

![A diagramatic representation of const 42, with internal 
components](image-8.png)

