.PHONY: all

all:
	node syrup compiler.syrup -T > out.json && mv out.json compiler.json
