Moosky = (function ()
{
  return function (str) {
    return eval(Moosky.compile(Moosky.read(str)));
  }
})();

Moosky.Cons = (function ()
{
  function Cons(ar, dr) {
    this.ar = ar,
    this.dr = dr;
  }

  Cons.nil = new Cons();

  Cons.prototype.car = function() { return this.ar; };
  Cons.prototype.cdr = function() { return this.dr; };
  Cons.prototype.setCar = function(a) { this.ar = a };
  Cons.prototype.setCdr = function(a) { this.dr = a };

  Cons.safe_traverse = function(list, step) {
    var fast = list;
    var slow = list;

    function adv() {
      step(fast);
      fast = fast.dr;
      if (!(fast instanceof Cons)) {
	console.log(this);
	throw new SyntaxError('improper list.');
      }
    }

    while (fast !== Cons.nil) {
      adv();

      if (fast === Cons.nil)
	break;

      adv();

      slow = slow.dr;
      if (fast == slow)
	throw new SyntaxError('circular list.')
    }
  }

  Cons.prototype.length = function() {
    var length = 0;
    Cons.safe_traverse(this, function(_) { length++ });
    return length;
  }

  Cons.prototype.append = function(a) {
    var result = new Cons();
    var tail = result;

    Cons.safe_traverse(this,
		       function(lst) {
			 tail.ar = lst.ar;
			 var next = new Cons();
			 tail.dr = next;
			 tail = next;
		       });

    tail.ar = a;
    tail.dr = Cons.nil;

    return result;
  }

  Cons.prototype.reverse = function() {
    var result = Cons.nil;

    Cons.safe_traverse(this,
		       function(lst) {
			 result = new Cons(lst.ar, result);
		       });

    return result;
  }

  Cons.printSexp = function(sexp) {
    if (sexp == nil)
      return "'()";

    if (!isList(sexp))
      return sexp.toString();

    var result = [];
    while (sexp != nil) {
      if (!isList(cdr(sexp))) {
	result.push(Cons.printSexp(car(sexp)));
	result.push('.');
	result.push(Cons.printSexp(cdr(sexp)));
	break;
      }

      result.push(Cons.printSexp(car(sexp)));
      sexp = cdr(sexp);
    }

    return '(' + result.join(' ') + ')';
  }

  Cons.prototype.toString = function() { return Cons.printSexp(this); };

  var nil = Cons.nil;

  function isNull(pair) {
    return pair === Cons.nil;
  }

  function isList(pair) {
    return pair instanceof Cons;
  }

  function isPair(a) {
    return isList(a) && !isNull(a);
  }

  function cons(a, b) {
    return new Cons(a, b);
  }

  function car(pair) {
    if (!isPair(pair)) {
      debugger;
      throw new SyntaxError('car: not a pair:' + pair);
    }

    return pair.car();
  }

  function cdr(pair) {
    if (!isPair(pair))
      throw new SyntaxError('cdr: not a pair:' + pair);

    return pair.cdr();
  }

  function setCar(pair, a) {
    if (!isPair(pair))
      throw new SyntaxError('setCar: not a pair:' + pair);

    pair.setCar(a);
  }

  function setCdr(pair, a) {
    if (!isPair(pair))
      throw new SyntaxError('setCdr: not a pair:' + pair);

    pair.setCdr(a);
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

  function list(___) {
    var list = nil;
    for (var i = arguments.length-1; i >= 0; i--)
      list = cons(arguments[i], list);

    return list;
  }

  function length(list) {
    if (!isList(list))
      throw new SyntaxError('length: not a list:' + list);

    return list.length();
  }

  function append(list, a) {
    if (!isList(list))
      throw new SyntaxError('append: not a list:' + list);

    return list.append(a);
  }

  function reverse(list) {
    if (!isList(list))
      throw new SyntaxError('reverse: not a list:' + list);

    return list.reverse();
  }

  function listTail(list, n) {
  }

  function listRef(list, n) {
  }

  function memq(a, list) {
  }

  function memv(a, list) {
  }

  function member(a, list) {
  }

  function assq(a, list) {
  }

  function assv(a, list) {
  }

  function assoc(a, list) {
  }

  Cons.exports = {
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
    length: length,
    append: append,
    reverse: reverse,
    listTail: listTail,
    listRef: listRef,
    memq: memq,
    memv: memv,
    member: member,
    assq: assq,
    assv: assv,
    assoc: assoc
  };

  Cons.mooskyExports = {
    'null?': isNull,
    'list?': isList,
    'pair?': isPair,
    cons: cons,
    car: car,
    cdr: cdr,
    'set-car!': setCar,
    'set-cdr!': setCdr,
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
    length: length,
    append: append,
    reverse: reverse,
    'list-tail': listTail,
    'list-ref': listRef,
    memq: memq,
    memv: memv,
    member: member,
    assq: assq,
    assv: assv,
    assoc: assoc
  };

  return Cons;
})();

Moosky.read = (function ()
{ with (Moosky.Cons.exports)
{
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

      var result = fn.apply(null, section);

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

      result.push(fn.apply(null, section));
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

  function lex(lexemeClasses, str) {
    var lexemeClasses = map(function (lexemeClass) {
			      return { tag: lexemeClass.tag,
				       regexp: new RegExp(lexemeClass.regexp.source, 'g'),
				       normalize: lexemeClass.normalize,
				       condition: lexemeClass.condition,
				       nextMatch: { index: -1 } };
			    }, lexemeClasses);

    var lexemes = [];
    var i = 0, length = str.length;
    while (i < length) {
      var lexeme =
	any(
	  function (lexemeClass) {
	    if (lexemeClass.nextMatch === null)
	      return false;

	    if (lexemeClass.nextMatch.index < i) {
	      lexemeClass.regexp.lastIndex = i;
	      lexemeClass.nextMatch = lexemeClass.regexp.exec(str);
	    }

	    if (lexemeClass.nextMatch === null)
	      return false;

	    if (lexemeClass.nextMatch.index == i) {
	      var lexeme = new String(lexemeClass.nextMatch[0]);

	      if (lexemeClass.normalize)
		lexeme.normed = lexemeClass.normalize(lexemeClass.nextMatch);

	      if (!lexemeClass.condition || lexemeClass.condition(lexemes, lexeme)) {
		lexeme.tag = lexemeClass.tag;
		return lexeme;
	      }
	    }

	    return false;
	  }, lexemeClasses);

      if (!lexeme) {
	var preview = str.slice(Math.max(0, i-30), i);
	var remainder = str.slice(i, Math.min(length, i+30));
	var caret_position = preview.slice(preview.lastIndexOf('\n')+1).length-1;
	var message = 'lexing failure at: \n'
			+ preview + remainder + '\n'
			+ map(constant(' '), range(caret_position)).join('') + '^';

	debugger;
	throw message;
      }

      if (lexeme.length == 0) {
	throw 'zero length lexeme: ' + lexeme.tag;
	break;
      }

      lexemes.push(lexeme);
      i += lexeme.length;
    }

    return lexemes;
  }

  function parseLexemes(lexemes, i) {
    var sexp = nil;
    var dotted = false;
    var last;

    var delimiter = false;

    if (i >= 0)
      delimiter = {'[': ']', '(': ')'}[lexemes[i].toString()];

    for (var j = i+1; j < lexemes.length; j++) {
      var lexeme = lexemes[j];
      var next;
      if (lexeme.toString().match(/^[\[\(]/)) {
	var result = parseLexemes(lexemes, j);
	next = result.sexp;
	j = result.index;

      } else if (lexeme.toString() == delimiter)
	break;

      else if (lexeme.toString().match(/^[\]\)]/))
	throw 'Mismatched ' + lexemes[i] + ': found ' + lexeme[j];

      else if (lexeme.toString() == '.') {
	if (dotted)
	  throw new SyntaxError('improper dotted list');
	dotted = true;
	continue;

      } else
	next = lexemes[j];

      if (dotted) {
	if (last !== undefined)
	  throw new SyntaxError('improper dotted list');

	last = next;
	continue;
      }

      if (sexp != nil && car(sexp) != nil && car(sexp).toString() == "'") {
	var quote = new String('quote');
	quote.tag = 'symbol'
	sexp = cons(cons(quote, cons(next, nil)), cdr(sexp));
      } else
	sexp = cons(next, sexp);
    }

    if (delimiter && lexeme.toString() != delimiter) {
      throw 'Mismatched ' + lexemes[i] + ' at end of input.';
    }

    if (dotted && last === undefined) {
      throw 'Dotted list ended abruptly.'
    }

    var result = last === undefined ? nil : last;
    while (sexp != nil) {
      result = cons(car(sexp), result);
      sexp = cdr(sexp);
    }
    return { sexp: result, index: j };
  }

  function read(str) {
    var lexemes = lex(Moosky.LexemeClasses, str);

    lexemes = filter(function (lexeme) {
		       return lexeme.tag != 'comment' &&
			 lexeme.tag != 'space';
		     }, lexemes);

    var result = parseLexemes(lexemes, -1);

    return result.sexp;
  }

  function isSymbol(sexp) {
    return sexp.tag == 'symbol';
  }

  function isLiteral(sexp) {
    return sexp.tag == 'number' || sexp.tag == 'string' || sexp.tag == 'regexp' || sexp.tag == 'literal';
  }

  function isJavascript(sexp) {
    return sexp.tag == 'javascript';
  }

  function isString(sexp) {
    return sexp.tag == 'string';
  }

  function isNumber(sexp) {
    return sexp.tag == 'number';
  }

  function isRegexp(sexp) {
    return sexp.tag == 'regexp';
  }

  read.exports = {
    isSymbol: isSymbol,
    isJavascript: isJavascript,
    isLiteral: isLiteral,
    isString: isString,
    isNumber: isNumber,
    isRegexp: isRegexp
  };

  return read;
}})();

Moosky.compile = (function ()
{ with (Moosky.Cons.exports)
{ with (Moosky.read.exports)
{
  function parseSexp(sexp) {
    if (!isList(sexp))
      return parseAtom(sexp);

    var key = car(sexp);

    if (isSymbol(key)) {
      var parsers = { 'and': parseAnd,
		      'begin': parseBegin,
		      'define': parseDefine,
		      'if': parseIf,
		      'lambda': parseLambda,
		      'let': parseLet,
		      'or': parseOr,
		      'quote': parseQuote };

      var parser = parsers[key.toString()];
      if (parser)
	return parser(sexp);
    }

    return parseApplication(sexp);
  }

  function parseAtom(atom) {
    if (isSymbol(atom))
      return list('deref', atom);

    if (isLiteral(atom))
      return list('literal', atom);

    if (isJavascript(atom))
      return parseJavascript(atom);

    debugger;
    throw new SyntaxError('unknown atom type: ' + atom);
  }

  function parseAnd(sexp) {
    return cons('and', parseSequence(cdr(sexp)));
  }

  function parseOr(sexp) {
    return cons('or', parseSequence(cdr(sexp)));
  }

  function parseQuote(sexp) {
    if (length(sexp) != 2)
      throw new SyntaxError('quote: wrong number of parts.');

    return list('quote', cadr(sexp));
  }

  function parseJavascript(sexp) {
    var backquoteRE = /`([^`\\]|\\.)*`/mg;

    var text = sexp.toString().slice(1, -1);
    var interpolates = text.match(backquoteRE);
    var components = nil;
    for (var i = 0; i < interpolates.length; i++) {
      var target = interpolates[i];
      var index = text.indexOf(target);
      var js = text.substring(0, index);
      var moosky = target.slice(1, -1);
      components = cons(parseSexp(car(Moosky.read(moosky))), cons(js, components));
      text = text.substring(index + target.length);
    }

    return cons('javascript', reverse(cons(text, components)));
  }

  function parseSequence(sexp) {
    var body = nil;
    while (sexp != nil) {
      body = cons(parseSexp(car(sexp)), body);
      sexp = cdr(sexp);
    }

    return reverse(body);
  }

  function parseLambda(sexp) {
    var formals = cadr(sexp);
    if (!isList(formals)) {
      if (!isSymbol(formals))
	throw SyntaxError('lambda: symbol expected for collective formal parameter: ' + formals);
    } else {
      var formals = formals;
      while (formals != nil) {
	if (!isSymbol(car(formals)))
	  throw SyntaxError('lambda: symbol expected in formal parameter: ' + car(formals));
	formals = cdr(formals);
      }
    }
    var body = parseSequence(cddr(sexp));
    return list('lambda', formals, body)
  }

  function parseIf(sexp) {
    if (length(sexp) != 4)
      throw new SyntaxError('if: wrong number of parts.');
    return cons('if', parseSequence(cdr(sexp)));
  }

  function parseApplication(sexp) {
    var args = nil;
    while (sexp != nil) {
      args = cons(parseSexp(car(sexp)), args)
      sexp = cdr(sexp);
    }
    return cons('apply', reverse(args))
  }

  function parseBindings(sexp) {
    var bindings = nil;
    while (sexp != nil) {
      var binding = car(sexp);
      if (length(binding) != 2)
	throw new SyntaxError('improper binding: ' + binding);

      var symbol = car(binding);
      if (!isSymbol(symbol))
	throw new SyntaxError('symbol expected in binding: ' + binding);

      var value = parseSexp(cadr(binding));
      bindings = cons(cons(symbol, value), bindings);
      sexp = cdr(sexp);
    }

    return reverse(bindings);
  }

  function parseLet(sexp) {
    var bindings = parseBindings(cadr(sexp));
    var body = parseSequence(cddr(sexp));

    return list('let', bindings, body);
  }

  function parseBegin(sexp) {
    return cons('begin', parseSequence(cdr(sexp)));
  }

  function parseDefine(sexp) {
    if (length(sexp) < 3)
      throw new SyntaxError('define: wrong number of parts: ' + sexp);

    var nameClause = cadr(sexp);
    var name;
    var body;
    if (!isList(nameClause)) {
      if (!isSymbol(nameClause))
	throw new SyntaxError('define: symbol expected: ' + nameClause);
      name = nameClause;
      body = parseSexp(caddr(sexp));
    } else {
      if (!isSymbol(car(nameClause)))
	throw new SyntaxError('define: symbol expected: ' + car(nameClause));
      name = car(nameClause);

      var formals = cdr(nameClause);
      body = list('lambda', formals, parseSequence(cddr(sexp)));
    }

    return list('define', name, body);
  }

  function emit(sexp) {
    var op = car(sexp);

    return ({'and': emitAnd,
	     'apply': emitApply,
	     'define': emitDefine,
	     'begin': emitBegin,
	     'deref': emitSymbolDeref,
	     'if': emitIf,
	     'javascript': emitJavascript,
	     'lambda': emitLambda,
	     'let': emitLet,
	     'literal': emitLiteral,
	     'or': emitOr,
	     'quote': emitQuote}[car(sexp).toString()])(sexp);
  }

  function emitAnd(sexp) {
    var len = length(sexp);
    if (len == 0)
      return 'true';

    if (len == 1)
      return '(' + emit(cadr(sexp)) + ')';

    // (this.$temp = (expr)) == false ? false : ... : this.$temp)
    sexp = cdr(sexp);
    var chunks = ['('];
    while (sexp != nil) {
      chunks.push('(this.$temp = (');
      chunks.push(emit(car(sexp)))
      chunks.push(')) == false ? false : ');
      sexp = cdr(sexp);
    }
    chunks.push('this.$temp)');
    return chunks.join('');
  }

  function emitOr(sexp) {
    var len = length(sexp);
    if (len == 0)
      return 'false';

    if (len == 1)
      return '(' + emit(cadr(sexp)) + ')';

    // (this.$temp = (expr)) != false ? this.$temp : ... : false)
    sexp = cdr(sexp);
    var chunks = ['('];
    while (sexp != nil) {
      chunks.push('(this.$temp = (');
      chunks.push(emit(car(sexp)))
      chunks.push(')) != false ? this.$temp : ');
      sexp = cdr(sexp);
    }
    chunks.push('false)');
    return chunks.join('');
  }

  function emitLiteral(sexp) {
    var value = cadr(sexp);
    if (value.tag == 'regexp' || value.tag == 'number')
      return value.toString();

    if (value.tag == 'string')
      return '"' + value.normed + '"';

    if (value.tag == 'literal')
      return { '#f': 'false',
	       '#n': 'null',
	       '#t': 'true',
	       '#u': 'undefined' }[value.toString()];

    debugger;
    throw new SyntaxError('Unknown literal: ' + value.tag + ': ' + value);
  }

  function emitQuote(sexp) {
    var quoteId = Moosky.Top.$quoted.length;
    Moosky.Top.$quoted.push(cadr(sexp));
    return '(this.$quoted[' + quoteId + '])';
  }

  function emitSymbolDeref(sexp) {
    var symbol = car(cdr(sexp)).toString();
    if (symbol.match(/\./))
      return symbol;
    else
      return 'this["' + symbol + '"]'
  }

  function emitBinding(symbol, value) {
    return 'env["' + symbol.toString() + '"] = ' + value + ';\n';
  }

  function emitSequence(sexp) {
    var values = [];
    while (sexp != nil) {
      values.push(emit(car(sexp)));
      sexp = cdr(sexp);
    }
    return '(' + values.join('), (') + ')';
  }

  function emitLambda(sexp) {
    var formals = cadr(sexp);
    var body = emitSequence(caddr(sexp));

    var bindings = [];
    if (isSymbol(formals))
      bindings.push(emitBinding(formals, 'this.$argumentsList(arguments, 0)'));

    else {
      var i = 0;
      while (formals != nil) {
	if (!isList(formals))
	  bindings.push(emitBinding(formals, 'this.$argumentsList(arguments, ' + i + ')'));

	else
	  bindings.push(emitBinding(car(formals), 'arguments[' + i + ']'));

	formals = cdr(formals);
	i++;
      }
    }

    return '(function () {\n'
      + 'var env = this.$makeFrame(this);\n'
      + bindings.join('')
      + 'return (function () {\n'
      + 'return ' + body + ';\n'
      + '}).call(env);\n'
      + '})\n';
  }

  function emitLet(sexp) {
    var bindings = cadr(sexp);
    var formals = nil;
    var params = nil;
    while (bindings != nil) {
      var binding = car(bindings);
      formals = cons(car(binding), formals);
      params = cons(cdr(binding), params);
      bindings = cdr(bindings);
    }
    var body = caddr(sexp);
    var lambda = list('lambda', reverse(formals), body);
    return emitApply(cons('apply', cons(lambda, reverse(params))));
  }

  function emitIf(sexp) {
    var test = emit(car(sexp = cdr(sexp)));
    var consequent = emit(car(sexp = cdr(sexp)));
    var alternate = emit(car(sexp = cdr(sexp)));
    return '((' + test + ')' + ' ? (' + consequent + ') : (' + alternate + '))';
  }

  function emitApply(sexp) {
    var func = emit(cadr(sexp));
    var actuals = cddr(sexp);

    var isPrimitive = isSymbol(cadr(sexp)) && func.match(/\./);

    var values = [];
    while (actuals != nil) {
      values.push(emit(car(actuals)));
      actuals = cdr(actuals);
    }

    if (isPrimitive)
      return func + '(' + values.join(', ') + ')';

    return '(' + func + ').call(this, ' + values.join(', ') + ')';
  }

  function emitDefine(sexp) {
    var name = cadr(sexp).toString();
    var body = emit(caddr(sexp));
    return 'this["' + name + '"] = (' + body + ')';
  }

  function emitBegin(sexp) {
    return emitSequence(cdr(sexp));
  }

  function emitJavascript(sexp) {
    sexp = cdr(sexp);
    var chunks = [];
    while (sexp != nil) {
      chunks.push(car(sexp));
      sexp = cdr(sexp);
      if (sexp != nil) {
	chunks.push('(' + emit(car(sexp)) + ')');
	sexp = cdr(sexp);
      }
    }
    return '(function () { ' + chunks.join('') + '}).call(this)';
  }

  return function compile(sexp) {
    var result = '(function () {\n'
		+ 'return ' + emit(parseBegin(cons('begin', sexp))) + ';\n'
		+ '}).call(Moosky.Top);';
    console.log(result);
    return eval(result);
  }
}}})();

Moosky.Top = (function ()
{ with (Moosky.Cons.exports)
{ with (Moosky.read.exports)
{
  function numericComparator(symbol, relation) {
    return function(___) {
      if (arguments.length == 0)
	return true;

      if (typeof(arguments[0]) != 'number')
	throw SyntaxError(symbol + ': number expected: not ' + arguments[0]);

      var a, b = arguments[0];
      for (var i = 0; i < arguments.length-1; i++) {
	a = b;
	b = arguments[i+1];

	if (typeof(b) != 'number')
	  throw SyntaxError(symbol + ': number expected: not ' + b);

	if (!relation(a, b)) return false;
      }

      return true;
    }
  }

  function numericFold(symbol, binop, zero) {
    return function(___) {
      if (arguments.length == 0) {
	if (zero === undefined)
	  throw SyntaxError(symbol + ': at least one argument expected.');

	return zero;
      }

      if (typeof(arguments[0]) != 'number')
	throw SyntaxError(symbol + ': number expected: not ' + arguments[0]);

      if (arguments.length == 1) {
	if (zero === undefined)
	  return arguments[0];
	else
	  return binop(zero, arguments[0]);
      }

      var result = arguments[0];
      for (var i = 1; i < arguments.length; i++) {
	var a = arguments[i];
	if (typeof(a) != 'number')
	  throw SyntaxError(symbol + ': number expected: not ' + a);

	result = binop(result, a);
      }

      return result;
    }
  }

  function divisiveBinop(symbol, binop) {
    return function(a, b) {
      if (arguments.length != 2)
	throw SyntaxError(symbol + ' expects 2 arguments; given ' + arguments.length);

      if (typeof(a) != 'number')
	  throw SyntaxError(symbol + ': number expected: not ' + a);

      if (typeof(b) != 'number')
	  throw SyntaxError(symbol + ': number expected: not ' + b);

      if (typeof(b) == 0)
	throw SyntaxError(symbol + ': division by zero');

      return binop(a, b);
    }
  }

  function numericUnop(symbol, unop) {
    return function(a) {
      if (arguments.length != 1)
	throw SyntaxError(symbol + ' expects 1 argument; given ' + arguments.length);

      if (typeof(a) != 'number')
	  throw SyntaxError(symbol + ': number expected: not ' + a);

      return unop(a);
    }
  }

  function numericBinop(symbol, binop) {
    return function(a, b) {
      if (arguments.length != 2)
	throw SyntaxError(symbol + ' expects 2 arguments; given ' + arguments.length);

      if (typeof(a) != 'number')
	  throw SyntaxError(symbol + ': number expected: not ' + a);

      if (typeof(b) != 'number')
	  throw SyntaxError(symbol + ': number expected: not ' + b);

      return binop(a, b);
    }
  }

  function truncate(a) {
    return a > 0 ? Math.floor(a) : Math.ceil(a);
  }

  function quotient(a, b) {
    return truncate(a/b);
  }

  var Top = {
    $argumentsList: function(args, n) {
      var list = nil;
      for (var i = args.length-1; i >= n; i--)
	list = cons(args[i], list);

      return list;
    },

    $quoted: [],

    $makeFrame: function (env) {
      var Frame = function () { };
      Frame.prototype = env;
      return new Frame();
    },

    '#f': false,
    '#n': null,
    '#t': true,
    '#u': undefined,

    alert: function(v) {
      alert(v);
      return true;
    },

    'eqv?': function(a, b) {
      if (arguments.length != 2)
	throw SyntaxError('eqv?: 2 arguments expected; got ' + arguments.length);

      return a === b
	|| isSymbol(a) && isSymbol(b) && a.toString() == b.toString()
	|| isNumber(a) && isNumber(b) && a == b
	|| isString(a) && isString(b) && a == b;
    },

    'eq?': function(a, b) {
      if (arguments.length != 2)
	throw SyntaxError('eq?: 2 arguments expected; got ' + arguments.length);

      return a === b
	|| isSymbol(a) && isSymbol(b) && a.toString() == b.toString()
	|| isNumber(a) && isNumber(b) && a == b
	|| isString(a) && isString(b) && a == b;
    },

    'equal?': function(a, b) {
      if (arguments.length != 2)
	throw SyntaxError('equal?: 2 arguments expected; got ' + arguments.length);

      if (Top['eq?'](a, b))
	return true;

      if (!isList(a) || !isList(b))
	return false;

      return Top['equal?'](car(a), car(b)) && Top['equal?'](cdr(a), cdr(b));
    },

    'number?': function(a) {
      return typeof(a) == 'number';
    },

    'complex?': function(a) {
      return false;
    },

    'real?': function(a) {
      return Top['number?'](a);
    },

    'rational?': function(a) {
      return false;
    },

    'integer?': function(a) {
      return false;
    },

    'exact?': function(a) {
      return false;
    },

    'inexact?': function(a) {
      return Top['number?'](a);
    },

    '=': numericComparator('=', function(a, b) { return a == b; }),
    '<': numericComparator('<', function(a, b) { return a < b; }),
    '>': numericComparator('>', function(a, b) { return a > b; }),
    '<=': numericComparator('<=', function(a, b) { return a <= b; }),
    '>=': numericComparator('>=', function(a, b) { return a >= b; }),

    'zero?': function(a) {
      return typeof(a) == 'number' && a == 0;
    },

    'positive?': function(a) {
      return typeof(a) == 'number' && a > 0;
    },

    'negative?': function(a) {
      return typeof(a) == 'number' && a < 0;
    },

    'odd?': function(a) {
      return typeof(a) == 'number' && Math.abs(a % 2) == 1;
    },

    'even?': function(a) {
      return typeof(a) == 'number' && a % 2 == 0;
    },

    max: numericFold('max', function(m, a) { return m > a ? m : a }),
    min: numericFold('min', function(m, a) { return m < a ? m : a }),
    '+': numericFold('+', function(s, a) { return s + a; }, 0),
    '-': numericFold('-', function(d, a) { return d - a; }, 0),
    '*': numericFold('+', function(p, a) { return p * a; }, 1),
    '/': numericFold('-',
		     function(q, a) {
		       if (a == 0)
			 throw SyntaxError('/: division by zero.');
		       return q / a;
		     }, 1),

    quotient: divisiveBinop('quotient', quotient),
    remainder: divisiveBinop('remainder', function(a, b) { return a - quotient(a, b)*b; }),
    modulo: divisiveBinop('modulo', function(a, b) { return a - Math.floor(a/b)*b; }),

    floor: numericUnop('floor', function(a) { return Math.floor(a); }),
    ceiling: numericUnop('ceiling', function(a) { return Math.ceil(a); }),
    truncate: numericUnop('truncate', function(a) { return truncate(a); }),
    round: numericUnop('round', function(a) { return Math.round(a); }),

    exp: numericUnop('exp', function(a) { return Math.exp(a); }),
    log: numericUnop('log', function(a) { return Math.log(a); }),
    sin: numericUnop('sin', function(a) { return Math.sin(a); }),
    cos: numericUnop('cos', function(a) { return Math.cos(a); }),
    tan: numericUnop('tan', function(a) { return Math.tan(a); }),
    asin: numericUnop('asin', function(a) { return Math.asin(a); }),
    acos: numericUnop('acos', function(a) { return Math.acos(a); }),
    atan: function(a, b) {
      if (arguments.length == 0 || arguments.length > 2)
	throw SyntaxError('atan expects 1 or 2 arguments; given ' + arguments.length);

      if (typeof(a) != 'number')
	  throw SyntaxError('atan: number expected: not ' + a);

      if (arguments.length == 1)
	return Math.atan(a);

      if (typeof(b) != 'number')
	throw SyntaxError('atan: number expected: not ' + b);

      return Math.atan2(a, b);
    },

    sqrt: numericUnop('sqrt', function(a) {
			if (a < 0)
			  throw SyntaxError('sqrt: negative argument not supported.');
			return Math.sqrt(a);
		      }),

    expt: numericBinop('expt', function(a, b) { return Math.pow(a, b); }),

    'string->number': function(str, radix) {
      if (typeof(a) != 'string')
	throw SyntaxError('string->number: string expected: ' + a);

      if (radix === undefined)
	return parseFloat(str);

      return parseInt(str, radix);
    },

    'number->string': function(a, radix) {
      if (typeof(a) != 'number')
	throw SyntaxError('number->string: number expected: ' + a);

      return (new Number(a)).toString(radix);
    },

    not: function(a) {
      if (arguments.length != 1)
	throw SyntaxError('not: expects a single argument; got ' + arguments.length);

      return a == false;
    },

    'boolean?': function(a) {
      if (arguments.length != 1)
	throw SyntaxError('not: expects a single argument; got ' + arguments.length);

      return a == true || a == false;
    }


  };

  for (p in Moosky.Cons.mooskyExports) {
    Top[p] = Moosky.Cons.mooskyExports[p];
  }

  return Top;
}}})();

Moosky.LexemeClasses = [ { tag: 'comment',
			 regexp: /;.*/ },

			{ tag: 'space',
			  regexp: /(\s|\n)+/ },

			{ tag: 'literal',
			  regexp: /#f|#n|#t|#u/ },

			{ tag: 'number',
			  regexp: /-?0?\.\d+|-?[1-9]\d*(\.\d*)?([eE][+-]?\d+)?|-?0([xX][0-9a-fA-F]+)?/ },

			{ tag: 'string',
			  regexp: /"(([^"\\]|\\.)*)"/, //"
			  normalize: function(match) {
			    return new String(match[1]);
			  }
			},

			{ tag: 'string',
			  regexp: /#<<\n(((([^>\n]|>[^>\n]|>>[^#\n])[^\n]*)?)(\n(([^>\n]|>[^>\n]|>>[^#\n])[^\n]*)?)*)\n>>#/m,
			  normalize: function(match) {
			    return (new String(match[1])).replace(/\n/g, '\\n');
			  }
			},

			{ tag: 'regexp',
			  regexp: /#\/([^\/\\]|\\.)*\// },

			{ tag: 'javascript',
			  regexp: /\{[^}]*\}/ },

			{ tag: 'javascript',
			  regexp: /#\{([^\}]|\}[^#])*\}#/m },

			{ tag: 'punctuation',
			  regexp: /[\.\(\)\[\]']/ }, //'

			{ tag: 'symbol',
			  regexp: /[^#$\d\n\s\(\)\[\]'".`][^$\n\s\(\)"'`\[\]]*/ }
		      ];
