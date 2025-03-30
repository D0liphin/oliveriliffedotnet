# Blog Generator

This is a Haskell program that generates static-site blogs for you.
Blogs are written in a slightly different version of markdown (explained
below).

You should have a folder that you target, for example `blog/`

```plaintext
blog/
    coding-in-haskell/
        index.md
        config.toml
    my-thoughts-on-riscv/
        index.md
        config.toml
        riscv-logo.png
```

The two things that actually matter are that both these directories
have a `index.md` and a `config.toml`. The `index.md` contains the
article body, and the `config.toml` contains metadata about the article.

Running this program on the target `blog/` will turn `index.md` into 
`index.html` and generate a blog home page pointing to all the different
blogs. The `config.toml` should look something like this, but only 
top-level fields are _required_

```toml
title = "Test Article"
description = "A test article, nothing special"
date = 2025-03-09

[meta]
keywords = ["test", "article"]

[[author]]
name = "Leslie Lamport"

[[author]]
name = "Donald Knuth"
```

# Markdown?

No. This is not markdown. It's pretty close though, and this is 
intentional. Most of the features of basic markdown are enabled and work
as expected. 

## Features not Present

### Soft paragraph breaks

If you want this, use `<br>` explicitly. So, instead of

```plaintext
Hi_there.__
Hi_there_on_a_newline.
```

```plaintext
Hi_there.<br>
Hi_there_on_a_newline.
```

## Changes

### Line breaks

Multiple newlines are actually counted. So for example

```plaintext
A


B

C
```

A, B and C have different amounts of spacing between them.

### Rules for Italics, Bold etc.

`* this *` would be printed as italicised. This is intentional. One
big difference then is that this:

```plaintext
blah: * this *hi*
```

Is no longer rendered like 

blah: * this *hi*

But rather like this

blah: *this* hi*

### Escapes

You can escape `*`, `>`, `!` and `$` whereever you like. Other 
characters cannot be escaped.
