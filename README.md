# Syrup, a syntactically-light LISP

```coffee-script
fib = fn: [n]
    calc-fib = fn: [n a b]
        if: (n == 0)
            a 
            calc-fib: (n - 1) b (a + b)
    calc-fib: n 0 1

print: fib: 10
```

From the command line:

    coffee syrup.coffee examples/fib.syrup

And for a REPL:

    coffee syrup.coffee

## Syntax

Syrup is whitespace-significant. Function calls are made by a colon
following an atom. All subsequent arguments on a line are passed to the
function until a newline of the same indentation, the end of a parenthetical,
or a semicolon `;`

```coffee-script
print: "Cool language x" 5000  # Parses as (print "Cool language x" 5000)
print:                         # Equivalent
    "Cool language x"
    5000
print: square: 5; square: 6;   # "25", "36"
```

Parentheses are for disambiguation, and are insignificant. 
Commas are allowed, but not required.

```coffee-script
calc-fib: (n - 1) b (a + b)
calc-fib: n - 1, b, a + b
```

Vector (array) syntax is like JavaScript's array literals. Vectors
are not executed as functions.

```coffee-script
[5 6 7 8] # equivalent to list: 5 6 7 8
```

Quoting uses \`.

```coffee-script
print: `apples                 # prints "apples"
```

Infix notation is supported for arithmetic operators
and the assign operator:

```coffee-script
5 + 6                          # these two lines...
+: 5 6                         # ...are equivalent
test = fn: [] print: 'hi'      # declares the function 'test'
```

Macros are supported:

```coffee-script
unless = macro: [cond t f]
  [`if cond f t]

print: unless: true "falsy" "truthy"
```

Object literals can be defined using quoted strings or string variables
as keys (as in python). Any arguments after the first passed to a string
function have their properties copied to the new object literal. Finally,
curly-braces combine all listed objects into one.

```coffee-script
"a": 1                         # JSON: {"a": 1}
key = "somekey"
key: "val"                     # JSON: {"somekey": "val"}
("some" + "key"): "val"        # JSON: {"somekey": "val"}
obj = "b": 2 "c": 3            # parses to ("b" 2 ("c" 3)), equals {"b": 2, "c": 3}
obj2 = {"a": 1, obj}           # parses to (combine ("a", 1) obj), equals {"a": 1, "b": 2, "c": 3}
```

## Roadmap

* Lots more bikeshedding.
* Option to write Node.js scripts in syrup.
* Rewrite compiler in Syrup.

## License

Syrup is released under the MIT License.