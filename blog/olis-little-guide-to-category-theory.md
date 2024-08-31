# Oli's Little Guide to Category Theory

This is a pure, plain-text-first little handbook for category theory.
It's not supposed to be a thorough description. I am writing it because
I want to be able to remember all these things in a few years when I
inevitably have gotten out of practice.

## Let's start

A category is a "bunch of objects". Some categories can be described as
sets, but some are _bigger_ than sets. Sometimes, people call this a
'class'.

Morphisms are arrows between objects. Objects are primitives in this
theory and don't have any properties. In fact, they're basically just
the names for ends of arrows.

There might be multiple morphisms between two objects, or none, or an 
infinite number of arrows... kind of like a graph.

Look at this

```
a --(f)-> b --(g)-> c
```

Here, we have two morphisms, `f` and `g`. There may be lots of morphisms
between `a` and `c` already, but we know there is at least one. We 
shall call this morphism "`g` after `f`" and write it `g ∘ f`. The `∘`
symbol is for "composition". Composition is associative.

Also, there is an `id` morphism for all objects. `g ∘ id` is of course
just `g`. This is a special morphism, because it's not just any morphism
that points from an object back into itself. For example, in the world
of sets as objects and functions as morphisms, `wrappingAdd n 1` 
might be a function that maps an object to itself, but it is not `id`.

## Some more stuff

`f :: a -> b` is an **isomorphism** if there exists a `g :: b -> a` with
these properties:

```
f ∘ g = id
g ∘ f = id
```
 

