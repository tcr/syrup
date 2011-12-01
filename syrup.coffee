util = require('util')

###

Syrup, a syntactically-light LISP

Syrup is whitespace-significant. Function calls are made as so:

  defn: test []
    print: "Cool language"

Where a colon following an atom indicates all subsequent arguments
are part of the list. This parse tree is equivalent to:

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

###


# Anonymous functions

code = """

defn: test []
 (fn: [f] f: `[b c]):
  fn: [x] concat: `a x
print: test.

"""

# Fibonacci

code = """

defn: fib-trec [n]
  defn: calc-fib [n a b]
    if: (n == 0)
      a 
      calc-fib: (n - 1) b (a + b)
  calc-fib: n 0 1

print: fib-trec: 10

"""

###
Equivalent parse tree:

(defn fib-trec (n)
  (defn calc-fib (n a b)
    (if (== n 0)
      a
      (calc-fib (- n 1) b (+ a b))
  (calc-fib n 0 1))
(print (fib-trec 10))

###

###
# Parser
###

chunker = 
	leftbracket: /^\[/
	rightbracket: /^\]/
	leftparen: /^\(/
	rightparen: /^\)[.:]?/
	quote: /^`/
	indent: /^\n[\t ]*/
	string: /^('[^']*'|"[^"]*")/
	callargs: /^[a-zA-Z_?=+-\/*!]+[:]/
	infix: /^[+\-\/*=]+/
	comma: /^,/
	call: /^[a-zA-Z_?=+\-\/*!]+[.]/
	bool: /^true|false/
	atom: /^[a-zA-Z_?=+\-\/*!]+/
	number: /^[0-9+]+/

c2 = code.replace /\r/g, ''
tokens = []
while c2.length
	m = null
	for k, patt of chunker
		if m = patt.exec(c2)
				c2 = c2.substr(m[0].length).replace /^[\t ]+/, ''
				tokens.push [k, m[0]]
				break
	unless m then throw new Error 'Invalid code'

res = []; stack = [[res, 0]]; indent = 0; i = 0

parseList = ->
	while i < tokens.length
		if tokens[i][0] == 'indent'
			if tokens[i+1]?[0] == 'indent'
				token = tokens[i]; i++
				continue
			# indented on newlines, part of list
			if stack[stack.length-1]?[1] < tokens[i][1].length	
				token = tokens[i]; i++
				indent = token[1].length
			else
				return
		if tokens[i]?[0] == 'comma'
			token = tokens[i]; i++
		if not parseExpression() then break

parseExpression = ->
	#while tokens[i]?[0] == 'indent' and tokens[i+1]?[0] == 'indent'
	#	token = tokens[i]; i++
	#	if tokens[i]?[0] == 'indent'
	#		continue
		#indent = token[1].length
		#stack.pop() while stack[stack.length-1]?[1] >= indent
	#while tokens[i]?[0] == 'indent'
	# if tokens[i]?[1].length != 1 then return false
	# token = tokens[i]; i++
	
	return unless tokens[i]
	if tokens[i][0] == 'call'
		token = tokens[i]; i++
		stack[stack.length-1][0].push [token[1][0...-1]]
	else if tokens[i][0] == 'callargs'
		token = tokens[i]; i++
		l = [token[1][0...-1]]
		stack[stack.length-1][0].push l
		stack.push [l, indent]
		parseList()
		stack.pop()
	else if tokens[i][0] == 'quote'
		token = tokens[i]; i++
		l = ['quote']
		stack[stack.length-1][0].push l
		stack.push [l, indent]
		parseExpression()
		stack.pop()
	else if tokens[i][0] == 'leftbracket'
		token = tokens[i]; i++
		l = ['list']
		stack[stack.length-1][0].push l
		stack.push [l, indent]
		parseList()
		if tokens[i]?[0] != 'rightbracket' then throw new Error 'Missing right bracket'
		token = tokens[i]; i++
		stack.pop()
	else if tokens[i][0] == 'leftparen'
		token = tokens[i]; i++
		parseExpression()
		if tokens[i]?[0] != 'rightparen' then throw new Error 'Missing right paren'
		token = tokens[i]; i++
		if token[1][1] == ':'
			l = [stack[stack.length-1]?[0].pop()]
			stack[stack.length-1]?[0].push l
			stack.push [l, indent]
			parseList()
			stack.pop()
		else if token[1][1] == '.'
			l = [stack[stack.length-1]?[0].pop()]
			stack[stack.length-1]?[0].push l
	else if tokens[i][0] == 'string'
		token = tokens[i]; i++
		stack[stack.length-1][0].push ['quote', token[1].substr(1, token[1].length - 2)]
	else if tokens[i][0] == 'bool'
		token = tokens[i]; i++
		stack[stack.length-1][0].push token[1] == 'true'
	else if tokens[i][0] == 'atom'
		token = tokens[i]; i++
		stack[stack.length-1][0].push token[1]
	else if tokens[i][0] == 'number'
		token = tokens[i]; i++
		stack[stack.length-1][0].push Number(token[1])
	else
		return false

	# infix notation
	if tokens[i]?[0] == 'infix'
		op = tokens[i][1]; i++
		left = stack[stack.length-1][0].pop()
		unless parseExpression() then throw new Error 'missing right expression'
		right = stack[stack.length-1][0].pop()
		stack[stack.length-1][0].push [op, left, right]

	return true

parseList()

console.log 'Parse tree:'
console.log(util.inspect(res, no, null))
console.log '------------'

###
# Evaluator
###

Scope = (parent = null, def) ->
	if parent then f = (->); f.prototype = parent; ret = new f()
	else ret = {}
	for k, v of def then ret[k] = v
	return ret

base = new Scope
	quote: (arg) -> arg
	"list": (list...) -> base.eval.call(this, e) for e in list
	"==": (a, b) -> base.eval.call(this, a) == base.eval.call(this, b)
	"atom?": (arg) -> typeof arg == 'string'

	"first": (list) -> list[0]
	"rest": (list) -> list[1...]
	"concat": (a, list) -> [base.eval.call(this, a)].concat base.eval.call(this, list)

	"if": (cond, t, f) ->
		if base.eval.call(this, cond) then return base.eval.call(this, t)
		else return base.eval.call(this, f)

	"eval": (f) ->
		if f?.constructor == Array
			#console.log 'Calling:', f[0], this
			if typeof f[0] == 'string' then this[f[0]](f[1...]...)
			else base.eval.call(this, f[0])(f[1...]...)
		else if typeof f == 'string' then this[f]
		else f

	"fn": (params, exprs...) ->
		lscope = this
		params = params[1...] # remove 'list' tag, auto-quote
		return (args...) ->
			#console.log 'Called function, scope is', this
			
			# evaluate params in original scope
			map = {}
			for p, i in params then map[p] = base.eval.call(this, args[i])

			# evaluate func in original scope
			s = new Scope(lscope, map)
			for expr in exprs[0...-1]
				#console.log ' ! ', s, expr
				base.eval.call(s, expr) 
			#console.log ' _ ', s, exprs[exprs.length-1]
			if exprs.length then return base.eval.call(s, exprs[exprs.length-1]) else null
	"def": (n, e) -> this[n] = base.eval.call this, e
	"defn": (n, params, exprs...) ->
		this[n] = base.fn.call this, params, exprs...

	"-": (a, b) -> base.eval.call(this, a) - base.eval.call(this, b)
	"+": (a, b) -> base.eval.call(this, a) + base.eval.call(this, b)

	"print": (args...) ->
		console.log 'Output:', (JSON.stringify(base.eval.call(this, arg)) for arg in args)...

###
# Test
###

#console.log(stat) for stat in res

for stat in res
	base.eval stat