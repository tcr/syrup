var DEBUG_JAVASCRIPT, DEBUG_PARSE_TREE, chunker, fs, macro, util,
  slice = [].slice;

util = require('util');

fs = require('fs');

Array.isArray = function(obj) {
  return !!(obj && obj.concat && obj.unshift && !obj.callee);
};

Object.hasOwnProperty = function(obj, prop) {
  return {}.hasOwnProperty.call(obj, prop);
};

DEBUG_PARSE_TREE = true;

DEBUG_JAVASCRIPT = true;

chunker = {
  leftbracket: /^\[/,
  rightbracket: /^\]/,
  leftparen: /^\(/,
  rightparen: /^\)[;:]?/,
  leftbrace: /^\{/,
  rightbrace: /^\}/,
  quote: /^`/,
  indent: /^\n[\t ]*/,
  "string": /^("([^\\"]|\\\\|\\")*"|'([^\\']|\\\\|\\')*')[:]?/,
  "regex": /^\/(\\\/|[^\/])*\//,
  callargs: /^(?![0-9])[0-9a-zA-Z_?!+\-\/*=><\.]+[:]/,
  call: /^(?![0-9])[0-9a-zA-Z_?!+\-\/*=><\.]+[;]/,
  atom: /^(?![0-9])[0-9a-zA-Z_?!+\-\/*=><\.]+/,
  comma: /^,/,
  semicolon: /^;/,
  "null": /^null/,
  bool: /^true|^false/,
  number: /^[0-9+]+/,
  comment: /^\#[^\n]+/
};

exports.tokenize = function(code) {
  var c2, k, m, patt, tokens;
  c2 = code.replace(/\r/g, '');
  tokens = [];
  while (c2.length) {
    m = null;
    for (k in chunker) {
      patt = chunker[k];
      if (!(m = patt.exec(c2))) {
        continue;
      }
      c2 = c2.substr(m[0].length).replace(/^[\t ]+/, '');
      tokens.push([k, m[0]]);
      break;
    }
    if (!m) {
      throw new Error('Invalid code');
    }
  }
  return tokens;
};

exports.parse = function(code) {
  var at, i, indent, next, parseExpression, parseList, peek, res, stack, tokens, top;
  tokens = exports.tokenize(code);
  i = 0;
  res = [];
  stack = [[res, -1]];
  indent = 0;
  at = function(type) {
    var ref;
    return ((ref = tokens[i]) != null ? ref[0] : void 0) === type;
  };
  peek = function(type) {
    var ref;
    return ((ref = tokens[i + 1]) != null ? ref[0] : void 0) === type;
  };
  next = function() {
    var t;
    t = tokens[i];
    i++;
    return t;
  };
  top = function() {
    var ref;
    return (ref = stack[stack.length - 1]) != null ? ref[0] : void 0;
  };
  parseList = function() {
    var ref, results, token;
    results = [];
    while (i < tokens.length) {
      if (at('indent')) {
        if (peek('indent')) {
          token = next();
          continue;
        }
        if (((ref = stack[stack.length - 1]) != null ? ref[1] : void 0) < tokens[i][1].length - 1) {
          token = next();
          indent = token[1].length - 1;
        } else {
          break;
        }
      }
      if (at('comma')) {
        token = next();
      }
      if (at('semicolon')) {
        token = next();
        break;
      }
      if (!parseExpression()) {
        break;
      } else {
        results.push(void 0);
      }
    }
    return results;
  };
  parseExpression = function() {
    var isfunc, j, l, left, len, method, name, op, prop, props, ref, right, str, token;
    if (!tokens[i]) {
      return;
    }
    while (at('comment')) {
      while (at('comment')) {
        token = next();
      }
      while (at('indent')) {
        next();
      }
    }
    if (at('leftbrace')) {
      token = next();
      l = ['combine'];
      top().push(l);
      stack.push([l, indent]);
      parseList();
      if (!at('rightbrace')) {
        throw new Error('Missing right brace');
      }
      token = next();
      stack.pop();
    } else if (at('leftbracket')) {
      token = next();
      l = ['list'];
      top().push(l);
      stack.push([l, indent]);
      parseList();
      if (!at('rightbracket')) {
        throw new Error('Missing right bracket');
      }
      token = next();
      stack.pop();
    } else if (at('leftparen')) {
      token = next();
      parseExpression();
      if (!at('rightparen')) {
        throw new Error('Missing right paren');
      }
      token = next();
      if (token[1][1] === ':') {
        l = [top().pop()];
        top().push(l);
        stack.push([l, indent]);
        parseList();
        stack.pop();
      } else if (token[1][1] === ';') {
        l = [top().pop()];
        top().push(l);
      }
    } else if (at('quote')) {
      token = next();
      l = ['quote'];
      top().push(l);
      stack.push([l, indent]);
      parseExpression();
      stack.pop();
    } else if (at('number')) {
      token = next();
      top().push(Number(token[1]));
    } else if (at('string')) {
      token = next();
      isfunc = token[1].substr(-1) === ':';
      str = token[1].substr(1, token[1].length - 2 - Number(isfunc));
      top().push(['quote', str]);
      if (isfunc) {
        l = [top().pop()];
        top().push(l);
        stack.push([l, indent]);
        parseList();
        stack.pop();
      }
    } else if (at('regex')) {
      token = next();
      str = token[1].substr(1, token[1].length - 2).replace('\\/', '/');
      top().push(['regex', ['quote', str]]);
    } else if (at('bool')) {
      token = next();
      top().push(token[1] === 'true');
    } else if (at('atom') || at('call') || at('callargs')) {
      token = next();
      name = token[0] === 'atom' ? token[1] : token[1].slice(0, -1);
      ref = name.split('.'), l = ref[0], props = 2 <= ref.length ? slice.call(ref, 1) : [];
      method = token[0] !== 'atom' ? props.pop() : void 0;
      if (l === '') {
        l = top().pop();
      }
      for (j = 0, len = props.length; j < len; j++) {
        prop = props[j];
        if (!prop) {
          throw new Error('Invalid dot operator');
        }
        l = ['.', l, ['quote', prop]];
      }
      if (token[0] !== 'atom') {
        if (method != null) {
          l = ['call', l, ['quote', method]];
        } else {
          l = [l];
        }
      }
      top().push(l);
      if (token[0] === 'callargs') {
        stack.push([l, indent]);
        parseList();
        stack.pop();
      }
    } else {
      return false;
    }
    if (at('atom') && tokens[i][1].match(/^[+\-\/*=\.><]+/)) {
      op = tokens[i][1];
      i++;
      left = top().pop();
      if (!parseExpression()) {
        throw new Error('Missing right expression. Matched ' + tokens[i][0] + ' after ' + tokens[i - 1][0] + ' (' + tokens[i - 1] + ')');
      }
      right = top().pop();
      top().push([op, left, right]);
    }
    return true;
  };
  parseList();
  if (DEBUG_PARSE_TREE) {
    console.log('Parse tree:');
    console.log(util.inspect(res, false, null));
    console.log('------------');
  }
  return res;
};

exports.Context = function(par) {
  var c, f, vars;
  if (par != null) {
    f = (function() {});
    f.prototype = par;
    vars = new f;
  } else {
    vars = {};
  }
  c = this;
  this["eval"] = function(v) {
    var arg, args, fn, ret;
    if (Array.isArray(v)) {
      fn = v[0], args = 2 <= v.length ? slice.call(v, 1) : [];
      fn = c["eval"](fn);
      if (typeof fn === 'string') {
        ret = {};
        ret[fn] = c["eval"](args[0]);
        return vars['combine'].apply(vars, [ret].concat(slice.call((function() {
          var j, len, ref, results;
          ref = args.slice(1);
          results = [];
          for (j = 0, len = ref.length; j < len; j++) {
            arg = ref[j];
            results.push(c["eval"](arg));
          }
          return results;
        })())));
      }
      if (fn == null) {
        throw Error('Cannot invoke null function.');
      }
      if (fn.__macro) {
        return fn.apply(c, args);
      } else {
        return fn.apply(c, (function() {
          var j, len, results;
          results = [];
          for (j = 0, len = args.length; j < len; j++) {
            arg = args[j];
            results.push(c["eval"](arg));
          }
          return results;
        })());
      }
    } else if (typeof v === 'string') {
      return this.vars[v];
    } else {
      return v;
    }
  };
  this.quote = function(v) {
    return v;
  };
  this.vars = vars;
  return this;
};

macro = function(f) {
  f.__macro = true;
  return f;
};

exports.DefaultContext = function() {
  var FlowControl;
  FlowControl = (function() {
    function FlowControl(type1, args1) {
      this.type = type1;
      this.args = args1;
    }

    return FlowControl;

  })();
  return new exports.Context({
    'eval': function(call) {
      return this["eval"].apply(this, call);
    },
    'fn': macro(function() {
      var arg, args, ctx, defaults, f, i, stats;
      args = arguments[0], stats = 2 <= arguments.length ? slice.call(arguments, 1) : [];
      if ((args != null ? args[0] : void 0) !== 'list') {
        throw new Error('Parse error: function arguments must be list');
      }
      defaults = [];
      args = (function() {
        var j, len, ref, results;
        ref = args.slice(1);
        results = [];
        for (i = j = 0, len = ref.length; j < len; i = ++j) {
          arg = ref[i];
          if (typeof arg !== 'string') {
            if (Array.isArray(arg) && arg[0] === '=' && arg.length === 3 && typeof arg[1] === 'string') {
              defaults[i] = this["eval"](arg[2]);
              results.push(arg[1]);
            } else {
              throw new Error('Parse error: invalid function argument definition');
            }
          } else {
            results.push(arg);
          }
        }
        return results;
      }).call(this);
      ctx = this;
      f = function() {
        var ctx2, j, len, ref, stat, vals;
        vals = 1 <= arguments.length ? slice.call(arguments, 0) : [];
        ctx2 = new exports.Context(ctx.vars);
        for (i = j = 0, len = args.length; j < len; i = ++j) {
          arg = args[i];
          ctx2.vars[arg] = (ref = vals[i]) != null ? ref : defaults[i];
        }
        vals = (function() {
          var len1, n, results;
          results = [];
          for (n = 0, len1 = stats.length; n < len1; n++) {
            stat = stats[n];
            results.push(ctx2["eval"](stat));
          }
          return results;
        })();
        return vals[vals.length - 1];
      };
      f.parameters = args;
      return f;
    }),
    'do': function(fn) {
      var arg;
      return fn.apply(null, (function() {
        var j, len, ref, results;
        ref = fn.parameters || [];
        results = [];
        for (j = 0, len = ref.length; j < len; j++) {
          arg = ref[j];
          results.push(this.vals[arg]);
        }
        return results;
      }).call(this));
    },
    'macro': macro(function() {
      var args, f, m, stats;
      args = arguments[0], stats = 2 <= arguments.length ? slice.call(arguments, 1) : [];
      f = this["eval"](['fn', args].concat(slice.call(stats)));
      m = macro(function() {
        var args;
        args = 1 <= arguments.length ? slice.call(arguments, 0) : [];
        return this["eval"](f.apply(null, args));
      });
      return m;
    }),
    'call': function() {
      var args, meth, obj;
      obj = arguments[0], meth = arguments[1], args = 3 <= arguments.length ? slice.call(arguments, 2) : [];
      return obj[meth].apply(obj, args);
    },
    'quote': macro(function(arg) {
      return arg;
    }),
    'atom?': macro(function(arg) {
      return typeof arg === 'string';
    }),
    'list': function() {
      var args;
      args = 1 <= arguments.length ? slice.call(arguments, 0) : [];
      return args;
    },
    'pairs': function(obj) {
      var k, results, v;
      results = [];
      for (k in obj) {
        v = obj[k];
        results.push([k, v]);
      }
      return results;
    },
    'first': function(list) {
      return list != null ? list[0] : void 0;
    },
    'rest': function(list) {
      return list != null ? list.slice(1) : void 0;
    },
    'concat': function() {
      var args, list;
      list = arguments[0], args = 2 <= arguments.length ? slice.call(arguments, 1) : [];
      return list.concat(args);
    },
    'empty?': function(list) {
      return !(list != null ? list.length : void 0);
    },
    'new': function() {
      var Obj, args;
      Obj = arguments[0], args = 2 <= arguments.length ? slice.call(arguments, 1) : [];
      return (function(func, args, ctor) {
        ctor.prototype = func.prototype;
        var child = new ctor, result = func.apply(child, args);
        return Object(result) === result ? result : child;
      })(Obj, args, function(){});
    },
    '=': macro(function(left, v) {
      var assign, tryAssign;
      assign = (function(_this) {
        return function(name, val) {
          if (Object.hasOwnProperty(_this.vars, name)) {
            throw new Error('Cannot reassign variable in this scope: ' + name);
          }
          return _this.vars[name] = val;
        };
      })(this);
      tryAssign = (function(_this) {
        return function(left, v) {
          var i, j, len, ref, results, x;
          if (Array.isArray(left) && left[0] === 'list') {
            ref = left.slice(1);
            results = [];
            for (i = j = 0, len = ref.length; j < len; i = ++j) {
              x = ref[i];
              results.push(tryAssign(x, v[i]));
            }
            return results;
          } else if (typeof left === 'string') {
            return assign(left, v);
          } else {
            throw new Error('Invalid assignment left hand side');
          }
        };
      })(this);
      return tryAssign(left, this["eval"](v));
    }),
    '==': function(a, b) {
      return a === b;
    },
    '+': function(a, b) {
      return a + b;
    },
    '-': function(a, b) {
      return a - b;
    },
    '/': function(a, b) {
      return a / b;
    },
    '*': function(a, b) {
      return a * b;
    },
    '%': function(a, b) {
      return a % b;
    },
    '.': function(a, b) {
      return a[b];
    },
    '>': function(a, b) {
      return a > b;
    },
    'instanceof': function(a, b) {
      return a instanceof b;
    },
    'regex': function(str, flags) {
      return new RegExp(str, flags);
    },
    'if': macro(function(test, t, f) {
      if (this["eval"](test)) {
        return this["eval"](t);
      } else {
        return this["eval"](f);
      }
    }),
    'loop': macro(function() {
      var arg, args, e, fn, stats, vals;
      args = arguments[0], stats = 2 <= arguments.length ? slice.call(arguments, 1) : [];
      fn = this["eval"](['fn', args].concat(slice.call(stats)));
      vals = (function() {
        var j, len, ref, results;
        ref = fn.parameters || [];
        results = [];
        for (j = 0, len = ref.length; j < len; j++) {
          arg = ref[j];
          results.push(this.vars[arg]);
        }
        return results;
      }).call(this);
      while (true) {
        try {
          return fn.apply(null, vals);
        } catch (_error) {
          e = _error;
          if (!(e instanceof FlowControl)) {
            throw e;
          }
          vals = e.args;
        }
      }
    }),
    'continue': function() {
      var args;
      args = 1 <= arguments.length ? slice.call(arguments, 0) : [];
      throw new FlowControl('continue', args);
    },
    'combine': function() {
      var expr, exprs, j, k, len, ret, v;
      exprs = 1 <= arguments.length ? slice.call(arguments, 0) : [];
      ret = {};
      for (j = 0, len = exprs.length; j < len; j++) {
        expr = exprs[j];
        for (k in expr) {
          v = expr[k];
          ret[k] = v;
        }
      }
      return ret;
    },
    'map': function(f, expr) {
      var i, j, len, results, results1, v;
      if (!Array.isArray(expr)) {
        results = [];
        for (i in expr) {
          v = expr[i];
          results.push(f(v, i));
        }
        return results;
      } else {
        results1 = [];
        for (i = j = 0, len = expr.length; j < len; i = ++j) {
          v = expr[i];
          results1.push(f(v, i));
        }
        return results1;
      }
    },
    'reduce': function(f, expr) {
      var i, j, len, results, results1, v;
      if (!Array.isArray(expr)) {
        results = [];
        for (i in expr) {
          v = expr[i];
          if (f(v, i)) {
            results.push([v, i]);
          }
        }
        return results;
      } else {
        results1 = [];
        for (i = j = 0, len = expr.length; j < len; i = ++j) {
          v = expr[i];
          if (f(v, i)) {
            results1.push(v);
          }
        }
        return results1;
      }
    },
    'print': function() {
      var args;
      args = 1 <= arguments.length ? slice.call(arguments, 0) : [];
      return console.log.apply(console, args);
    },
    'host': global
  });
};

exports["eval"] = function(code, ctx) {
  var j, len, ref, ret, stat;
  if (ctx == null) {
    ctx = new exports.DefaultContext;
  }
  ret = null;
  ref = exports.parse(code);
  for (j = 0, len = ref.length; j < len; j++) {
    stat = ref[j];
    ret = ctx["eval"](stat);
  }
  return ret;
};

if (require.main === module) {
  if (process.argv.length < 3) {
    require('./repl');
  } else {
    fs.readFile(process.argv[2], 'utf-8', function(err, code) {
      if (err) {
        console.error("Could not open file: %s", err);
        process.exit(1);
      }
      return exports["eval"](code);
    });
  }
}
