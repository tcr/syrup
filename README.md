# Syrup, a syntactically-light LISP

Syrup is whitespace-significant. Function calls are made as so:

    print: "Cool language x" 5000

Where a colon following an atom indicates all subsequent arguments
are part of the list. This parse tree is equivalent to (in Clojure):

    (print "Cool language x" 5000)

Parentheses are for disambiguation, and are insignificant:

    calc-fib: (n - 1) b (a + b)

Commas are allowed, but not required in lists of arguments/literals.
Array/list syntax is like JavaScript array literals:

    [5 6 7 8] # equivalent to list: 5 6 7 8

Because arrays evaluate to lists, they are not equivalent to lists
in Lisp (which can be evaluated).

Quoting uses \`.

    print: `apples # prints "apples"

Infix notation is supported for arithmetic operations
and for the assign operator:

    (+: 5 6) # equivalent to (5 + 6)
    test = fn: [] print: 'hi' # declares the function 'test'

Macros are supported:

    unless = macro: [cond t f]
      [`if cond f t]
    print: unless: true "false value" "true value"

## Open Design Issues!

### JSON Compatible

A major goal for Syrup is to be JSON-compatible. There would be syntatic
confusion for object literals if both the following lines were valid:

    # Function calls:
    a: 5, b: 6 # (a 5 (b 6))

    # Object literal:
    {"a": 5, "b": 6}

Requiring object keys to be quoted as strings (strict JSON) alleviates
some of this concern, but the colon operator still seems overloaded.

### More things later