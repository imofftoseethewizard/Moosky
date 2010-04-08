// merge values into runtime
// wrap bare with asserts to make safe
// move exports for top to different module
// safe and bare should have identical api
// only switch should be which file is included
// ?debug module allows switching?

Moosky.Runtime = {};

Moosky.Runtime.Bare = (function ()
{
  var Values = Moosky.Values;
  var Symbol = Values.Symbol;
  var Keyword = Values.Keyword;
  var Cons = Values.Cons;
  var Cite = Values.Cite;
  var nil = Cons.nil;

  function isString(sexp) {
    return typeof(sexp) == 'string' || sexp instanceof Values.String;
  }

  function isNumber(sexp) {
    return typeof(sexp) == 'number' || sexp instanceof Values.Number;
  }

  function isInteger(sexp) {
    return typeof(sexp) == 'number' && sexp == Math.round(sexp) || sexp instanceof Values.Integer;
  }

  function isSymbol(sexp) {
    return sexp instanceof Values.Symbol;
  }
  
  function isKeyword(sexp) {
    return sexp instanceof Values.Keyword;
  }

  function isList(sexp) {
    return Cons.isCons(sexp);
  }

  function makeFrame(env) {
    var Frame = function () { };
    Frame.prototype = env;
    return new Frame();
  }

  function any(fn, ___) {
    var inputs = [];
    var length = Number.MAX_VALUE;

    for (var i = 1; i < arguments.length; i++) {
      inputs.push(arguments[i]);
      length = Math.min(length, arguments[i].length);
    }

    var width = inputs.length;

    for (i = 0; i < length; i++) {
      var section = [];
      for (var j = 0; j < width; j++)
	section.push(inputs[j][i]);

      var result = fn.apply(this, section);

      if (result)
	return result;
    }

    return false;
  }

  function map(fn, ___) {
    var result = [];
    var inputs = [];
    var length = Number.MAX_VALUE;

    for (var i = 1; i < arguments.length; i++) {
      inputs.push(arguments[i]);
      length = Math.min(length, arguments[i].length);
    }

    var width = inputs.length;

    for (i = 0; i < length; i++) {
      var section = [];
      for (var j = 0; j < width; j++)
	section.push(inputs[j][i]);

      result.push(fn.apply(this, section));
    }

    return result;
  }

  function range(n, m, step) {
    if (step === undefined) step = 1;
    if (m === undefined)
      start = 0, end = n;
    else
      start = n, end = m;

    var result = [];
    for (i = start; i <= end; i += step)
      result.push(i);

    return result;
  }

  function constant(v) { return function () { return v; }; }

  function filter(fn, A) {
    var result = [];
    for (var i = 0, length = A.length; i < length; i++)
      if (fn(A[i]))
	result.push(A[i]);

    return result;
  }

  var symbolCount = 0;
  function gensym(key) {
    return new Symbol('$' + (key || '') + '_' + symbolCount++);
  }

  function isNull(pair) {
    return pair === Cons.nil;
  }

  function isList(pair) {
    return Cons.isCons(pair);
  }

  function isPair(a) {
    return isList(a) && !isNull(a);
  }

  function cons(a, b) {
    return new Cons(a, b);
  }

  function car(pair) {
    return pair.$a;
  }

  function cdr(pair) {
    return pair.$d;
  }

  function setCar(pair, a) {
    pair.$a = a;
  }

  function setCdr(pair, d) {
    pair.$d = d;
  }

  function caar(pair) { return pair.$a.$a; }
  function cadr(pair) { return pair.$d.$a; }
  function cdar(pair) { return pair.$a.$d; }
  function cddr(pair) { return pair.$d.$d; }

  function caaar(pair) { return pair.$a.$a.$a; }
  function caadr(pair) { return pair.$d.$a.$a; }
  function cadar(pair) { return pair.$a.$d.$a; }
  function caddr(pair) { return pair.$d.$d.$a; }
  function cdaar(pair) { return pair.$a.$a.$d; }
  function cdadr(pair) { return pair.$d.$a.$d; }
  function cddar(pair) { return pair.$a.$d.$d; }
  function cdddr(pair) { return pair.$d.$d.$d; }

  function caaaar(pair) { return pair.$a.$a.$a.$a; }
  function caaadr(pair) { return pair.$d.$a.$a.$a; }
  function caadar(pair) { return pair.$a.$d.$a.$a; }
  function caaddr(pair) { return pair.$d.$d.$a.$a; }
  function cadaar(pair) { return pair.$a.$a.$d.$a; }
  function cadadr(pair) { return pair.$d.$a.$d.$a; }
  function caddar(pair) { return pair.$a.$d.$d.$a; }
  function cadddr(pair) { return pair.$d.$d.$d.$a; }
  function cdaaar(pair) { return pair.$a.$a.$a.$d; }
  function cdaadr(pair) { return pair.$d.$a.$a.$d; }
  function cdadar(pair) { return pair.$a.$d.$a.$d; }
  function cdaddr(pair) { return pair.$d.$d.$a.$d; }
  function cddaar(pair) { return pair.$a.$a.$d.$d; }
  function cddadr(pair) { return pair.$d.$a.$d.$d; }
  function cdddar(pair) { return pair.$a.$d.$d.$d; }
  function cddddr(pair) { return pair.$d.$d.$d.$d; }

  function list(___) {
    var list = nil;
    for (var i = arguments.length-1; i >= 0; i--)
      list = cons(arguments[i], list);

    return list;
  }

  function listStar(___) {
    var list = arguments[arguments.length-1];
    for (var i = arguments.length-2; i >= 0; i--)
      list = cons(arguments[i], list);

    return list;
  }

  function syntax(___) {
    var list = nil;
    var source = new Cite(undefined, Number.MAX_VALUE, 0);
    for (var i = arguments.length-1; i >= 0; i--) {
      var item = arguments[i];
      item && source.merge(item.$source);
      list = cons(item, list);
    }

    if (source.$text && list != nil)
      list.$source = source;

    return list;
  }

  function syntaxStar(___) {
    var list = arguments[arguments.length-1];
    var source = list && list.$source || new Cite(undefined, Number.MAX_VALUE, 0);
    for (var i = arguments.length-2; i >= 0; i--) {
      var item = arguments[i];
      item && source.merge(item.$source);
      list = cons(item, list);
    }

    if (source.$text && list != nil)
      list.$source = source;

    return list;
  }

  function reverseSyntax(list) {
    list = reverse(list);
    return mergeSources(list);
  }

  function appendSyntax(___) {
    list = append.apply(null, arguments);
    return mergeSources(list);
  }

  function mergeSources(list) {
    var source = new Cite(undefined, Number.MAX_VALUE, 0);
    var sexp = list;
    while (sexp != nil) {
      car(sexp) && source.merge(car(sexp).$source);
      sexp = cdr(sexp);
      if (!isList(sexp)) {
	sexp && source.merge(sexp.$source);
	break;
      }
    }

    if (source.$text && list != nil)
      list.$source = source;

    return list;
  }

  function length(list) {
    return list.length();
  }

  function append(___) {
    return Cons.append.apply(null, arguments);
  }

  function reverse(list) {
    return list.reverse();
  }

  function $promise(p) {
    return new Values.Promise(p);
  }

  function $force(result) {
    return (result && result.$promise) ? result.force() : result;
  }

  function values(___) {
    var value = arguments[0];

    if (arguments.length == 1)
      return value;

    value = { 'undefined': function(u) { return new Object(); },
	      'boolean':   function(b) { return new Boolean(b); },
	      'number' :   function(n) { return new Number(n); },
	      'string':    function(s) { return new String(s); },
	      'function':  function(f) { return f; },
	      'object':    function(o) { return o === null && new Object(o) || o; } }[typeof(value)](value);

    value.$values = Array.apply(Array, arguments);
    return value;
  }

  function callWithValues(values, consumer) {
    values = $force(values);
    return $force(consumer.apply(null, values && values.$values || [values]));
  }

  function numericComparator(symbol, relation) {
    return function(___) {
      if (arguments.length == 0)
	return true;

      var a, b = arguments[0].valueOf();
      for (var i = 0; i < arguments.length-1; i++) {
	a = b;
	b = arguments[i+1].valueOf();

	if (!relation(a, b)) return false;
      }

      return true;
    };
  }

  function numericFold(symbol, binop, zero) {
    return function(___) {
      if (arguments.length == 0)
	return zero;

      if (arguments.length == 1) {
	if (zero === undefined)
	  return arguments[0];
	else
	  return binop(zero, arguments[0]);
      }

      var result = arguments[0].valueOf();
      for (var i = 1; i < arguments.length; i++) {
	var a = arguments[i].valueOf();
	result = binop(result, a);
      }

      return result;
    };
  }

  function divisiveBinop(symbol, binop) {
    return function(a, b) {
      a = a.valueOf();
      b = b.valueOf();

      return binop(a, b);
    };
  }

  function numericUnop(symbol, unop) {
    return function(a) {
      return unop(a.valueOf());
    };
  }

  function numericBinop(symbol, binop) {
    return function(a, b) {
      return binop(a.valueOf(), b.valueOf());
    };
  }

  function truncate(a) {
    return a > 0 ? Math.floor(a) : Math.ceil(a);
  }

  function quotient(a, b) {
    return truncate(a/b);
  }

  function characterComparator(name, kernel, prep) {
    return function(___) {
      prep = prep || function (x) { return x; };
      var A = prep(arguments[0]).charCodeAt(0);
      for (var i = 1; i < arguments.length; i++) {
	var B = prep(arguments[i]).charCodeAt(0);
	if (!kernel(A, B))
	  return false;
      }
      return true;
    };
  }

  function characterComparatorCI(name, kernel) {
    return characterComparator(name, kernel, function(a) { return a.toLowerCase(); });
  }

  function characterPredicate(name, kernel) {
    return kernel;
  }

  var characterOperator = characterPredicate;


  function stringComparator(name, kernel, prep) {
    return function(___) {
      prep = prep || function (x) { return x; };
      var A = prep(arguments[0]);
      for (var i = 1; i < arguments.length; i++) {
	var B = prep(arguments[i]);
	if (!kernel(A, B))
	  return false;
      }
      return true;
    };
  }

  function stringComparatorCI(name, kernel) {
    return stringComparator(name, kernel, function(a) { return a.toLowerCase(); });
  }

  function stringPredicate(name, kernel) {
    return kernel;
  }

  var stringOperator = stringPredicate;


  function integerPredicate(name, kernel) {
    return kernel;
  }

  var integerOperator = integerPredicate;


  function iterator(name, collect) {
    collect = collect || function () {};

    return function(proc, lst0, ___) {
      var lsts = [lst0];
      for (var i = 2; i < arguments.length; i++) {
	var lst = arguments[i];
	lsts.push(lst);
      }

      var result = nil;
      while (true) {
	var args = [];
	for (var i = 0; i < lsts.length; i++) {
	  if (lsts[i] == nil)
	    break;

	  args.push(car(lsts[i]));
	  lsts[i] = cdr(lsts[i]);
	}

	if (i != lsts.length)
	  break;

	result = collect($force(proc.apply(this, args)), result);
      }

      return result;
    };
  }

  function vectorIterator(name, collect) {
    collect = collect || function () {};

    return function(proc, v0, ___) {
      var vs = [v0];
      var length = v0.length;
      for (var i = 2; i < arguments.length; i++)
	vs.push(arguments[i]);

      var result = nil;
      for (i = 0; i < length; i++) {
	var args = [];
	for (var j = 0; j < vs.length; j++)
	  args.push(vs[j][i]);

	result = collect($force(proc.apply(this, args)), result);
      }

      return result;
    };
  }

  function alistKeyToString(key) {
    if (isKeyword(key))
      return Symbol.munge(key.$sym.slice(0, -1));

    if (isSymbol(key))
      return Symbol.munge('S$' + key.$sym);

    if (isNumber(key))
      return Symbol.munge('N$' + key);

    if (isString(key))
      return Symbol.munge(key);

    return Symbol.munge('' + key);
  }

  function alistToObject(alist) {
    var obj = {};
    while (alist != nil) {
      var pair = car(alist);
      var key = alistKeyToString(car(pair));

      obj[key] = cdr(pair);
      alist = cdr(alist);
    }
    return obj;
  }

  function keywordToString(key) {
    return Symbol.munge(key.$sym.slice(0, -1));
  }

  function sexpToObject(sexp) {
    var original = sexp;
    var obj = {};
    while (sexp != nil) {
      var key = keywordToString(car(sexp));

      sexp = cdr(sexp);
      obj[key] = car(sexp);
      sexp = cdr(sexp);
    }
    return obj;
  }

  function argsToObject(args, first) {
    var obj = {};
    for (var i = first; i < args.length; i++) {
      var key = keywordToString(args[i]);
      i++;
      obj[key] = args[i];
    }
    return obj;
  }

  var Bare = {};
  Bare.exports = {
    isString: isString,
    isNumber: isNumber,
    isInteger: isInteger,
    isSymbol: isSymbol,
    isKeyword: isKeyword,
    isList: isList,
    any: any,
    map: map,
    range: range,
    constant: constant,
    filter: filter,
    makeFrame: makeFrame,
    gensym: gensym,
    printSexp: Cons.printSexp,
    nil: Cons.nil,
    isNull: isNull,
    isList: isList,
    isPair: isPair,
    cons: cons,
    car: car,
    cdr: cdr,
    setCar: setCar,
    setCdr: setCdr,
    caar: caar,
    cadr: cadr,
    cdar: cdar,
    cddr: cddr,
    caaar: caaar,
    caadr: caadr,
    cadar: cadar,
    caddr: caddr,
    cdaar: cdaar,
    cdadr: cdadr,
    cddar: cddar,
    cdddr: cdddr,
    caaaar: caaaar,
    caaadr: caaadr,
    caadar: caadar,
    caaddr: caaddr,
    cadaar: cadaar,
    cadadr: cadadr,
    caddar: caddar,
    cadddr: cadddr,
    cdaaar: cdaaar,
    cdaadr: cdaadr,
    cdadar: cdadar,
    cdaddr: cdaddr,
    cddaar: cddaar,
    cddadr: cddadr,
    cdddar: cdddar,
    cddddr: cddddr,
    list: list,
    listStar: listStar,
    syntax: syntax,
    syntaxStar: syntaxStar,
    length: length,
    append: append,
    reverse: reverse,
    appendSyntax: appendSyntax,
    reverseSyntax: reverseSyntax,
    $promise: $promise,
    $force: $force,
    values: values,
    callWithValues: callWithValues,
    numericComparator: numericComparator,
    numericFold: numericFold,
    divisiveBinop: divisiveBinop,
    numericUnop: numericUnop,
    numericBinop: numericBinop,
    truncate: truncate,
    quotient: quotient,
    characterComparator: characterComparator,
    characterComparatorCI: characterComparatorCI,
    characterPredicate: characterPredicate,
    characterOperator: characterPredicate,
    stringComparator: stringComparator,
    stringComparatorCI: stringComparatorCI,
    stringPredicate: stringPredicate,
    stringOperator: stringPredicate,
    integerPredicate: integerPredicate,
    integerOperator: integerPredicate,
    iterator: iterator,
    vectorIterator: vectorIterator,
    alistKeyToString: alistKeyToString,
    alistToObject: alistToObject,
    keywordToString: keywordToString,
    sexpToObject: sexpToObject,
    argsToObject: argsToObject
  };

  return Bare;
})();

