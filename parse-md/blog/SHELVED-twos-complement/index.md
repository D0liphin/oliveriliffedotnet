# Two's Complement

It is difficult to prove by intuition various properties of two's
complement. This article aims to show proof for `-n` being equivalent to
`++(~n)` and `n + m` being identical to unsigned integer addition.

## What is two's complement?

It is simply the association of each binary index with numbers in a
special order. Specifically, we start at `0`, then go up to
`2^(N - 1) - 1` and then go from `-2(N - 1)` down to `-1`. So for
`N = 4`.

```plaintext
0000 : 0
0001 : 1
0010 : 2
0011 : 3
0100 : 4
0101 : 5 
0110 : 6
0111 : 7  (2^(N - 1) - 1)
1000 : -8 (-2^(N - 1))
1001 : -7
1010 : -6
1011 : -5
1100 : -4
1101 : -3
1110 : -2
1111 : -1
```

This arrangement _happens_ to have some nice properties. I don't think
they are completely obvious, but hopefully this article helps develop an
intuition for them.

## Easy negation

Negation in two's complement is just `++(~n)`. However, what we should 
really be focusing on is that the bitwise-`NOT` of a binary value, gives
us the binary value in the "mirror position". See the below table for 
an example.

```
 a = 000
 b = 001
 c = 010 
 d = 011
~d = 100
~c = 101 
~b = 110
~a = 111
```

The trick here is to look at each column from most-significant to least
significant.

```
0 0 0
0 0 1
0 1 0 
0 1 1
-----
1 0 0
1 0 1 
1 1 0
1 1 1
```

Obviously, all columns besides the most-significant are identical in the
top and bottom sections. Then, each column is `2ᴺ` `0`s, followed by 
`2ᴺ` `1`s. So we only need to prove that `NOT` of this sequence is 
equivalent to its reverse.

First, a definition for `rev`, which you will have to accept is correct
by your own genius intuition:

```hs
rev [a, b] = [b, a]
rev xs = rev sndHalf ++ rev fstHalf 
  where (fstHalf, sndHalf) = splitAt (length xs `div` 2) xs
```

Next, let's define the not of a sequence of `2ᴺ` `0`s, followed by 
`2ᴺ` `1`s, repeated `2ᴹ` times. 

```hs
bnot [zro, one] = [one, zro]
```

This is the shortest possible sequence we will deal with. As you can 
see, it is simply the definition of `NOT`. 

```hs
bnot xs = bnot sndHalf ++ bnot fstHalf 
  where (fstHalf, sndHalf) = splitAt (length xs `div` 2) xs
```

Because of the restrictions of the sequence, either

- `sndHalf == fstHalf`
  - Both are `2ᴺ` `0`s, `2ᴺ` `1`s, but this time `2ᴹ⁻¹` times
  - And thus the flipping of these two halves should have no effect
  
- `fstHalf` is all `0` and `sndHalf` is all `1`. 
  - And thus the flipping of these halves is equivalent to the bitwise
    `NOT` of the full list. 

Cool, so now we know why negation works like it does!

## Easy Addition

One of the benefits of two's complement is that addition of two numbers
works the same regardless of the sign. Let's investigate all four 
possibilities:

### positive + positive

This is obviously the same because both numbers are represented the 
same as regular unsigned binary numbers.

### positive + negative

Consider this as a positive shift from the negative number, we start on
the negative number and if we overflow, we wrap around to `0` and keep 
going up.

```
000 0
001 1
010 2 <- overflows to here
011 3
100 -4 (+ 6)
101 -3
110 -2
111 -1
-4 -> -3 -> -2 -> -1 -> 0 -> 1 -> 2 ...
```

### negative + negative

This is the only tricky case. But consider it like this...

A full overflow all the way back round to our number is `+ 1000`. An 
overflow one less than that would be `111`, two less would be `110` and 
so on. So the addition of a negative `-n` will overflow us exactly `n`
less than a full rotation, shifting us "up" diagramatically on the 
example diagram. Notice how every valid upward shift on the diagram is
also equivalent to a decrement... very cool.

