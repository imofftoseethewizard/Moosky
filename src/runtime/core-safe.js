//=============================================================================
//
//
// This file is part of Moosky.
//
// Moosky is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Moosky is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Moosky.  If not, see <http://www.gnu.org/licenses/>.
//
//
//=============================================================================

Moosky.Runtime.Safe = (function ()
{
  var Values = Moosky.Values;
  var Symbol = Values.Symbol;
  var Keyword = Values.Keyword;
  var Cons = Values.Cons;
  var Cite = Values.Cite;
  var nil = Cons.nil;

  var Bare = Moosky.Runtime.Bare;
  
  var imports = [];
  for (var p in Bare.exports)
    imports.push(['var ', p, ' = Bare.exports.', p, ';'].join(''));
  
  eval(imports.join(''));
  
  function assertMinArgs(name, count, arguments) {
    if (arguments.length < count)
      throw new SyntaxError(name + ': expects at least ' + count +
			    ' argument' + (count == 1 ? '' : 's') +
			    ': given ' + arguments.length);
  }

  function assertArgCount(name, count, arguments) {
    if (arguments.length != count)
      throw new SyntaxError(name + ': expects at exactly ' + count +
			    ' argument' + (count == 1 ? '' : 's') +
			    ': given ' + arguments.length);
  }

  function assertArgRange(name, min, max, arguments) {
    if (arguments.length < min || arguments.length > max)
      throw new SyntaxError(name + ': expects at between ' + min +
			    ' and ' + max +
			    ' arguments: given ' + arguments.length);
  }

  function assertIsList(name, lst) {
    if (!isList(lst))
      throw new SyntaxError(name + ': list expected: ' + lst);
  }

  function assertIsKeyword(name, sym) {
    if (!isKeyword(sym))
      throw new SyntaxError(name + ': keyword expected: ' + sym);
  }

  function assertIsProcedure(name, fn) {
    if (!(typeof(fn) == 'function'))
      throw new SyntaxError(name + ': procedure expected: ' + fn);
  }

  function assertIsCharacter(name, ch) {
    if (!(typeof(ch) == 'string' || ch instanceof String) || ch.length != 1)
      throw new SyntaxError(name + ': character expected: ' + ch);
  }

  function assertIsString(name, s) {
    if (!(typeof(s) == 'string' || s instanceof String))
      throw new SyntaxError(name + ': string expected: ' + s);
  }

  function assertIsInteger(name, i) {
    if (!isInteger(i) || Math.round(i) != i)
      throw new SyntaxError(name + ': integer expected: ' + i);
  }

  function assertIsNonNegativeInteger(name, i) {
    assertIsInteger(name, i);
    if (i < 0)
      throw new SyntaxError(name + ': non-negative integer expected: ' + i);
  }

  function assertIsVector(name, v) {
    if (!(v instanceof Array || typeof(v) == 'object' && v.length !== undefined))
      throw new SyntaxError(name + ': vector expected: ' + v);
  }

  function assertVectorIndexInRange(name, v, k) {
    if (k >= v.length)
      throw new SyntaxError(name + ': index ' + k + ' out of range[0, '
			      + v.length-1 + '] for vector ' + v);
  }

  function car(pair) {
    if (!isPair(pair)) {
      debugger;
      throw new SyntaxError('car: not a pair:' + pair);
    }

    return Bare.car(pair);
  }

  function cdr(pair) {
    if (!isPair(pair))
      throw new SyntaxError('cdr: not a pair:' + pair);

    return Bare.cdr(pair);
  }

  function setCar(pair, a) {
    if (!isPair(pair))
      throw new SyntaxError('setCar: not a pair:' + pair);

    Bare.setCar(pair, a);
  }

  function setCdr(pair, a) {
    if (!isPair(pair))
      throw new SyntaxError('setCdr: not a pair:' + pair);

    Bare.setCdr(pair, a);
  }

  function caar(pair) { return car(car(pair)); }
  function cadr(pair) { return car(cdr(pair)); }
  function cdar(pair) { return cdr(car(pair)); }
  function cddr(pair) { return cdr(cdr(pair)); }

  function caaar(pair) { return car(car(car(pair))); }
  function caadr(pair) { return car(car(cdr(pair))); }
  function cadar(pair) { return car(cdr(car(pair))); }
  function caddr(pair) { return car(cdr(cdr(pair))); }
  function cdaar(pair) { return cdr(car(car(pair))); }
  function cdadr(pair) { return cdr(car(cdr(pair))); }
  function cddar(pair) { return cdr(cdr(car(pair))); }
  function cdddr(pair) { return cdr(cdr(cdr(pair))); }

  function caaaar(pair) { return car(car(car(car(pair)))); }
  function caaadr(pair) { return car(car(car(cdr(pair)))); }
  function caadar(pair) { return car(car(cdr(car(pair)))); }
  function caaddr(pair) { return car(car(cdr(cdr(pair)))); }
  function cadaar(pair) { return car(cdr(car(car(pair)))); }
  function cadadr(pair) { return car(cdr(car(cdr(pair)))); }
  function caddar(pair) { return car(cdr(cdr(car(pair)))); }
  function cadddr(pair) { return car(cdr(cdr(cdr(pair)))); }
  function cdaaar(pair) { return cdr(car(car(car(pair)))); }
  function cdaadr(pair) { return cdr(car(car(cdr(pair)))); }
  function cdadar(pair) { return cdr(car(cdr(car(pair)))); }
  function cdaddr(pair) { return cdr(car(cdr(cdr(pair)))); }
  function cddaar(pair) { return cdr(cdr(car(car(pair)))); }
  function cddadr(pair) { return cdr(cdr(car(cdr(pair)))); }
  function cdddar(pair) { return cdr(cdr(cdr(car(pair)))); }
  function cddddr(pair) { return cdr(cdr(cdr(cdr(pair)))); }

  function length(list) {
    if (!isList(list))
      throw new SyntaxError('length: not a list:' + list);

    return Bare.length(list);
  }

  function reverse(list) {
    if (!isList(list))
      throw new SyntaxError('reverse: not a list:' + list);

    return Bare.reverse(list);
  }

  function values(___) {
    assertMinArgs('values', 1, arguments);
    return Bare.values.apply(null, arguments);
  }

  function callWithValues(producer, consumer) {
    assertArgCount('call-with-values', 2, arguments);
    assertIsProcedure('call-with-values', producer);
    assertIsProcedure('call-with-values', consumer);
    return Bare.callWithValues(producer, consumer);
  }

  function numericComparator(symbol, relation) {
    var comparator = Bare.numericComparator(symbol, relation);
    
    return function(___) {
      for (var i = 0; i < arguments.length-1; i++) {
	if (!isNumber(arguments[i]))
	  throw SyntaxError(symbol + ': number expected: not ' + b);
      }

      return comparator.apply(this, arguments);
    };
  }

  function numericFold(symbol, binop, zero) {
    var fold = Bare.numericFold(symbol, binop, zero);
    
    return function(___) {
      if (arguments.length == 0) {
	if (zero === undefined)
	  throw SyntaxError(symbol + ': at least one argument expected.');

      } else {
	for (var i = 0; i < arguments.length; i++) {
	  if (!isNumber(arguments[i]))
	    throw SyntaxError(symbol + ': number expected: not ' + a);
	}
      }
      
      return fold.apply(this, arguments);
    };
  }

  function divisiveBinop(symbol, binop) {
    var op = Bare.divisiveBinop(symbol, binop);
    
    return function(a, b) {
      if (arguments.length != 2)
	throw SyntaxError(symbol + ' expects 2 arguments; given ' + arguments.length);

      if (!isNumber(a))
	  throw SyntaxError(symbol + ': number expected: not ' + a);

      if (!isNumber(b))
	  throw SyntaxError(symbol + ': number expected: not ' + b);

      return op(a, b);
    };
  }

  function numericUnop(symbol, unop) {
    var op = Bare.numericUnop(symbol, unop);
    
    return function(a) {
      if (arguments.length != 1)
	throw SyntaxError(symbol + ' expects 1 argument; given ' + arguments.length);

      if (!isNumber(a))
	  throw SyntaxError(symbol + ': number expected: not ' + a);

      return op(a);
    };
  }

  function numericBinop(symbol, binop) {
    var op = Bare.numericBinop(symbol, binop);
    
    return function(a, b) {
      if (arguments.length != 2)
	throw SyntaxError(symbol + ' expects 2 arguments; given ' + arguments.length);

      if (!isNumber(a))
	  throw SyntaxError(symbol + ': number expected: not ' + a);

      if (!isNumber(b))
	  throw SyntaxError(symbol + ': number expected: not ' + b);

      return op(a, b);
    };
  }

  var truncate = Bare.truncate;
  var quotient = Bare.quotient;

  function characterComparator(name, kernel, prep) {
    var comparator = Bare.characterComparator(name, kernel, prep);
    
    return function(___) {
      assertMinArgs(name, 2, arguments);
      for (var i = 0; i < arguments.length; i++)
	assertIsCharacter(name, arguments[i]);

      return comparator.apply(this, arguments);
    };
  }

  function characterComparatorCI(name, kernel) {
    return characterComparator(name, kernel, function(a) { return a.toLowerCase(); });
  }

  function characterPredicate(name, kernel) {
    var predicate = Bare.characterPredicate(name, kernel);
    
    return function(a) {
      assertArgCount(name, 1, arguments);
      assertIsCharacter(name, a);
      return predicate(a);
    };
  }

  var characterOperator = characterPredicate;

  function stringComparator(name, kernel, prep) {
    var comparator = Bare.stringComparator(name, kernel, prep);
    
    return function(___) {
      assertMinArgs(name, 2, arguments);
      for (var i = 0; i < arguments.length; i++)
	assertIsString(name, arguments[i]);

      return comparator.apply(this, arguments);
    };
  }

  function stringComparatorCI(name, kernel) {
    return stringComparator(name, kernel, function(a) { return a.toLowerCase(); });
  }

  function stringPredicate(name, kernel) {
    var predicate = Bare.stringPredicate(name, kernel);
    return function(a) {
      assertArgCount(name, 1, arguments);
      assertIsString(name, a);
      return predicate(a);
    };
  }

  var stringOperator = stringPredicate;


  function integerPredicate(name, kernel) {
    var predicate = integerPredicate(name, kernel);
    
    return function (i) {
      assertArgCount(name, 1, arguments);
      assertIsInteger(name, i);
      return predicate(i);
    };
  }

  var integerOperator = integerPredicate;

  function iterator(name, collect) {
    var iter = Bare.iterator(name, collect);
    
    return function(proc, lst0, ___) {
      assertMinArgs(name, 2, arguments);
      assertIsProcedure(name, proc);
      assertIsList(name, lst0);

      var lsts = [lst0];
      for (var i = 2; i < arguments.length; i++)
	assertIsList(name, lst);

      return iter.apply(this, arguments);
    };
  }

  function vectorIterator(name, collect) {
    var iter = Bare.vectorIterator(name, collect);
    
    return function(proc, v0, ___) {
      assertMinArgs(name, 2, arguments);
      assertIsProcedure(name, proc);
      assertIsVector(name, v0);

      var vs = [v0];
      var length = v0.length;
      for (var i = 2; i < arguments.length; i++) {
	var v = arguments[i];
	assertIsVector(name, v);
	if (v.length != length)
	  throw new SyntaxError(name + ': all vectors must be the same length: '
				+ '(vector-length "' + v0 + '") != (vector-length "' + v + '")');
      }

      return iter.apply(this, arguments);
    };
  }

  var alistKeyToString = Bare.alistKeyToString;

  function alistToObject(alist) {
    // should use safe_iterator
    while (alist != nil) {
      var pair = car(alist);
      var key = alistKeyToString(car(pair));
      if (!key)
	throw new SyntaxError('bad alist key: ' + car(pair));

      alist = cdr(alist);
    }
    return Bare.alistToObject(alist);
  }

  function keywordToString(key) {
    if (!isKeyword(key))
      throw new Exception('keyword expected: ' + key);
    
    return Bare.keywordToString(key);
  }

  function sexpToObject(sexp) {
    var original = sexp;
    while (sexp != nil) {
      // should use safe_traverse
      var key = keywordToString(car(sexp));

      sexp = cdr(sexp);
      if (!isPair(sexp))
	throw new Exception('unexpected end of list while constructing Object: ' + sexp);

      sexp = cdr(sexp);
    }
    
    return Bare.sexpToObject(sexp);
  }

  function argsToObject(args, first) {
    for (var i = first; i < args.length; i++) {
      var key = keywordToString(args[i]);
      i++;
      if (i == args.length)
	throw new Exception('unexpected end of list while constructing Object: ('
			    + Array.apply(Array, args).join(' ') + ')');
    }
    return Bare.argsToObject(args, first);
  }

  var Safe = {};
  Safe.exports = {
    isString: isString,
    isNumber: isNumber,
    isInteger: isInteger,
    isSymbol: isSymbol,
    isKeyword: isKeyword,
    isList: isList,
    assertMinArgs: assertMinArgs,
    assertArgCount: assertArgCount,
    assertArgRange: assertArgRange,
    assertIsList: assertIsList,
    assertIsKeyword: assertIsKeyword,
    assertIsProcedure: assertIsProcedure,
    assertIsCharacter: assertIsCharacter,
    assertIsString: assertIsString,
    assertIsInteger: assertIsInteger,
    assertIsNonNegativeInteger: assertIsNonNegativeInteger,
    assertIsVector: assertIsVector,
    assertVectorIndexInRange: assertVectorIndexInRange,
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

  return Safe;
})();

