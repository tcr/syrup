# Syrup, a syntactically-light LISP

Syrup is whitespace-significant. Function calls are made as so:

    defn: test []
      print: "Cool language"

Where a colon following an atom indicates all subsequent arguments
are part of the list. This parse tree is equivalent to (in Clojure):

    (defn test [] (print "Cool language"))

Parentheses are for disambiguation, and are insignificant:

    calc-fib: (n - 1) b (a + b)

Commas are allowed, but not required in lists of arguments/literals.
Array/list syntax is like JavaScript array literals:

    [5 6 7 8]

Arrays can't be invoked, as the above the above is equivalent to

    list: 5 6 7 8

Quoting is `. Infix notation is supported for arithmetic operations:

    (+: 5 6) is equal to (5 + 6)