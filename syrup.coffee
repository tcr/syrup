util = require 'util'
fs = require 'fs'

Array.isArray = (obj) -> !!(obj and obj.concat and obj.unshift and not obj.callee)
Object.hasOwnProperty = (obj, prop) -> {}.hasOwnProperty.call(obj, prop)

DEBUG_PARSE_TREE = no
DEBUG_JAVASCRIPT = yes

#######################################################################
# Parser
#######################################################################

chunker = 
	leftbracket: /^\[/
	rightbracket: /^\]/
	leftparen: /^\(/
	rightparen: /^\)[;:]?/
	leftbrace: /^\{/
	rightbrace: /^\}/
	quote: /^`/
	indent: /^\n[\t ]*/
	string: /^('[^']*'|"[^"]*")[:]?/
	callargs: /^[a-zA-Z_?!+\-\/*=\.]+[:]/
	call: /^[a-zA-Z_?!+\-\/*=\.]+[;](?!\b)/
	atom: /^([a-zA-Z_?!+\-\/*=\.]+)/
	comma: /^,/
	null: /^null/
	bool: /^true|^false/
	number: /^[0-9+]+/
	comment: /^\#[^\n]+/

exports.tokenize = (code) ->
	# Parse tokens.
	c2 = code.replace /\r/g, ''
	tokens = []
	while c2.length
		m = null
		for k, patt of chunker when m = patt.exec(c2)
			c2 = c2.substr(m[0].length).replace /^[\t ]+/, ''
			tokens.push [k, m[0]]
			break
		unless m then throw new Error 'Invalid code'
	
	#console.warn(util.inspect(tokens, no, null))
	return tokens

exports.parse = (code) -> 
	tokens = exports.tokenize(code); i = 0
	
	# Return parse tree.
	res = []
	# Stack of current node, and indentation level
	stack = [[res, -1]]
	indent = 0

	at = (type) -> tokens[i]?[0] == type
	peek = (type) -> tokens[i+1]?[0] == type
	next = -> t = tokens[i]; i++; return t
	top = -> stack[stack.length-1]?[0]

	parseList = ->
		while i < tokens.length
			if at 'indent'
				# Subsequent newlines.
				if peek 'indent'
					token = next()
					continue
				# indented on newlines, part of list
				if stack[stack.length-1]?[1] < tokens[i][1].length-1
					token = next()
					indent = token[1].length-1
				else
					break
			if at 'comma'
				token = next()
			if not parseExpression() then break

	parseExpression = ->
		return unless tokens[i]

		while at 'comment'
			token = next()

		if at 'call'
			token = next()
			name = token[1][0...-1]
			top().push [name]
		else if at 'callargs'
			token = next()
			name = token[1][0...-1]
			top().push l = [name]
			stack.push [l, indent]
			parseList()
			stack.pop()
		else if at 'quote'
			token = next()
			l = ['quote']
			top().push l
			stack.push [l, indent]
			parseExpression()
			stack.pop()
		else if at 'leftbrace'
			token = next()
			l = ['combine']
			top().push l
			stack.push [l, indent]
			parseList()
			unless at 'rightbrace' then throw new Error 'Missing right brace'
			token = next()
			stack.pop()
		else if at 'leftbracket'
			token = next()
			l = ['list']
			top().push l
			stack.push [l, indent]
			parseList()
			unless at 'rightbracket' then throw new Error 'Missing right bracket'
			token = next()
			stack.pop()
		else if at 'leftparen'
			token = next()
			parseExpression()
			unless at 'rightparen' then throw new Error 'Missing right paren'
			token = next()
			if token[1][1] == ':'
				l = [top().pop()]
				top().push l
				stack.push [l, indent]
				parseList()
				stack.pop()
			else if token[1][1] == ';'
				l = [top().pop()]
				top().push l
		else if at 'string'
			token = next()
			isfunc = token[1].substr(-1) == ':'
			str = token[1].substr(1, token[1].length - 2 - Number(isfunc))
			top().push ['quote', str]
			if isfunc
				l = [top().pop()]
				top().push l
				stack.push [l, indent]
				parseList()
				stack.pop()
		else if at 'bool'
			token = next()
			top().push token[1] == 'true'
		else if at 'atom'
			token = next()
			[l, props...] = token[1].split('.')
			for prop in props
				if not prop then throw new Error 'Invalid dot operator'
				l = ['.', l, ['quote', prop]]
			top().push l
		else if at 'number'
			token = next()
			top().push Number(token[1])
		else
			return false

		# Check if subsequent token is infix
		if at('atom') and tokens[i][1].match /^[+\-\/*=\.]+/
			op = tokens[i][1]; i++
			left = top().pop()
			unless parseExpression()
				throw new Error 'Missing right expression. Matched ' + tokens[i][0] + ' after ' + tokens[i-1][0] + ' (' + tokens[i-1] + ')'
			right = top().pop()
			top().push [op, left, right]

		return true

	parseList()

	if DEBUG_PARSE_TREE
		console.log 'Parse tree:'
		console.log(util.inspect(res, no, null))
		console.log '------------'

	return res

#######################################################################
# Evaluator
#######################################################################

exports.Context = (par) ->
	if par? then f = (->); f.prototype = par; vars = new f
	else vars = {}

	c = @
	@eval = (v) ->
		if Array.isArray(v)
			[fn, args...] = v
			fn = c.eval(fn)
			if typeof fn == 'string'
				ret = {}; ret[fn] = c.eval(args[0])
				return vars['combine'] ret, (c.eval(arg) for arg in args[1...])...
			if not fn? then throw Error 'Cannot invoke null function.'
			if fn.__macro then fn.apply c, args
			else fn.apply c, (c.eval(arg) for arg in args)
		else if typeof v == 'string' then @vars[v]
		else v
	@quote = (v) -> v
	@vars = vars
	return this

macro = (f) -> f.__macro = yes; f

exports.DefaultContext = ->
	class FlowControl
		constructor: (@type, @args) ->

	return new exports.Context
		'eval': (call) -> @eval call...
		'fn': macro (args, stats...) ->
			if args?[0] != 'list' then throw new Error 'Parse error: function arguments must be list'
			defaults = []
			args = for arg, i in args[1...]
				if typeof arg != 'string'
					if Array.isArray(arg) and arg[0] == '=' and arg.length == 3 and typeof arg[1] == 'string'
						defaults[i] = @eval arg[2]
						arg[1]
					else throw new Error 'Parse error: invalid function argument definition'
				else arg
			ctx = @
			f = (vals...) ->
				ctx2 = new exports.Context(ctx.vars)
				for arg, i in args
					ctx2.vars[arg] = vals[i] ? defaults[i]
				vals = ((ctx2.eval stat) for stat in stats)
				return vals[vals.length - 1]
			f.parameters = args
			return f
		'do': (fn) -> fn (@vals[arg] for arg in (fn.parameters or []))...
		'macro': macro (args, stats...) ->
			f = @eval ['fn', args, stats...]
			m = macro (args...) -> @eval f args...
			return m
		'quote': macro (arg) -> arg
		'atom?': macro (arg) -> typeof arg == 'string'

		# Lists.
		'list': (args...) -> args
		'first': (list) -> list?[0]
		'rest': (list) -> list?[1...]
		'concat': (v, list) -> [v].concat list
		'empty?': (list) -> not list?.length
		# Operators
		'new': (Obj, args...) -> (new Obj(args...))
		'=': macro (str, v) ->
			if Object.hasOwnProperty @vars, str
				throw new Error 'Cannot reassign variable in this scope: ' + str
			@vars[str] = @eval v
		'==': (a, b) -> a == b
		'+': (a, b) -> a + b
		'-': (a, b) -> a - b
		'/': (a, b) -> a / b
		'*': (a, b) -> a * b
		'%': (a, b) -> a % b
		'.': (a, b) -> a[b]
		'instanceof': (a, b) -> a instanceof b

		# Flow/generation
		'if': macro (test, t, f) -> if @eval test then @eval t else @eval f
		'loop': macro (args, stats...) ->
			fn = @eval ['fn', args, stats...]
			vals = (@vars[arg] for arg in (fn.parameters or []))
			loop
				try
					return fn vals...
				catch e
					unless e instanceof FlowControl then throw e
					vals = e.args
		'continue': (args...) -> throw new FlowControl 'continue', args
		'map': (f, expr) -> (f(v, i) for v, i in expr)
		'reduce': (f, expr) -> v for v, i in expr when f(v, i)
		'combine': (exprs...) ->
			ret = {}
			for expr in exprs
				for k, v of expr then ret[k] = v
			return ret

		# Utility
		'print': (args...) -> console.log args...
		'host': global

exports.eval = (code, ctx = new exports.DefaultContext) ->
	ret = null
	for stat in exports.parse(code)
		ret = ctx.eval stat
	return ret

#######################################################################
# Command line
#######################################################################

if require.main == module
	if process.argv.length < 3
		# Include REPL.
		require './repl'

	else
		fs.readFile process.argv[2], 'utf-8', (err, code) ->
			if err
				console.error "Could not open file: %s", err
				process.exit 1

			exports.eval code