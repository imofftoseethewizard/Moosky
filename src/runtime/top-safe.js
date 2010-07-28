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

(function ()
{
  var Bare = Moosky.Runtime.Bare.Top;
  var Safe = Moosky.Runtime.Safe.Top = {};
  
  for (var p in Bare)
    Safe[p] = Bare[p];

//  with (Moosky.Runtime.exports) {
  {
    eval(Moosky.Runtime.importExpression);
    
    function assertIsSymbolOrKeyword(name, sym) {
      if (!isSymbol(sym) && !isKeyword(sym))
	throw new SyntaxError(name + ': symbol expected: ' + sym);
    }

    var wrappers = {
      $quasiUnquote: function(sexp, lambdas) {
	if (isPair(sexp)) {
	  var A = car(sexp);
	  if (isSymbol(A)) {
	    if (A == 'unquote-splicing')
	      throw new SyntaxError('quasiquote: illegal splice' + sexp);
	  }
	}

	return Bare.$quasiUnquote(sexp, lambdas);
      },
      
      'eqv?': function(a, b) {
	assertArgCount('eqv?', 2, arguments);
	return Bare['eqv?'](a, b);
      },

      'eq?': function(a, b) {
	assertArgCount('eq?', 2, arguments);
	return Bare['eq?'](a, b);
      },

      'equal?': function(a, b) {
	assertArgCount('equal?', 2, arguments);
	return Bare['equal?'](a, b);
      },

      '/': numericFold('/',
		       function(q, a) {
			 if (a == 0)
			   throw SyntaxError('/: division by zero.');
			 return q / a;
		       }, 1),

      atan: function(a, b) {
	if (arguments.length == 0 || arguments.length > 2)
	  throw SyntaxError('atan expects 1 or 2 arguments; given ' + arguments.length);

	if (!isNumber(a))
	    throw SyntaxError('atan: number expected: not ' + a);

	if (arguments.length == 2 && isNumber(b))
	  throw SyntaxError('atan: number expected: not ' + b);

	return Bare.atan(a, b);
      },

      sqrt: numericUnop('sqrt', function(a) {
			  if (a < 0)
			    throw SyntaxError('sqrt: negative argument not supported.');
			  return Math.sqrt(a);
			}),

      'string->number': function(str, radix) {
	if (typeof(a) != 'string')
	  throw SyntaxError('string->number: string expected: ' + a);
	
	return Bare['string->number'](str, radix);
      },

      'number->string': function(a, radix) {
	assertNonNegativeInteger('number->string', radix);
	return Bare['number->string'](a, radix);
      },

      not: function(a) {
	if (arguments.length != 1)
	  throw SyntaxError('not: expects a single argument; got ' + arguments.length);
	return Bare.not(a);
      },

      'boolean?': function(a) {
	if (arguments.length != 1)
	  throw SyntaxError('not: expects a single argument; got ' + arguments.length);

	return Bare['boolean?'](a);
      },

      'make-string': function(k, ch) {
	assertArgRange('make-string', 1, 2, arguments);
	assertIsNonNegativeInteger('make-string', k);

	assertIsCharacter('make-string', ch !== undefined ? ch : ' ');
	return Bare['make-string'](l, ch);
      },

      'string': function(___) {
	for (var i = 0; i < arguments.length; i++)
	  assertIsCharacter('string', arguments[i]);
	
	return Bare.string.apply(this, arguments);
      },

      'string-ref': function(s, k) {
	assertArgCount('string-ref', 2, arguments);
	assertIsString('string-ref', s);
	assertIsNonNegativeInteger('string-ref', k);
	return Bare['string-ref'](s, k);
      },

      'substring': function(s, start, end) {
	assertArgCount('substring', 2, arguments);
	assertIsNonNegativeInteger('substring', start);
	assertIsNonNegativeInteger('substring', end);
	if (end < start)
	  throw new SyntaxError('substring: end < start.');
	
	return Bare['substring'](s, start, end);
      },

      'string-append': function(___) {
	for (var i = 0; i < arguments.length; i++)
	  assertIsString('string-append', arguments[i]);

	return Bare['string-append'].apply(this, arguments);
      },

      'string->list': function(s) {
	assertArgCount('string->list', 1, arguments);
	assertIsString('string->list', s);
	return Bare['string->list'](s);
      },

      'list->string': function(lst) {
	assertArgCount('list->string', 1, arguments);
	assertIsList('list->string', lst);

	while (lst != nil) {
	  var ch = car(lst);
	  assertIsCharacter('list->string', ch);
	  lst = cdr(lst);
	}

	return Bare['list->string'](lst);
      },

      'string-copy': function(s) {
	assertArgCount('string-copy', 1, arguments);
	assertIsString('string-copy', s);
	return Bare['string-copy'](s);
      },

      'string-for-each': function(proc, s0, ___) {
	assertMinArgs('string-for-each', 2, arguments);
	assertIsProcedure('string-for-each', proc);
	assertIsString('string-for-each', s0);

	var length = s0.length;
	for (var i = 2; i < arguments.length; i++) {
	  var s = arguments[i];
	  assertIsString('string-for-each', s);
	  if (s.length != length)
	    throw new SyntaxError('string-for-each: all strings must be the same length: '
				  + '(string-length "' + s0 + '") != (string-length "' + s + '")');

	}
	
	return Bare['string-for-each'].apply(this, arguments);
      },

      'vector?': function(v) {
	assertArgCount('vector?', 1, arguments);
	return Bare['vector?'](v);
      },

      'make-vector': function(k, obj) {
	assertArgRange('make-vector', 1, 2, arguments);
	assertIsNonNegativeInteger('make-vector', k);
	return Bare['make-vector'](k, obj);
      },

      'vector-length': function(v) {
	assertArgCount('vector-length', 1, arguments);
	assertIsVector('vector-length', v);
	return Bare['vector-length'](v);
      },

      'vector-ref': function(v, k) {
	assertArgCount('vector-ref', 2, arguments);
	assertIsVector('vector-ref', v);
	assertIsNonNegativeInteger('vector-ref', k);
	assertVectorIndexInRange(v, k);
	return Bare['vector-ref'](v, k);
      },

      'vector-set!': function(v, k, obj) {
	assertArgCount('vector-set!', 3, arguments);
	assertIsVector('vector-set!', v);
	assertIsNonNegativeInteger('vector-set!', k);
	assertVectorIndexInRange(v, k);
	return Bare['vector-set!'](v, k, obj);
      },

      'vector->list': function(v) {
	assertArgCount('vector->list', 1, arguments);
	assertIsVector('vector->list', v);
	return Bare['vector->list'](v);
      },

      'list->vector': function(lst) {
	assertArgCount('list->vector', 1, arguments);
	assertIsList('list->vector', lst);
	return Bare['list->vector'](lst);
      },

      'symbol?': function(s) {
	assertArgCount('symbol?', 1, arguments);
	return Bare['symbol?'](s);
      },

      'keyword?': function(k) {
	assertArgCount('keyword?', 1, arguments);
	return Bare['keyword?'](k);
      },

      'symbol->string': function(sym) {
	assertIsSymbolOrKeyword('symbol->string', sym);
	assertArgCount('symbol->string', 1, arguments);
	return Bare['symbol->string'](sym);
      },

      'string->symbol': function(s) {
	assertIsString('string->symbol', s);
	assertArgCount('string->symbol', 1, arguments);
	return Bare['string->symbol'](s);
      },

      'procedure?': function(p) {
	assertArgCount('procedure?', 1, arguments);
	return Bare['procedure?'](p);
      },


      'apply': function(proc, ___, lst) {
	assertMinArgs('apply', 2, arguments);
	assertIsProcedure('apply', proc);
	var tailIndex = arguments.length-1;
	var tail = arguments[tailIndex];
	if (!isList(tail))
	  throw new SyntaxError('apply: last argument must be a list: ' + tail);

	return Bare['apply'].apply(this, arguments);
      },

      '?>>': function() {
	var insp = Moosky.Top.$lastInspector;
	if (insp && insp.children.length > 0)
	  Moosky.Top.$lastInspector = insp.children[insp.children.length-1];
      },

      '<<?': function() {
	var insp = Moosky.Top.$lastInspector;
	if (insp && insp.inspector)
	  Moosky.Top.$lastInspector = insp.inspector;
      },

      ':?': function() {
	var insp = Moosky.Top.$lastInspector;
	return insp && insp.citation.content();
      },

      '?frames': function() {
	var topInsp = Moosky.Top.$lastInspector;

	if (!topInsp)
	  return nil;
	while (topInsp.inspector != null)
	  topInsp = topInsp.inspector;

	var insp = topInsp;
	var inspectors = nil;
	while (insp.children.length > 0) {
	  inspectors = cons(insp, inspectors);
	  insp = insp.children[insp.children.length-1];
	}
	return inspectors;
      },

      version: function() {
	return Moosky.Version;
      }
    };
    
    for (p in wrappers)
      Safe[p] = wrappers[p];
  }
})();
