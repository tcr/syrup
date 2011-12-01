(function() {
  var Scope, base, chunker, fs, parse, util;
  var __slice = Array.prototype.slice;
  util = require('util');
  fs = require('fs');
  /*
  # Parser
  */
  chunker = {
    leftbracket: /^\[/,
    rightbracket: /^\]/,
    leftparen: /^\(/,
    rightparen: /^\)[.:]?/,
    quote: /^`/,
    indent: /^\n[\t ]*/,
    string: /^('[^']*'|"[^"]*")/,
    callargs: /^[a-zA-Z_?=+-\/*!]+[:]/,
    infix: /^[+\-\/*=]+/,
    comma: /^,/,
    call: /^[a-zA-Z_?=+\-\/*!]+[.]/,
    bool: /^true|false/,
    atom: /^[a-zA-Z_?=+\-\/*!]+/,
    number: /^[0-9+]+/,
    comment: /^\#[^\n]+/
  };
  parse = function(code) {
    var c2, i, indent, k, m, parseExpression, parseList, patt, res, stack, tokens;
    c2 = code.replace(/\r/g, '');
    tokens = [];
    while (c2.length) {
      m = null;
      for (k in chunker) {
        patt = chunker[k];
        if (m = patt.exec(c2)) {
          c2 = c2.substr(m[0].length).replace(/^[\t ]+/, '');
          tokens.push([k, m[0]]);
          break;
        }
      }
      if (!m) {
        throw new Error('Invalid code');
      }
    }
    res = [];
    stack = [[res, -1]];
    indent = 0;
    i = 0;
    parseList = function() {
      var token, _ref, _ref2, _ref3, _results;
      _results = [];
      while (i < tokens.length) {
        if (tokens[i][0] === 'indent') {
          if (((_ref = tokens[i + 1]) != null ? _ref[0] : void 0) === 'indent') {
            token = tokens[i];
            i++;
            continue;
          }
          if (((_ref2 = stack[stack.length - 1]) != null ? _ref2[1] : void 0) < tokens[i][1].length - 1) {
            token = tokens[i];
            i++;
            indent = token[1].length - 1;
          } else {
            break;
          }
        }
        if (((_ref3 = tokens[i]) != null ? _ref3[0] : void 0) === 'comma') {
          token = tokens[i];
          i++;
        }
        if (!parseExpression()) {
          break;
        }
      }
      return _results;
    };
    parseExpression = function() {
      var l, left, op, right, token, _ref, _ref2, _ref3, _ref4, _ref5, _ref6, _ref7;
      if (!tokens[i]) {
        return;
      }
      while (tokens[i][0] === 'comment') {
        token = tokens[i];
        i++;
      }
      if (tokens[i][0] === 'call') {
        token = tokens[i];
        i++;
        stack[stack.length - 1][0].push([token[1].slice(0, -1)]);
      } else if (tokens[i][0] === 'callargs') {
        token = tokens[i];
        i++;
        l = [token[1].slice(0, -1)];
        stack[stack.length - 1][0].push(l);
        stack.push([l, indent]);
        parseList();
        stack.pop();
      } else if (tokens[i][0] === 'quote') {
        token = tokens[i];
        i++;
        l = ['quote'];
        stack[stack.length - 1][0].push(l);
        stack.push([l, indent]);
        parseExpression();
        stack.pop();
      } else if (tokens[i][0] === 'leftbracket') {
        token = tokens[i];
        i++;
        l = ['list'];
        stack[stack.length - 1][0].push(l);
        stack.push([l, indent]);
        parseList();
        if (((_ref = tokens[i]) != null ? _ref[0] : void 0) !== 'rightbracket') {
          throw new Error('Missing right bracket');
        }
        token = tokens[i];
        i++;
        stack.pop();
      } else if (tokens[i][0] === 'leftparen') {
        token = tokens[i];
        i++;
        parseExpression();
        if (((_ref2 = tokens[i]) != null ? _ref2[0] : void 0) !== 'rightparen') {
          throw new Error('Missing right paren');
        }
        token = tokens[i];
        i++;
        if (token[1][1] === ':') {
          l = [(_ref3 = stack[stack.length - 1]) != null ? _ref3[0].pop() : void 0];
          if ((_ref4 = stack[stack.length - 1]) != null) {
            _ref4[0].push(l);
          }
          stack.push([l, indent]);
          parseList();
          stack.pop();
        } else if (token[1][1] === '.') {
          l = [(_ref5 = stack[stack.length - 1]) != null ? _ref5[0].pop() : void 0];
          if ((_ref6 = stack[stack.length - 1]) != null) {
            _ref6[0].push(l);
          }
        }
      } else if (tokens[i][0] === 'string') {
        token = tokens[i];
        i++;
        stack[stack.length - 1][0].push(['quote', token[1].substr(1, token[1].length - 2)]);
      } else if (tokens[i][0] === 'bool') {
        token = tokens[i];
        i++;
        stack[stack.length - 1][0].push(token[1] === 'true');
      } else if (tokens[i][0] === 'atom') {
        token = tokens[i];
        i++;
        stack[stack.length - 1][0].push(token[1]);
      } else if (tokens[i][0] === 'number') {
        token = tokens[i];
        i++;
        stack[stack.length - 1][0].push(Number(token[1]));
      } else {
        return false;
      }
      if (((_ref7 = tokens[i]) != null ? _ref7[0] : void 0) === 'infix') {
        op = tokens[i][1];
        i++;
        left = stack[stack.length - 1][0].pop();
        if (!parseExpression()) {
          throw new Error('missing right expression');
        }
        right = stack[stack.length - 1][0].pop();
        stack[stack.length - 1][0].push([op, left, right]);
      }
      return true;
    };
    parseList();
    console.log('Parse tree:');
    console.log(util.inspect(res, false, null));
    console.log('------------');
    return res;
  };
  /*
  # Evaluator
  */
  Scope = function(parent, def) {
    var f, k, ret, v;
    if (parent == null) {
      parent = null;
    }
    if (parent) {
      f = (function() {});
      f.prototype = parent;
      ret = new f();
    } else {
      ret = {};
    }
    for (k in def) {
      v = def[k];
      ret[k] = v;
    }
    return ret;
  };
  base = new Scope({
    quote: function(arg) {
      return arg;
    },
    "list": function() {
      var e, list, _i, _len, _results;
      list = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      _results = [];
      for (_i = 0, _len = list.length; _i < _len; _i++) {
        e = list[_i];
        _results.push(base.eval.call(this, e));
      }
      return _results;
    },
    "==": function(a, b) {
      return base.eval.call(this, a) === base.eval.call(this, b);
    },
    "atom?": function(arg) {
      return typeof arg === 'string';
    },
    "first": function(list) {
      return list[0];
    },
    "rest": function(list) {
      return list.slice(1);
    },
    "concat": function(a, list) {
      return [base.eval.call(this, a)].concat(base.eval.call(this, list));
    },
    "if": function(cond, t, f) {
      if (base.eval.call(this, cond)) {
        return base.eval.call(this, t);
      } else {
        return base.eval.call(this, f);
      }
    },
    "eval": function(f) {
      if ((f != null ? f.constructor : void 0) === Array) {
        if (typeof f[0] === 'string') {
          return this[f[0]].apply(this, f.slice(1));
        } else {
          return base.eval.call(this, f[0]).apply(null, f.slice(1));
        }
      } else if (typeof f === 'string') {
        return this[f];
      } else {
        return f;
      }
    },
    "fn": function() {
      var exprs, lscope, params;
      params = arguments[0], exprs = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
      lscope = this;
      params = params.slice(1);
      return function() {
        var args, expr, i, map, p, s, _i, _len, _len2, _ref;
        args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
        map = {};
        for (i = 0, _len = params.length; i < _len; i++) {
          p = params[i];
          map[p] = base.eval.call(this, args[i]);
        }
        s = new Scope(lscope, map);
        _ref = exprs.slice(0, -1);
        for (_i = 0, _len2 = _ref.length; _i < _len2; _i++) {
          expr = _ref[_i];
          base.eval.call(s, expr);
        }
        if (exprs.length) {
          return base.eval.call(s, exprs[exprs.length - 1]);
        } else {
          return null;
        }
      };
    },
    "macro": function() {
      var exprs, lscope, params;
      params = arguments[0], exprs = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
      lscope = this;
      params = params.slice(1);
      return function() {
        var args, expr, i, map, p, s, _i, _len, _len2, _ref;
        args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
        map = {};
        for (i = 0, _len = params.length; i < _len; i++) {
          p = params[i];
          map[p] = args[i];
        }
        s = new Scope(lscope, map);
        _ref = exprs.slice(0, -1);
        for (_i = 0, _len2 = _ref.length; _i < _len2; _i++) {
          expr = _ref[_i];
          base.eval.call(s, expr);
        }
        if (exprs.length) {
          return base.eval.call(s, exprs[exprs.length - 1]);
        } else {
          return null;
        }
      };
    },
    "=": function(n, e) {
      return this[n] = base.eval.call(this, e);
    },
    "-": function(a, b) {
      return base.eval.call(this, a) - base.eval.call(this, b);
    },
    "+": function(a, b) {
      return base.eval.call(this, a) + base.eval.call(this, b);
    },
    "print": function() {
      var arg, args;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return console.log.apply(console, ['Output:'].concat(__slice.call((function() {
        var _i, _len, _results;
        _results = [];
        for (_i = 0, _len = args.length; _i < _len; _i++) {
          arg = args[_i];
          _results.push(JSON.stringify(base.eval.call(this, arg)));
        }
        return _results;
      }).call(this))));
    }
  });
  /*
  # Test
  */
  if (process.argv.length < 3) {
    console.error('Please specify a file');
    process.exit(1);
  }
  (function() {
    return fs.readFile(process.argv[2], 'utf-8', function(err, code) {
      var res, stat, _i, _len, _results;
      if (err) {
        console.error("Could not open file: %s", err);
        process.exit(1);
      }
      res = parse(code);
      _results = [];
      for (_i = 0, _len = res.length; _i < _len; _i++) {
        stat = res[_i];
        _results.push(base.eval(stat));
      }
      return _results;
    });
  })();
}).call(this);
