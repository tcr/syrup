# A very simple Read-Eval-Print-Loop.
# Based of CoffeeScript repl.coffee by Jeremy Ashkenas.

# Open `stdin` and `stdout`
stdin = process.openStdin()
stdout = process.stdout

# Require the **syrup** module to get access to the interpreter.
syrup = require './syrup'
readline     = require 'readline'
{inspect}    = require 'util'
{Script}     = require 'vm'
Module       = require 'module'

# REPL Setup

# Config
REPL_PROMPT = 'syrup> '
REPL_PROMPT_MULTILINE = '------> '
REPL_PROMPT_CONTINUATION = '.....> '
enableColours = no
unless process.platform is 'win32'
	enableColours = not process.env.NODE_DISABLE_COLORS

# Log an error.
error = (err) ->
	stdout.write (err.stack or err.toString()) + '\n'

# Make sure that uncaught exceptions don't kill the REPL.
process.on 'uncaughtException', error

# The current backlog of multi-line code.
backlog = ''

# Global context.
ctx = new syrup.DefaultContext

# The main REPL function. **run** is called every time a line of code is entered.
# Attempt to evaluate the command. If there's an exception, print it out instead
# of exiting.
run = (buffer) ->
	buffer = buffer.replace /[\r\n]+$/, ""
	if multilineMode
		backlog += "#{buffer}\n"
		repl.setPrompt REPL_PROMPT_CONTINUATION
		repl.prompt()
		return
	if !buffer.toString().trim() and !backlog
		repl.prompt()
		return
	code = backlog += buffer
	if code[code.length - 1] is '\\'
		backlog = "#{backlog[...-1]}\n"
		repl.setPrompt REPL_PROMPT_CONTINUATION
		repl.prompt()
		return
	repl.setPrompt REPL_PROMPT
	backlog = ''
	try
		returnValue = syrup.eval code, ctx
		repl.output.write "#{inspect returnValue, no, 2, enableColours}\n"
	catch err
		error err
	repl.prompt()

if stdin.readable
	# handle piped input
	pipedInput = ''
	repl =
		prompt: -> stdout.write @_prompt
		setPrompt: (p) -> @_prompt = p
		input: stdin
		output: stdout
		on: ->
	stdin.on 'data', (chunk) ->
		pipedInput += chunk
	stdin.on 'end', ->
		for line in pipedInput.trim().split "\n"
			stdout.write "#{line}\n"
			run line
		stdout.write '\n'
		process.exit 0
else
	# Create the REPL by listening to **stdin**.
	repl = readline.createInterface stdin, stdout

multilineMode = off

# Handle multi-line mode switch
repl.input.on 'keypress', (char, key) ->
	# test for Ctrl-v
	return unless key and key.ctrl and not key.meta and not key.shift and key.name is 'v'
	cursorPos = repl.cursor
	repl.output.cursorTo 0
	repl.output.clearLine 1
	multilineMode = not multilineMode
	backlog = ''
	repl.setPrompt (newPrompt = if multilineMode then REPL_PROMPT_MULTILINE else REPL_PROMPT)
	repl.prompt()
	repl.output.cursorTo newPrompt.length + (repl.cursor = cursorPos)

# Handle Ctrl-d press at end of last line in multiline mode
repl.input.on 'keypress', (char, key) ->
	return unless multilineMode and repl.line
	# test for Ctrl-d
	return unless key and key.ctrl and not key.meta and not key.shift and key.name is 'd'
	multilineMode = off
	repl._line()

repl.on 'attemptClose', ->
	if multilineMode
		multilineMode = off
		repl.output.cursorTo 0
		repl.output.clearLine 1
		repl._onLine repl.line
		return
	if backlog
		backlog = ''
		repl.output.write '\n'
		repl.setPrompt REPL_PROMPT
		repl.prompt()
	else
		repl.close()

repl.on 'close', ->
	repl.output.write '\n'
	repl.input.destroy()

repl.on 'line', run

repl.setPrompt REPL_PROMPT
repl.prompt()