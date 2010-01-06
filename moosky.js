Moosky = (function ()
{
  return function (str, env) {
    return eval(Moosky.compile(Moosky.read(str), env));
  };
})();

Moosky.Cons = (function ()
{
  function Cons(a, d) {
    this.$a = a,
    this.$d = d;
  }

  Cons.nil = new Cons();

  Cons.prototype.car = function() { return this.$a; };
  Cons.prototype.cdr = function() { return this.$d; };
  Cons.prototype.setCar = function(a) { this.$a = a; };
  Cons.prototype.setCdr = function(a) { this.$d = a; };

  Cons.safe_traverse = function(list, step) {
    var fast = list;
    var slow = list;

    function adv() {
      step(fast);
      fast = fast.$d;
      if (!(fast instanceof Cons)) {
	throw new SyntaxError('improper list.');
      }
    }

    while (fast !== Cons.nil) {
      adv();

      if (fast === Cons.nil)
	break;

      adv();

      slow = slow.$d;
      if (fast == slow)
	throw new SyntaxError('circular list.');
    }
  };

  Cons.prototype.length = function() {
    var length = 0;
    Cons.safe_traverse(this, function(_) { length++ });
    return length;
  };

  Cons.prototype.reverse = function() {
    var result = Cons.nil;

    Cons.safe_traverse(this,
		       function(lst) {
			 result = new Cons(lst.$a, result);
		       });

    return result;
  };

  Cons.append = function(___) {
    var argCount = arguments.length;

    if (argCount == 0)
      return Cons.nil;

    var resultHead = new Cons();
    var tail = resultHead;

    for (var i = 0; i < argCount-1; i++) {
      Cons.safe_traverse(arguments[i],
			 function(lst) {
			   var next = new Cons();
			   tail.$d = next;
			   tail = next;
			   tail.$a = lst.$a;
			 });
    }

    tail.$d = arguments[argCount-1];

    return cdr(resultHead);
  };

  Cons.printSexp = function(sexp) {
    if (sexp == nil)
      return "'()";

    if (!isList(sexp)) {
      switch (sexp) {
	case false: return '#f';
	case null: return '#n';
	case true: return '#t';
	case undefined: return '#u';
      }
      return sexp.toString();
    }

    var result = [];
    while (sexp != nil) {
      var A = car(sexp);
      var D = cdr(sexp);

      if (!isList(D)) {
	result.push(Cons.printSexp(A));
	result.push('.');
	result.push(Cons.printSexp(D));
	break;
      }

      if (result.length == 0 && !isList(A) && A.tag == 'symbol' && A.toString() == 'quote'
	 && cdr(D) == nil)
	return "'" + Cons.printSexp(car(D));

      result.push(Cons.printSexp(A));
      sexp = D;
    }

    return '(' + result.join(' ') + ')';
  };

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

  function listStar(___) {
    var list = arguments[arguments.length-1];
    for (var i = arguments.length-2; i >= 0; i--)
      list = cons(arguments[i], list);

    return list;
  }

  function length(list) {
    if (!isList(list))
      throw new SyntaxError('length: not a list:' + list);

    return list.length();
  }

  function append(___) {
    return Cons.append.apply(null, arguments);
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
    'list*': listStar,
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
    lexemeClasses = map(function (lexemeClass) {
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

      if (sexp == nil || car(sexp) == nil)
	sexp = cons(next, sexp);

      else {
	var key = car(sexp).toString();
	var translated = { "'": 'quote',
			   '`': 'quasiquote',
			   ',': 'unquote',
			   ',@': 'unquote-splicing' }[key];

	if (translated === undefined)
	  sexp = cons(next, sexp);
	else
	  sexp = cons(cons(makeSymbol(translated), cons(next, nil)), cdr(sexp));
      }
    }

    if (delimiter && lexeme.toString() != delimiter) {
      throw 'Mismatched ' + lexemes[i] + ' at end of input.';
    }

    if (dotted && last === undefined) {
      throw 'Dotted list ended abruptly.';
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

  function makeToken(tag, str) {
    var token = new String(str);
    token.tag = tag;

    return token;
  }

  function makeSymbol(str) {
    return makeToken('symbol', str);
  }

  function makeLiteral(str) {
    return makeToken('literal', str);
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
    makeSymbol: makeSymbol,
    makeLiteral: makeLiteral,
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
  function isMacro(v) {
    console.log(v);
    return v !== undefined && typeof v == 'function' && v.tag == 'macro';
  }

  function parseSexp(sexp, env) {
    if (env === undefined) {
      debugger;
    }

    if (!isList(sexp))
      return parseAtom(sexp);

    var key = car(sexp);

    if (isSymbol(key)) {
      var parsers = { 'and': parseAnd,
		      'begin': parseBegin,
		      'case': parseCase,
		      'cond': parseCond,
		      'define': parseDefine,
		      'define-macro': parseDefineMacro,
		      'if': parseIf,
		      'lambda': parseLambda,
		      'let': parseLet,
		      'let*': parseLetStar,
		      'letrec': parseLetrec,
		      'letrec*': parseLetrec,
		      'or': parseOr,
		      'quote': parseQuote,
		      'quasiquote': parseQuasiQuote,
		      'set!': parseSet };

      var parser = parsers[key.toString()];
      if (parser)
	return parser(sexp, env);

      var applicand = env[key];
      if (isMacro(applicand))
	return parseSexp(applicand.call(applicand.env, sexp), env);
    }

    return parseApplication(sexp, env);
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

  function parseApplication(sexp, env) {
    var args = nil;
    while (sexp != nil) {
      args = cons(parseSexp(car(sexp), env), args);
      sexp = cdr(sexp);
    }
    return cons('apply', reverse(args));
  }

  function parseBindings(sexp, env) {
    var bindings = nil;
    while (sexp != nil) {
      var binding = car(sexp);
      if (length(binding) != 2)
	throw new SyntaxError('improper binding: ' + binding);

      var symbol = car(binding);
      if (!isSymbol(symbol))
	throw new SyntaxError('symbol expected in binding: ' + binding);

      var value = parseSexp(cadr(binding), env);
      bindings = cons(cons(symbol, value), bindings);
      sexp = cdr(sexp);
    }

    return reverse(bindings);
  }

  function parseSequence(sexp, env) {
    var body = nil;
    while (sexp != nil) {
      body = cons(parseSexp(car(sexp), env), body);
      sexp = cdr(sexp);
    }

    return reverse(body);
  }

  function parseAnd(sexp, env) {
    return cons('and', parseSequence(cdr(sexp), env));
  }

  function parseBegin(sexp, env) {
    return cons('begin', parseSequence(cdr(sexp), env));
  }

  function parseCase(sexp, env) {
    var key = cadr(sexp);
    var caseClauses = nil;

    var temp = makeSymbol('$key');
    var eqvp = makeSymbol('eqv?');
    var or_ = makeSymbol('or');
    var quote = makeSymbol('quote');
    var begin = makeSymbol('begin');

    sexp = cddr(sexp);
    while (sexp != nil) {
      try {
	var clause = car(sexp);
	var data = car(clause);
	var expressions = cdr(clause);

	var elseClause = isSymbol(data) && data.toString() == 'else';

	if (cdr(sexp) != nil && elseClause || !elseClause && !isList(data)
	    || expressions == nil)
	  throw new SyntaxError();

	var test;
	if (elseClause)
	  test = makeLiteral('#t');

	else {
	  test = nil;
	  while (data != nil) {
	    var datum = car(data);
	    if (isSymbol(datum))
	      datum = list(quote, datum);

	    test = cons(list(eqvp, temp, datum), test);
	    data = cdr(data);
	  }

	  test = cons(or_, test);
	}

	if (cdr(expressions) == nil)
	  expressions = car(expressions);
	else
	  expressions = cons(begin, expressions);

	caseClauses = cons(cons(test, expressions), caseClauses);

      } catch(e) {
	throw new SyntaxError('bad case clause: ' + clause);
      }
      sexp = cdr(sexp);
    }

    var result = makeLiteral('#u');
    var if_ = makeSymbol('if');
    while (caseClauses != nil) {
      var clause = car(caseClauses);
      result = listStar(if_, car(clause), cdr(clause), list(result));
      caseClauses = cdr(caseClauses);
    }

    result = list(makeSymbol('let'), list(list(temp, key)), result)
    return parseSexp(result, env);
  }

  function parseCond(sexp, env) {
    var condClauses = nil;
    sexp = cdr(sexp);
    while (sexp != nil) {
      var clause = car(sexp);
      try {
	var test = car(clause);
	var elseClause = isSymbol(test) && test.toString() == 'else';
	var expressions = cdr(clause);

	function makeAnaphoricTest(test) {
	  // ironically, this is implemented as an epistrophe
	  return list(makeSymbol('begin'),
		      list(makeSymbol('set!'), makeSymbol('$temp'), test),
		      makeSymbol('$temp'));
	}

	if (expressions == nil) {
	  test = makeAnaphoricTest(test);
	  expressions = list(makeSymbol('$temp'));

	} else {
	  var expr_1 = car(expressions);
	  var anaphoric = isSymbol(expr_1) && expr_1.toString() == '=>';

	  if (anaphoric) {
	    test = makeAnaphoricTest(test);

	    expressions = cdr(expressions);
	    if (cdr(expressions) != nil)
	      throw new SyntaxError();

	    expressions = list(list(car(expressions), makeSymbol('$temp')));
	  }

	  if (expressions == nil)
	    throw new SyntaxError();
	}

	if (cdr(expressions) == nil)
	  expressions = car(expressions);
	else
	  expressions = cons(makeSymbol('begin'), expressions);

	test = parseSexp(test, env);
	expressions = parseSexp(expressions, env);

	condClauses = cons(cons(test, expressions), condClauses);

      } catch (e) {
	throw new SyntaxError('bad cond clause: ' + clause);
      }

      sexp = cdr(sexp);
    }

    var result = list('literal', makeLiteral('#u'));
    var if_ = makeSymbol('if');
    while (condClauses != nil) {
      var clause = car(condClauses);
      result = listStar(if_, car(clause), cdr(clause), list(result));
      condClauses = cdr(condClauses);
    }

    return result;
  }

  function parseDefine(sexp, env) {
    if (length(sexp) < 3)
      throw new SyntaxError('define: wrong number of parts: ' + sexp);

    var nameClause = cadr(sexp);
    var name;
    var body;
    if (!isList(nameClause)) {
      if (!isSymbol(nameClause))
	throw new SyntaxError('define: symbol expected: ' + nameClause);
      name = nameClause;
      body = parseSexp(caddr(sexp), env);
    } else {
      if (!isSymbol(car(nameClause)))
	throw new SyntaxError('define: symbol expected: ' + car(nameClause));
      name = car(nameClause);

      var formals = cdr(nameClause);
      body = list('lambda', formals, parseSequence(cddr(sexp), env));
    }

    return list('define', name, body);
  }

  function parseDefineMacro(sexp, env) {
    var name;
    var nameClause = cadr(sexp);
    var body = cddr(sexp);

    if (!isList(nameClause))
      name = nameClause;

    else {
      if (length(nameClause) != 2 || !isSymbol(car(nameClause)) || !isSymbol(cadr(nameClause)))
	throw new SyntaxError('define-macro: expects 2nd element is either an identifier or a list of two identifiers: ' + nameClause);

      name = car(nameClause);
      body = listStar(makeSymbol('lambda'), cdr(nameClause), body);
    }

    var macro = eval(emit(parseSexp(body, env)));
    macro.tag = 'macro';
    macro.env = env;

    env[name] = macro;
    return parseSexp(makeLiteral('#u'), env);
  }

  function parseIf(sexp, env) {
    if (length(sexp) != 4)
      throw new SyntaxError('if: wrong number of parts.');
    return cons('if', parseSequence(cdr(sexp)));
  }

  function parseJavascript(sexp, env) {
    var backquoteRE = /`([^`\\]|\\.)*`/mg;

    var text = sexp.toString().slice(1, -1);
    var interpolates = text.match(backquoteRE);
    var components = nil;
    for (var i = 0; i < interpolates.length; i++) {
      var target = interpolates[i];
      var index = text.indexOf(target);
      var js = text.substring(0, index);
      var moosky = target.slice(1, -1);
      components = cons(parseSexp(car(Moosky.read(moosky)), env), cons(js, components));
      text = text.substring(index + target.length);
    }

    return cons('javascript', reverse(cons(text, components)));
  }

  function parseLambda(sexp, env) {
    var formals = cadr(sexp);
    if (!isList(formals)) {
      if (!isSymbol(formals))
	throw SyntaxError('lambda: symbol expected for collective formal parameter: ' + formals);
    } else {
      while (formals != nil) {
	if (!isSymbol(car(formals)))
	  throw SyntaxError('lambda: symbol expected in formal parameter: ' + car(formals));
	formals = cdr(formals);
      }
      formals = cadr(sexp);
    }

    var body = parseSequence(cddr(sexp), Moosky.Top.$makeFrame(env));
    return list('lambda', formals, body);
  }

  function parseLet(sexp, env) {
    var bindings = parseBindings(cadr(sexp), env);
    var body = parseSequence(cddr(sexp), Moosky.Top.$makeFrame(env));

    return list('let', bindings, body);
  }

  function parseLetrec(sexp, env) {
    var bindings = cadr(sexp);
    var body = cddr(sexp);
    var let_ = makeSymbol('let');

    if (bindings == nil)
      return parseLet(cons(let_, cdr(sexp)), env);

    var dummyBindings = nil;
    var assignments = nil;
    var undefined = makeLiteral('#u');
    var set = makeSymbol('set!');
    while (bindings != nil) {
      var binding = car(bindings);
      dummyBindings = cons(list(car(binding), undefined), dummyBindings);
      assignments = cons(cons(set, binding), assignments);
      bindings = cdr(bindings);
    }

    return parseLet(listStar(let_, dummyBindings, append(reverse(assignments), body)), env);
  }

  function parseLetStar(sexp, env) {
    var bindings = cadr(sexp);
    var body = cddr(sexp);
    var let_ = makeSymbol('let');

    if (bindings == nil)
      return parseLet(cons(let_, cdr(sexp)), env);

    return parseLet(list(let_, list(car(bindings)),
			 listStar(car(sexp), cdr(bindings), body)), env);
  }

  function parseOr(sexp, env) {
    return cons('or', parseSequence(cdr(sexp), env));
  }

  function parseQuasiQuote(sexp, env) {
    if (length(sexp) != 2)
      throw new SyntaxError('quasiquote: wrong number of parts.');

    var bindings = nil;

    var quoted = cadr(sexp);
    if (!isPair(quoted))
      return list('quote', quoted);

    function parseQQ(sexp) {
      if (!isPair(sexp))
	return sexp;

      var A = car(sexp);

      if (isSymbol(A) && (A.toString() == 'unquote-splicing' || A.toString() == 'unquote')) {
	var symbol = Moosky.Top.gensym('qq');
	bindings = cons(cons(symbol, parseSexp(list(makeSymbol('lambda'), list(), cadr(sexp)), env)), bindings);

	return list(A, symbol);
      }

      return cons(parseQQ(A), parseQQ(cdr(sexp)));
    }

    return list('quasiquote', parseQQ(quoted), bindings);
  }

  function parseQuote(sexp, env) {
    if (length(sexp) != 2)
      throw new SyntaxError('quote: wrong number of parts.');

    return list('quote', cadr(sexp));
  }

  function parseSet(sexp, env) {
    if (length(sexp) != 3)
      throw new SyntaxError('set!: expected (set! <variable> <expression>), not ' + sexp);

    if (!isSymbol(cadr(sexp)))
      throw new SyntaxError('set!: expected (set! <variable> <expression>); ' + cadr(sexp) + ' is not a variable');

    return list('set!', cadr(sexp), parseSexp(caddr(sexp), env));
  }

  function quoteSexp(sexp) {
    if (isPair(sexp))
      return cons(quoteSexp(car(sexp)), quoteSexp(cdr(sexp)));

    if (sexp == nil || isSymbol(sexp))
      return sexp;

    if (sexp.tag == 'regexp')
      return new RegExp(sexp.toString());

    if (sexp.tag == 'number')
      return Number(sexp.toString());

    if (sexp.tag == 'string')
      return sexp.toString();

    if (sexp.tag == 'literal')
      return { '#f': false,
	       '#n': null,
	       '#t': true,
	       '#u': undefined }[sexp.toString()];

    debugger;
    throw new SyntaxError('Unknown sexp: ' + sexp);
  }

  var jsIdentifierRE = /^[$\w_][\w\d_]*$/;

  var jsKeywords = ["break", "case", "catch", "continue", "default", "delete",
		    "do", "else", "finally", "for", "function", "if", "in",
		    "instanceof", "new", "return", "switch", "this", "throw",
		    "try", "typeof", "var", "void", "while", "with"];

  var jsReservedWords = ["abstract", "boolean", "byte", "char", "class",
			 "const", "debugger", "double", "enum", "export",
			 "extends", "final", "float", "goto", "implements",
			 "import", "int", "interface", "long", "native",
			 "package", "private", "protected", "public", "short",
			 "static", "super", "synchronized", "throws",
			 "transient", "volatile"];

  var jsReservedRE = new RegExp('^' + jsKeywords.join('|') + '|'
				+ jsReservedWords.join('|') + '$');

  function requiresQuotes(variable) {
    return !variable.match(jsIdentifierRE) || variable.match(jsReservedRE);
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
	     'quasiquote': emitQuasiQuote,
	     'quote': emitQuote,
	     'set!': emitSet}[car(sexp).toString()])(sexp);
  }

  function emitBinding(envName, symbol, value) {
    if (requiresQuotes(symbol))
      return envName + '["' + symbol.toString() + '"] = ' + value + '';
    else
      return envName + '.' + symbol.toString() + ' = ' + value + '';
  }

  function emitSequence(sexp) {
    var values = [];
    while (sexp != nil) {
      values.push(emit(car(sexp)));
      sexp = cdr(sexp);
    }
    return '(' + values.join(', ') + ')';
  }

  function emitAnd(sexp) {
    sexp = cdr(sexp);

    var values = length(sexp);
    if (values == 0)
      return 'true';

    if (values == 1)
      return emit(car(sexp));

    // (this.$temp = (expr)) == false ? false : ... : this.$temp)
    var chunks = ['('];
    while (sexp != nil) {
      chunks.push('(this.$temp = (');
      chunks.push(emit(car(sexp)));
      chunks.push(')) == false ? false : ');
      sexp = cdr(sexp);
    }
    chunks.push('this.$temp)');
    return chunks.join('');
  }

  function emitApply(sexp) {
    var func = emit(cadr(sexp));
    var actuals = cddr(sexp);

    var isPrimitive = caadr(sexp) == 'deref' && func.match(/\./);

    var values = isPrimitive ? [] : ['this'];
    while (actuals != nil) {
      values.push(emit(car(actuals)));
      actuals = cdr(actuals);
    }

    if (isPrimitive)
      return func + '(' + values.join(', ') + ')';
    else
      return '(' + func + ').call(' + values.join(', ') + ')';
  }

  function emitBegin(sexp) {
    return emitSequence(cdr(sexp));
  }

  function emitDefine(sexp) {
    var name = cadr(sexp).toString();
    var body = emit(caddr(sexp));
    return 'this["' + name + '"] = (' + body + ')';
  }

  function emitIf(sexp) {
    var test = emit(car(sexp = cdr(sexp)));
    var consequent = emit(car(sexp = cdr(sexp)));
    var alternate = emit(car(sexp = cdr(sexp)));
    return '(' + test + ' != false ' + ' ? (' + consequent + ') : (' + alternate + '))';
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
    return '(function () { return ' + chunks.join('') + '}).call(this)';
  }

  function emitLambda(sexp) {
    var formals = cadr(sexp);
    var body = emitSequence(caddr(sexp));

    var bindings = [];
    if (isSymbol(formals))
      bindings.push(emitBinding('env', formals, 'this.$argumentsList(arguments, 0)'));

    else {
      var i = 0;
      while (formals != nil) {
	if (!isList(formals))
	  bindings.push(emitBinding('env', formals, 'this.$argumentsList(arguments, ' + i + ')'));

	else
	  bindings.push(emitBinding('env', car(formals), 'arguments[' + i + ']'));

	formals = cdr(formals);
	i++;
      }
    }

    return '(function () {\n'
      + 'var env = this.$makeFrame(this);\n'
      + bindings.join(';\n') + '\n'
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

  function emitOr(sexp) {
    sexp = cdr(sexp);
    var values = length(sexp);
    if (values == 0)
      return 'false';

    if (values == 1)
      return emit(car(sexp));

    // (this.$temp = (expr)) != false ? this.$temp : ... : false)
    var chunks = ['('];
    while (sexp != nil) {
      chunks.push('(this.$temp = (');
      chunks.push(emit(car(sexp)));
      chunks.push(')) != false ? this.$temp : ');
      sexp = cdr(sexp);
    }
    chunks.push('false)');
    return chunks.join('');
  }

  function emitQuasiQuote(sexp) {
    var quoteId = Moosky.Top.$quoted.length;
    Moosky.Top.$quoted.push(quoteSexp(cadr(sexp)));

    var expressions = [];
    var bindings = caddr(sexp);
    while (bindings != nil) {
      expressions.push(emitBinding('this', caar(bindings), emit(cdar(bindings))));
      bindings = cdr(bindings);
    }
    expressions.push('this.$quasiUnquote(this.$quoted[' + quoteId + '])');
    return '(' + expressions.join('), (') + ')';
  }

  function emitQuote(sexp) {
    var quoteId = Moosky.Top.$quoted.length;
    Moosky.Top.$quoted.push(quoteSexp(cadr(sexp)));
    return '(this.$quoted[' + quoteId + '])';
  }

  function emitSet(sexp) {
    var variable = cadr(sexp).toString();
    var value = emit(caddr(sexp));

    if (requiresQuotes(variable))
      return '(this["' + variable + '"] = ' + value + ')';
    else
      return '(this.' + variable + ' = ' + value + ')';
  }

  function emitSymbolDeref(sexp) {
    var symbol = car(cdr(sexp)).toString();
    if (symbol.match(/\./))
      return symbol;
    else {
      if (requiresQuotes(symbol))
	return 'this["' + symbol + '"]';
      else
	return 'this.' + symbol;
    }
  }

  return function compile(sexp, env) {
    var env = env || Moosky.Top.$makeFrame(Moosky.Top);
    var result = '(function () {\n'
		+ 'return ' + emit(parseBegin(cons('begin', sexp), env)) + ';\n'
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

    $quasiUnquote: function(sexp) {
      if (!isPair(sexp))
	return sexp;

      var A = car(sexp);
      if (isPair(A) && isSymbol(car(A)) && car(A).toString() == 'unquote-splicing') {
	var unquoted = this[cadr(A)].call(this);

	if (isList(unquoted))
	  return append(unquoted, this.$quasiUnquote(cdr(sexp)));

	return cons(unquoted, this.$quasiUnquote(cdr(sexp)));
      }

      if (isSymbol(A)) {
	var key = A.toString();
	if (key == 'unquote-splicing')
	  throw new SyntaxError('quasiquote: illegal splice' + sexp);

	if (key == 'unquote')
	  return this[cadr(sexp)].call(this);
      }

      return cons(this.$quasiUnquote(A), this.$quasiUnquote(cdr(sexp)));
    },

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
    },

    gensym: (function () {
	       var symbolCount = 0;
	       return function (key) {
		 return makeSymbol('$' + (key || '') + '_' + symbolCount++);
	       }
	     })()
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
			  regexp: /[\.\(\)\[\]'`]|,@?/ }, //'

			{ tag: 'symbol',
			  regexp: /[^#$\d\n\s\(\)\[\]'".`][^$\n\s\(\)"'`\[\]]*/ }
		      ];
