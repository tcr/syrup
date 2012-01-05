util = require 'util'
fs = require 'fs'

#######################################################################
# Parser
#######################################################################

chunker = 
	leftbracket: /^\[/
	rightbracket: /^\]/
	leftparen: /^\(/
	rightparen: /^\)[.:]?/
	quote: /^`/
	indent: /^\n[\t ]*/
	string: /^('[^']*'|"[^"]*")/
	callargs: /^[a-zA-Z_?=+-\/*!]+[:]/
	call: /^[a-zA-Z_?=+\-\/*!]+[.](?!\b)/
	atom: /^[a-zA-Z_?=+\-\/*!]+/
	comma: /^,/
	null: /^null/
	bool: /^true|^false/
	number: /^[0-9+]+/
	comment: /^\#[^\n]+/

parse = (code) -> 
	# Parse tokens.

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
	
	console.warn(util.inspect(tokens, no, null))
	
	# Parse grammar.

	res = []; stack = [[res, -1]]; indent = 0; i = 0

	parseList = ->
		while i < tokens.length
			if tokens[i][0] == 'indent'
				if tokens[i+1]?[0] == 'indent'
					token = tokens[i]; i++
					continue
					# indented on newlines, part of list
				if stack[stack.length-1]?[1] < tokens[i][1].length-1
					token = tokens[i]; i++
					indent = token[1].length-1
				else
					break
			if tokens[i]?[0] == 'comma'
				token = tokens[i]; i++
			if not parseExpression() then break

	parseExpression = ->
		while tokens[i][0] == 'comment'
			token = tokens[i]; i++

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

		# Check if subsequent token is infix
		if tokens[i]?[0] == 'atom' and tokens[i][1].match /^[+\-\/*=]+/
			op = tokens[i][1]; i++
			left = stack[stack.length-1][0].pop()
			unless parseExpression()
				throw new Error 'Missing right expression. Matched ' + tokens[i][0] + ' after ' + tokens[i-1][0] + ' (' + tokens[i-1] + ')'
			right = stack[stack.length-1][0].pop()
			stack[stack.length-1][0].push [op, left, right]

		return true

	parseList()

	console.log 'Parse tree:'
	console.log(util.inspect(res, no, null))
	console.log '------------'

	return res

#######################################################################
# Evaluator
#######################################################################

execScript = (code) ->
	Scope = (parent = null, def) ->
		if parent then f = (->); f.prototype = parent; ret = new f()
		else ret = {}
		for k, v of def then ret[k] = v
		return ret

	eval = (ths, f) -> base.eval.call(ths, f)

	base = new Scope
		quote: (arg) -> arg
		"list": (list...) -> eval(this, e) for e in list
		"==": (a, b) -> eval(this, a) == eval(this, b)
		"atom?": (arg) -> typeof arg == 'string'
		"first": (list) -> eval(this, list)[0]
		"rest": (list) -> eval(this, list)[1...]
		"concat": (a, list) -> [eval(this, a)].concat eval(this, list)
		"if": (cond, t, f) -> if eval(this, cond) then eval(this, t) else eval(this, f)

		"empty?": (list) -> not eval(this, list)?.length

		"eval": (f) ->
			if f?.constructor == Array
				if typeof f[0] == 'string'
					this[f[0]](f[1...]...)
				else
					base.eval.call(this, f[0]).call(this, f[1...]...)
			else if typeof f == 'string' then this[f]
			else f

		"fn": (params, exprs...) ->
			lscope = this
			params = params[1...] # remove 'list' tag, auto-quote
			return (args...) ->
				# evaluate params in original scope
				map = {}
				for p, i in params then map[p] = base.eval.call(this, args[i])
				# evaluate func in new scope
				s = new Scope(lscope, map)
				for expr in exprs[0...-1] then base.eval.call(s, expr) 
				return if exprs.length then base.eval.call(s, exprs[exprs.length-1]) else null
		"macro": (params, exprs...) ->
			lscope = this
			params = params[1...] # remove 'list' tag, auto-quote
			return (args...) ->
				# name params
				map = {}
				for p, i in params then map[p] = args[i]
				# evaluate func in new scope
				s = new Scope(lscope, map)
				for expr in exprs[0...-1] then base.eval.call(s, expr) 
				if exprs.length
					res = base.eval.call(s, exprs[exprs.length-1])
					return eval(this, res)
				else
					return null
		"=": (n, e) ->
			if this[n]? then throw new Error 'Cannot reassign variable'
			this[n] = base.eval.call this, e
		"-": (a, b) -> base.eval.call(this, a) - base.eval.call(this, b)
		"+": (a, b) -> base.eval.call(this, a) + base.eval.call(this, b)

		"print": (args...) ->
			console.log (JSON.stringify(base.eval.call(this, arg)) for arg in args)...
	
	res = parse(code)
	for stat in res
		base.eval stat

#######################################################################
# Command line
#######################################################################

if process.argv.length < 3
	console.error 'Please specify a file'
	process.exit 1

do ->
	fs.readFile process.argv[2], 'utf-8', (err, code) ->
		if err
			console.error "Could not open file: %s", err
			process.exit 1

		execScript code