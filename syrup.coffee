console.log '######################################################'

code = """

defn: test_a [f]
 f: `[b c]
defn: test_b [x]
 concat: `a x
print: test_a: test_b

"""

###
# Parser
###

chunker = 
 leftbracket: /^\[/
 rightbracket: /^\]/
 quote: /^`/
 indent: /^\n\s*/
# leftparen: /^\(/
# rightparen: /^\)/
 string: /^('[^']*'|"[^"]*")/
 callargs: /^[a-zA-Z_?=+-\/*!]+[:]/
 call: /^[a-zA-Z_?=+-\/*!]+[.]/
 atom: /^[a-zA-Z_?=+-\/*!]+/

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

res = []; stack = [[res, 0]]; indent = 0

parseList = ->
 while i < tokens.length
  if tokens[i][0] == 'indent'
   i++
   indent = token[1].length
   stack.pop() while stack[stack.length-1]?[1] > indent
   if indent == stack[stack.length-1]?[1] then stack.pop()
  if not parseExpression() then break
 
parseExpression = ->
 if tokens[i][0] == 'call'
  i++
  stack[stack.length-1][0].push [tokens[i][1][0...-1]]
 else if tokens[i][0] == 'callargs'
  i++
  l = [tokens[i][1][0...-1]]
  stack[stack.length-1][0].push l
  stack.push [l, indent]
  parseList()
 else if tokens[i][0] == 'quote'
  i++
  l = ['quote']
  stack[stack.length-1][0].push l
  stack.push [l, indent]
  parseExpression()
  stack.pop()
 else if tokens[i][0] == 'leftbracket'
  i++
  l = []
  stack[stack.length-1][0].push l
  stack.push [l, indent]
  if tokens[i][0] !== 'rightbracket' then throw 'Missing right bracket'
  i++
  stack.pop()
 else if tokens[i][0] == 'string'
  i++
  stack[stack.length-1][0].push ['quote', tokens[i][1].substr(1, tokens[i][1].length - 2)]
 else if tokens[i][0] == 'atom'
  i++
  stack[stack.length-1][0].push tokens[i][1]
 else return false
 return true

while i < tokens.length
 parseExpression()

console.log 'Parse tree:', JSON.stringify res
throw 'done'

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
 "atom?": (arg) -> typeof arg == 'string'
 "=": (a, b) -> a == b
 "first": (list) -> list[0]
 "rest": (list) -> list[1...]
 "concat": (a, list) -> [base.eval.call(this, a)].concat base.eval.call(this, list)
 "cond": (list) ->
  for f in list
   if base.eval.call(this, f[0]) then return base.eval.call(this, f[1])

 "eval": (f) ->
  if f?.constructor == Array
   if typeof f[0] == 'string' then this[f[0]](f[1...]...)
   else base.eval.call(this, f[0])(f[1...]...)
  else if typeof f == 'string' then this[f]
  else f
 "print": (args...) ->
  console.log 'Output:', (JSON.stringify(base.eval.call(this, arg)) for arg in args)...
 "fn": (params, exprs...) -> return (args...) =>
  map = {}
  for p, i in params then map[p] = base.eval.call(this, args[i])
  s = new Scope(this, map)
  base.eval.call(s, expr) for expr in exprs[0...-1]
  if exprs.length then return base.eval.call(s, exprs[exprs.length-1]) else null
 "def": (n, e) -> this[n] = base.eval.call this, e
 "defn": (n, params, exprs...) -> this[n] = base.fn.call this, params, exprs...

###
# Test
###

for stat in res
 base.eval stat