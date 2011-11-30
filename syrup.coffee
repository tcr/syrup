code = """
(print "hi")
"""

###
# PARSER
###

chunker = 
 leftparen: /^\(/
 rightparen: /^\)/
 string: /^('[^']*'|"[^"]*")/
 atom: /^[a-zA-Z_?=+-\/*!]+/

c2 = code
tokens = []
while c2.length
 m = null
 for k, patt of chunker
  if m = patt.exec(c2)
    c2 = c2.substr(m[0].length).replace /^\s+/, ''
    tokens.push [k, m[0]]
    break
 unless m then throw new Error 'Invalid code'

res = []; stack = [res]
for token in tokens
 if token[0] == 'leftparen'
  l = []; stack[stack.length-1].push l; stack.push l
 if token[0] == 'rightparen'
  stack.pop()
 if token[0] == 'string'
  stack[stack.length-1].push ['quote', token[1].substr(1, token[1].length - 2)]
 if token[0] == 'atom'
  stack[stack.length-1].push token[1]

###
# EVAL
###

funcs =
 quote: (arg) -> arg
 "atom?": (arg) -> typeof arg == 'string'
 "=": (a, b) -> a == b
 "first": (list) -> list[0]
 "rest": (list) -> list[1...]
 "concat": (a, list) -> [a].concat(list)
 "cond": (list) ->
  for f in list then if funcs.eval(f[0]) then return funcs.eval(f[1])
 "eval": (f) ->
  if f?.constructor == Array then funcs[f[0]](f[1...])
  else f
 "print": (args) -> console.log (funcs.eval(arg) for arg in args)...

for stat in res
 funcs.eval stat