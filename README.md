# Syrup, a syntactically-light LISP

    fib = fn: [n]
        calc-fib = fn: [n a b]
            if: (n == 0)
                a 
                calc-fib: (n - 1) b (a + b)
        calc-fib: n 0 1

    print: fib: 10

## Syntax

Syrup is whitespace-significant. Function calls are made by a colon
following an atom. All subsequent arguments on a line are passed to the
function until a newline of the same indentation, the end of a parenthetical,
or a period `.`

    print: "Cool language x" 5000  # Parses as (print "Cool language x" 5000)
    print:                         # Equivalent
        "Cool language x"
        5000
    print: square: 5. square: 6.   # "25", "36"

Parentheses are for disambiguation, and are insignificant. 
Commas are allowed, but not required.

    calc-fib: (n - 1) b (a + b)
    calc-fib: n - 1, b, a + b

Vector (array) syntax is like JavaScript's array literals. Vectors
are not executed as functions.

    [5 6 7 8] # equivalent to list: 5 6 7 8

Quoting uses \`.

    print: `apples                 # prints "apples"

Infix notation is supported for arithmetic operations
and for the assign operator:

    5 + 6                          # these two lines are
    (+: 5 6)                       # equivalent
    test = fn: [] print: 'hi'      # declares the function 'test'

Macros are supported:

    unless = macro: [cond t f]
      [`if cond f t]

    print: unless: true "false value" "true value"

Object literals can be defined using quoted strings or string variables
as keys (as in python). Any arguments after the first passed to a string
function have their properties copied to the new object literal. Finally,
curly-braces combine all listed objects into one.
 
    "a": 1                         # JSON: {"a": 1}
    ("some" + "key"): "val"        # JSON: {"somekey": "val"}
    obj = "b": 2 "c": 3            # parses to ("b" 2 ("c" 3)) and JSON: {"b": 2, "c": 3}
    obj2 = {"a": 1, obj}           # parses to (combine ("a", 1) obj) and JSON: {"a": 1, "b": 2, "c": 3}

## TODO

REPL, and lots more bikeshedding.