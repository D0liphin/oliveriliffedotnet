# Rust is FP?


I often see people claim that Rust is basically "fast FP" (in the cases
where FP is actually more expressive than imperative). This is a short
article comparing the FP expressiveness of various languages. I'll use
quicksort for this.

## Haskell

Pretty hard to beat haskell here. First class support for filters is
nice, so we can do something like this...

```
quicksort [] = []
quicksort (x : xs) =
  quicksort [y | y <- xs, y < x]
  ++ [x]
  ++ quicksort [y | y <- xs, y >= x]
```

That being said, I actually prefer this

```
quicksort [] = []
quicksort (x : xs) = f (< x) ++ [x] ++ f (x <=)
  where f p = quicksort (filter p xs)
```

It's just so clear how the algorithm works just by looking at that line.
`f (x >) ++ [x] ++ f (x <=)`. "The stuff smaller than x, then x, then
the stuff bigger than x". So clean.

## Python

Python's got some new features since 3.10 that make this a lot easier.
It's pretty clean (if, in the normal python fashion a little spread
out). We have to flip the match statement around here for type
inference.

```
def quicksort(xs):
    match xs:
        case [y, *ys]:
            f = lambda p: quicksort(list(filter(p, ys)))
            return f(lambda x: x < y) + [y] + f(lambda x: x >= y)
        case _:
            return []
```

## JavaScript

JavaScript is surprisingly clean here. You can get away with not using
any braces at all, becuase it's so relaxed with... well, everything.
This makes it a little trickier though... I overlooked the potential of
the first element being falsey, so we have to do this proper equality
check...

```
const quicksort = ([x, ...xs]) => x !== undefined
    ? [...quicksort(xs.filter(y => y < x)), x, ...quicksort(xs.filter(y => y >= x))]
    : []
```

The drawback here is that a list with `undefined` in it doesn't sort
properly. If we want that to work, we have to do this. It's an easy fix,
but sadly the original elegance is lost slightly.

```
const quicksort = ns => {
    if (ns.length == 0) return [];
    const [x, ...xs] = ns;
    return [...quicksort(xs.filter(y => y < x)), x, ...quicksort(xs.filter(y => y >= x))];
}    
```

## Rust

Ok, so let's try Rust. 

```
fn quicksort&lt;T: PartialOrd + Clone&gt;(xs: &[T]) -&gt; Vec&lt;T&gt; {
    fn qs&lt;'a, T: PartialOrd&gt;(xs: &[&'a T]) -&gt; Vec&lt;&'a T&gt; {
        match *xs {
            [x, ref xs @ ..] =&gt; {
                let filterxs = |p: &dyn Fn(&&T) -&gt; bool| {
                    qs(&xs.iter().copied().filter(p).collect::&lt;Vec&lt;&T&gt;&gt;())
                };
                Vec::from_iter(
                    filterxs(&move |&y| y &lt; x)
                        .into_iter()
                        .chain([x])
                        .chain(filterxs(&move |&y| y &gt;= x)),
                )
            }
            [] =&gt; vec![],
        }
    }
    qs(&Vec::from_iter(xs)).into_iter().cloned().collect()
}
```

Oh... my goodness. We've had to do a bunch of terrible things here.
Firstly, `T` might be a deep type... in which case we don't want to
clone more than once, so we have to convert into a `&[&T]`. Also, to
make this shorter, we have to use `dyn` eugh!. I mean, this probably
does _less_ than the Haskell version.