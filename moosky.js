//=============================================================================
//
//
//=============================================================================


//=============================================================================
//
//

Moosky = (function ()
{
  return function (str, env) {
    return eval(Moosky.compile(Moosky.Core.read(str), env));
  };
})();

//=============================================================================
//
//

Moosky.Values = (function ()
{
  function escapeString(str) {
    return str.replace(/\n/g, '\\n').replace(/\"/g, '\\"').replace(/\r/g, '\\r');
  }

  // --------------------------------------------------------------------------
  function Value() {
  }

  Value.prototype = new Object();
  Value.prototype.constructor = Value;

  // --------------------------------------------------------------------------
  function Character(ch) {
    this.$ch = ch;
  }

  Character.prototype = new Value();

  Character.prototype.toString = function () {
    var name;

    name = { '\u0000': 'nul',     '\u0007': 'alarm',    '\u0008': 'backspace',
	     '\u0009': 'tab',     '\u000a': 'linefeed', '\u000a': 'newline',
	     '\u000b': 'vtab',    '\u000c': 'page',     '\u000d': 'return',
	     '\u001b': 'esc',     '\u0020': 'space',    '\u007f': 'delete' }[this.$ch]
      || { '\u0000': 'NUL', '\u0001': 'SOH', '\u0002': 'STX', '\u0003': 'ETX',
	   '\u0004': 'EOT', '\u0005': 'ENQ', '\u0006': 'ACK', '\u0007': 'BEL',
 	   '\u0008': 'BS',  '\u0009': 'HT',  '\u000a': 'LF',  '\u000b': 'VT',
 	   '\u000c': 'FF',  '\u000d': 'CR',  '\u000e': 'SO',  '\u000f': 'SI',
 	   '\u0010': 'DLE', '\u0011': 'DC1', '\u0012': 'DC2', '\u0013': 'DC3',
	   '\u0014': 'DC4', '\u0015': 'NAK', '\u0016': 'SYN', '\u0017': 'ETB',
 	   '\u0018': 'CAN', '\u0019': 'EM',  '\u001a': 'SUB', '\u001b': 'ESC',
 	   '\u001c': 'FS',  '\u001d': 'GS',  '\u001e': 'RS',  '\u001f': 'US',
 	   '\u007f': 'DEL'}[this.$ch];

    if (name === undefined) {
      var codePoint = this.$ch.charCodeAt(0);
      if (codePoint <= 126)
	name = this.$ch;
      else {
	name = codePoint.toString(16);
	while (name.length < 4)
	  name = '0' + name;

	name = 'u' + name;
      }
    }
    return '#\\' + name;
  }

  Character.prototype.emit = function() {
    return '"' + escapeString(this.$ch) + '"';
  }

  // --------------------------------------------------------------------------
  function String(str) {
    this.$str = eval(str.replace(/"^\s*\\\s*\n\s*/, '"') // '
		     .replace(/\s*\\\s*\n\s*"$/, '"') // '
		     .replace(/\n/, '\\n')
		     .replace(/\r/, '\\r'));
  }

  String.prototype = new Value();

  String.prototype.toString = function () {
    return '"' + this.$str + '"';
  }

  String.prototype.emit = function() {
    return '"' + escapeString(this.$str) + '"';
  }

  // --------------------------------------------------------------------------
  function Symbol(sym) {
    this.$sym = sym;
  }

  Symbol.prototype = new Value();
  Symbol.prototype.constructor = Symbol;
  Symbol.prototype.toString = function () {
    return this.$sym;
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

  Symbol.prototype.requiresQuotes = function() {
    var value = this.toString();
    return !value.match(jsIdentifierRE) || value.match(jsReservedRE);
  }

  Symbol.prototype.emit = function(envName) {
    var envName = envName || 'this';

    if (this.$sym.match(/\./))
      return this.$sym;

    else if (this.requiresQuotes())
      return envName + '["' + escapeString(this.toString()) + '"]';

    else
      return envName + '.' + this.toString();
  }

  Symbol.prototype.toString = function() {
    if (this.$sym.length == 0)
      return '||';

    if (this.$sym.match(/[\]["'\(\),@#`\\\{\}]/g)) //" ])
      return '|' + this.$sym + '|';

    return this.$sym.replace(/\|/g, '\\|');
  }

  // --------------------------------------------------------------------------
  function RegExp(regexp) {
    this.$regexp = regexp;
  }

  RegExp.prototype = new Value();
  RegExp.prototype.emit = function() {
    return this.$regexp.toString();
  }

  RegExp.prototype.toString = function () {
    return '#' + this.$regexp.toString();
  }

  // --------------------------------------------------------------------------
  function Javascript(js) {
    this.$js = js;
  }

  Javascript.prototype = new Value();

  // --------------------------------------------------------------------------
  function Token(lexeme, tag, cite, norm) {
    this.$lexeme = lexeme;
    this.$tag = tag;
    this.$cite = cite;
    this.$norm = norm;
  }

  Token.prototype = new Value();

  // --------------------------------------------------------------------------
  function Cite(source, start, end) {
    this.$source = source;
    this.$start = start;
    this.$end = end;
  }

  Cite.prototype = new Value();

  // --------------------------------------------------------------------------
  function Number(n) {
    this.$n = n;
  }

  Number.prototype = new Number();

  // --------------------------------------------------------------------------
  function Complex(z) {
    this.$z = z;
  }

  Complex.prototype = new Number();

  // --------------------------------------------------------------------------
  function Real(s) {
    this.$s = s;
  }

  Real.prototype = new Complex();

  // --------------------------------------------------------------------------
  function Rational(n, d) {
    this.$n = n;
    this.$d = d;
  }

  Rational.prototype = new Real();

  Rational.prototype.toString = function() {
    return '' + this.$n + '/' + this.$d;
  }

  Rational.prototype.emit = function() {
    return 'this.$makeRational(' + this.$n + ', ' + this.$d + ')';
  }

  // --------------------------------------------------------------------------
  function Integer(i) {
    this.$i = i;
  }

  Integer.prototype = new Rational();

  Integer.prototype.toString = function() {
    return '' + this.$i;
  }

  Integer.prototype.emit = Integer.prototype.toString;

  // --------------------------------------------------------------------------
  function Cons(a, d) {
    this.$a = a,
    this.$d = d;
  }

  Cons.prototype = new Value();

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

    return resultHead.$d;
  };

  Cons.printSexp = function(sexp) {
    if (sexp == Cons.nil)
      return "'()";

    if (!(sexp instanceof Cons)) {
      switch (sexp) {
	case false: return '#f';
	case null: return '#n';
	case true: return '#t';
	case undefined: return '#u';
      }

      if (sexp instanceof Array) {
	var chunks = [];
	for (var i = 0; i < sexp.length; i++)
	  chunks.push(Cons.printSexp(sexp[i]));

	return '#(' + chunks.join(' ') + ')';
      }

      if (typeof(sexp) == 'string')
	return '"' + sexp.replace(/"/g, '\\"') + '"'; //" )

      return sexp.toString();
    }

    var result = [];
    while (sexp != Cons.nil) {
      var A = sexp.$a;
      var D = sexp.$d

      if (!(D instanceof Cons)) {
	result.push(Cons.printSexp(A));
	result.push('.');
	result.push(Cons.printSexp(D));
	break;
      }

      if (result.length == 0 && A instanceof Symbol && A == 'quote' && D.$d == Cons.nil)
	return "'" + Cons.printSexp(D.$a);

      result.push(Cons.printSexp(A));
      sexp = D;
    }

    return '(' + result.join(' ') + ')';
  };

  Cons.prototype.toString = function() { return Cons.printSexp(this); };

  return { Value: Value, Character: Character, String: String,
	   Symbol: Symbol, RegExp: RegExp, Javascript:Javascript,
	   Token: Token, Cite: Cite, Number: Number, Complex: Complex,
	   Real: Real, Rational: Rational, Integer: Integer, Cons: Cons };
})();

//=============================================================================
//
//

Moosky.Core = {};

//=============================================================================
//
//

Moosky.Core.Primitives = (function ()
{
  var Cons = Moosky.Values.Cons;
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

  Primitives = {};
  Primitives.exports = {
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

  Primitives.mooskyExports = {
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

  return Primitives;
})();

//=============================================================================
//
//

Moosky.Core.read = (function ()
{ with (Moosky.Core.Primitives.exports)
{
  var Values = Moosky.Values;
  var Symbol = Values.Symbol;
  var Token = Values.Token;
  var Cite = Values.Cite;

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

  function tokenize(lexemeClasses, str) {
    lexemeClasses = map(function (lexemeClass) {
			  return { tag: lexemeClass.tag,
				   regexp: new RegExp(lexemeClass.regexp.source, 'g'),
				   normalize: lexemeClass.normalize,
				   condition: lexemeClass.condition,
				   nextMatch: { index: -1 } };
			}, lexemeClasses);

    var tokens = [];
    var i = 0, length = str.length;
    while (i < length) {
      var token =
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
	      var lexeme = lexemeClass.nextMatch[0];
	      var norm;

	      if (lexemeClass.normalize)
		norm = lexemeClass.normalize(lexemeClass.nextMatch);

	      if (!lexemeClass.condition || lexemeClass.condition(tokens, lexeme))
		return new Token(lexeme, lexemeClass.tag, new Cite(str, i, i+lexeme.length), norm);
	    }

	    return false;
	  }, lexemeClasses);

      if (!token) {
	var preview = str.slice(Math.max(0, i-30), i);
	var remainder = str.slice(i, Math.min(length, i+30));
	var caret_position = preview.slice(preview.lastIndexOf('\n')+1).length-1;
	var message = 'lexing failure at: \n'
			+ preview + remainder + '\n'
			+ map(constant(' '), range(caret_position)).join('') + '^';

	debugger;
	throw message;
      }

      if (token.$lexeme.length == 0) {
	throw 'zero length lexeme: ' + token.$tag;
	break;
      }

      tokens.push(token);
      i += token.$lexeme.length;
    }

    return tokens;
  }

  function makeVector(lst) {
    var v = [];
    while (lst != nil) {
      v.push(car(lst));
      lst = cdr(lst);
    }

    return v;
  }

  function parseTokens(tokens, i) {
    var sexp = nil;
    var dotted = false;
    var last;

    var delimiter = false;

    if (i >= 0)
      delimiter = {'[': ']', '(': ')', '#(': ')'}[tokens[i].$lexeme];

    for (var j = i+1; j < tokens.length; j++) {
      var token = tokens[j];
      var next;
      if (token.$lexeme.match(/^[\[\(]|#\(/)) {
	var result = parseTokens(tokens, j);
	if (token.$lexeme == '#(')
	  next = makeVector(result.sexp);
	else
	  next = result.sexp;

	j = result.index;

      } else if (token.$lexeme == delimiter)
	break;

      else if (token.$lexeme.match(/^[\]\)]/))
	throw 'Mismatched ' + tokens[i].$lexeme + ': found ' + tokens[j].$lexeme;

      else if (token.$lexeme == '.') {
	if (dotted)
	  throw new SyntaxError('improper dotted list');
	dotted = true;
	continue;

      } else
	next = parseToken(tokens[j]);

      if (dotted) {
	if (last !== undefined)
	  throw new SyntaxError('improper dotted list');

	last = next;
	continue;
      }

      if (sexp == nil || car(sexp) == nil)
	sexp = cons(next, sexp);

      else {
	var translated = { "'": 'quote',
			   '`': 'quasiquote',
			   ',': 'unquote',
			   ',@': 'unquote-splicing' }[car(sexp)];

	if (translated === undefined)
	  sexp = cons(next, sexp);
	else
	  sexp = cons(cons(parseToken(new Token(translated, 'symbol', token.$cite, token.$norm)),
			   cons(next, nil)),
		      cdr(sexp));
      }
    }

    if (delimiter && token.$lexeme != delimiter) {
      throw 'Mismatched ' + tokens[i] + ' at end of input.';
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

  function parseToken(token) {
    return { 'character':   function(token) { return new Values.Character(token.$norm); },
	     'javascript':  parseJavascript,
	     'literal':     parseLiteral,
	     'number':      parseNumber,
	     'punctuation': function(token) { return new Symbol(token.$lexeme); },
	     'regexp':      function(token) { return new Values.RegExp(new RegExp(token.$norm)); },
	     'string':      function(token) { return new Values.String(token.$lexeme); },
	     'symbol':      function(token) { return new Symbol(token.$lexeme); } }[token.$tag](token);
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
      components = cons(parseSexp(car(Moosky.Core.read(moosky)), env), cons(js, components));
      text = text.substring(index + target.length);
    }

    return cons($javascript, reverse(cons(text, components)));
  }

  function parseLiteral(token) {
    return { '#f': false,
	     '#n': null,
	     '#t': true,
	     '#u': undefined }[token.$lexeme];
  }

  function parseNumber(token) {
    var lexeme = token.$lexeme;
    if (lexeme.match(/^-?([\d]+|0[xX][\da-fA-F]+)$/))
      return new Values.Integer(parseInt(lexeme));

    if (lexeme.match(/^-?[\d]+\/[\d]+$/)) {
      var nd = lexeme.split('/');
      return new Values.Rational(nd[0], nd[1]);
    }

    return new Values.Real(parseFloat(lexeme));
  }

  function read(str) {
    var tokens = tokenize(Moosky.LexemeClasses, str);

    tokens = filter(function (token) {
		      return token.$tag != 'comment' &&
			token.$tag != 'space';
		    }, tokens);

    var result = parseTokens(tokens, -1);

    return result.sexp;
  }

  return read;
}})();

//=============================================================================
//
//

Moosky.compile = (function ()
{ with (Moosky.Core.Primitives.exports)
{
  var Values = Moosky.Values;
  var Value = Values.Value;
  var Symbol = Values.Symbol;

  var $and         = new Symbol('and');
  var $apply       = new Symbol('apply');
  var $begin       = new Symbol('begin');
  var $case        = new Symbol('case');
  var $cond        = new Symbol('cond');
  var $define      = new Symbol('define');
  var $defineMacro = new Symbol('define-macro');
  var $eqv         = new Symbol('eqv?');
  var $if          = new Symbol('if');
  var $javascript  = new Symbol('javascript');
  var $lambda      = new Symbol('lambda');
  var $let         = new Symbol('let');
  var $letStar     = new Symbol('let*');
  var $letrec      = new Symbol('letrec');
  var $letrecStar  = new Symbol('letrec*');
  var $or          = new Symbol('or');
  var $quote       = new Symbol('quote');
  var $quasiquote  = new Symbol('quasiquote');
  var $set         = new Symbol('set!');

  function isMacro(v) {
    return v !== undefined && typeof v == 'function' && v.tag == 'macro';
  }

  function isSymbol(sexp) {
    return sexp instanceof Symbol;
  }

  function parseSexp(sexp, env) {
    console.log(sexp);
    if (env === undefined) {
      debugger;
    }

    if (!isList(sexp))
      return sexp;

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

      var parser = parsers[key];
      if (parser)
	return parser(sexp, env);

      var applicand = env[key];
      if (isMacro(applicand))
	return parseSexp(applicand.call(applicand.env, sexp), env);
    }

    return parseApplication(sexp, env);
  }

  function parseApplication(sexp, env) {
    var args = nil;
    while (sexp != nil) {
      args = cons(parseSexp(car(sexp), env), args);
      sexp = cdr(sexp);
    }
    return cons($apply, reverse(args));
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
    return cons($and, parseSequence(cdr(sexp), env));
  }

  function parseBegin(sexp, env) {
    return cons($begin, parseSequence(cdr(sexp), env));
  }

  function parseCase(sexp, env) {
    var key = cadr(sexp);
    var caseClauses = nil;
    var $temp = Moosky.Top.gensym('case');

    sexp = cddr(sexp);
    while (sexp != nil) {
      try {
	var clause = car(sexp);
	var data = car(clause);
	var expressions = cdr(clause);

	var elseClause = isSymbol(data) && data == 'else';

	if (cdr(sexp) != nil && elseClause || !elseClause && !isList(data)
	    || expressions == nil)
	  throw new SyntaxError();

	var test;
	if (elseClause)
	  test = true;

	else {
	  test = nil;
	  while (data != nil) {
	    var datum = car(data);
	    if (isSymbol(datum))
	      datum = list($quote, datum);

	    test = cons(list($eqv, $temp, datum), test);
	    data = cdr(data);
	  }

	  test = cons($or, test);
	}

	if (cdr(expressions) == nil)
	  expressions = car(expressions);
	else
	  expressions = cons($begin, expressions);

	caseClauses = cons(cons(test, expressions), caseClauses);

      } catch(e) {
	throw new SyntaxError('bad case clause: ' + clause);
      }
      sexp = cdr(sexp);
    }

    var result = undefined;
    while (caseClauses != nil) {
      var clause = car(caseClauses);
      result = listStar($if, car(clause), cdr(clause), list(result));
      caseClauses = cdr(caseClauses);
    }

    result = list($let, list(list($temp, key)), result)
    return parseSexp(result, env);
  }

  function parseCond(sexp, env) {
    var condClauses = nil;
    sexp = cdr(sexp);
    while (sexp != nil) {
      var clause = car(sexp);
      try {
	var test = car(clause);
	var elseClause = isSymbol(test) && test == 'else';
	var expressions = cdr(clause);

	var $temp = Moosky.Top.gensym('cond');

	function makeAnaphoricTest(test) {
	  // ironically, this is implemented as an epistrophe
	  return list($begin, list($set, $temp, test), $temp);
	}

	if (expressions == nil) {
	  test = makeAnaphoricTest(test);
	  expressions = list($temp);

	} else {
	  var expr_1 = car(expressions);
	  var anaphoric = isSymbol(expr_1) && expr_1 == '=>';

	  if (anaphoric) {
	    test = makeAnaphoricTest(test);

	    expressions = cdr(expressions);
	    if (cdr(expressions) != nil)
	      throw new SyntaxError();

	    expressions = list(list(car(expressions), $temp));
	  }

	  if (expressions == nil)
	    throw new SyntaxError();
	}

	if (cdr(expressions) == nil)
	  expressions = car(expressions);
	else
	  expressions = cons($begin, expressions);

	test = parseSexp(test, env);
	expressions = parseSexp(expressions, env);

	condClauses = cons(cons(test, expressions), condClauses);

      } catch (e) {
	throw new SyntaxError('bad cond clause: ' + clause);
      }

      sexp = cdr(sexp);
    }

    var result = undefined;
    while (condClauses != nil) {
      var clause = car(condClauses);
      result = listStar($if, car(clause), cdr(clause), list(result));
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
      body = list($lambda, formals, parseSequence(cddr(sexp), env));
    }

    return list(car(sexp), name, body);
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
      body = listStar($lambda, cdr(nameClause), body);
    }

    env[name] = eval(emit(parseSexp(body, env)));
    env[name].env = env;
    env[name].tag = 'macro';
    return undefined;
  }

  function parseIf(sexp, env) {
    if (length(sexp) != 4)
      throw new SyntaxError('if: wrong number of parts.');
    return cons(car(sexp), parseSequence(cdr(sexp), env));
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
    return list($lambda, formals, body);
  }

  function parseLet(sexp, env) {
    var bindings = parseBindings(cadr(sexp), env);
    var body = parseSequence(cddr(sexp), Moosky.Top.$makeFrame(env));

    return list($let, bindings, body);
  }

  function parseLetrec(sexp, env) {
    var bindings = cadr(sexp);
    var body = cddr(sexp);

    if (bindings == nil)
      return parseLet(cons($let, cdr(sexp)), env);

    var dummyBindings = nil;
    var assignments = nil;
    while (bindings != nil) {
      var binding = car(bindings);
      dummyBindings = cons(list(car(binding), undefined), dummyBindings);
      assignments = cons(cons($set, binding), assignments);
      bindings = cdr(bindings);
    }

    return parseLet(listStar($let, dummyBindings, append(reverse(assignments), body)), env);
  }

  function parseLetStar(sexp, env) {
    var bindings = cadr(sexp);
    var body = cddr(sexp);

    if (bindings == nil)
      return parseLet(cons($let, cdr(sexp)), env);

    return parseLet(list($let, list(car(bindings)),
			 listStar(car(sexp), cdr(bindings), body)), env);
  }

  function parseOr(sexp, env) {
    return cons(car(sexp), parseSequence(cdr(sexp), env));
  }

  function parseQuasiQuote(sexp, env) {
    if (length(sexp) != 2)
      throw new SyntaxError('quasiquote: wrong number of parts.');

    var bindings = nil;

    var quoted = cadr(sexp);
    if (!isPair(quoted))
      return list($quote, quoted);

    function parseQQ(sexp) {
      if (!isPair(sexp))
	return sexp;

      var A = car(sexp);

      if (isSymbol(A) && A == 'unquote-splicing' || A == 'unquote') {
	var symbol = Moosky.Top.gensym('qq');
	bindings = cons(cons(symbol, parseSexp(list($lambda, list(), cadr(sexp)), env)), bindings);

	return list(A, symbol);
      }

      return cons(parseQQ(A), parseQQ(cdr(sexp)));
    }

    return list(car(sexp), parseQQ(quoted), bindings);
  }

  function parseQuote(sexp, env) {
    if (length(sexp) != 2)
      throw new SyntaxError('quote: wrong number of parts.');

    return sexp;
  }

  function parseSet(sexp, env) {
    if (length(sexp) != 3)
      throw new SyntaxError('set!: expected (set! <variable> <expression>), not ' + sexp);

    if (!isSymbol(cadr(sexp)))
      throw new SyntaxError('set!: expected (set! <variable> <expression>); ' + cadr(sexp) + ' is not a variable');

    return list(car(sexp), cadr(sexp), parseSexp(caddr(sexp), env));
  }

  function emit(sexp) {
    console.log('emit: ' + sexp);
    if (!isList(sexp)) {
      return (sexp instanceof Value) ? sexp.emit() : '' + emitPrimitive(sexp);
    }

    var op = car(sexp);

    return ({'and': emitAnd,
	     'apply': emitApply,
	     'define': emitDefine,
	     'begin': emitBegin,
	     'if': emitIf,
	     'javascript': emitJavascript,
	     'lambda': emitLambda,
	     'let': emitLet,
	     'or': emitOr,
	     'quasiquote': emitQuasiQuote,
	     'quote': emitQuote,
	     'set!': emitSet}[car(sexp).toString()])(sexp);
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
    var applicand = cadr(sexp);
    var actuals = cddr(sexp);

    // FIX  this will work where native code is directly referred to with
    // eg, window.alert, but not in the case where an application returns
    // it as a value.
    var isPrimitive = isSymbol(applicand) && applicand.toString().match(/\./);

    var values = isPrimitive ? [] : ['this'];
    while (actuals != nil) {
      values.push(emit(car(actuals)));
      actuals = cdr(actuals);
    }

    if (isPrimitive)
      return emit(applicand) + '(' + values.join(', ') + ')';
    else
      return '(' + emit(applicand) + ').call(' + values.join(', ') + ')';
  }

  function emitBegin(sexp) {
    return emitSequence(cdr(sexp));
  }

  function emitBinding(envName, symbol, value) {
    return symbol.emit(envName) + ' = ' + value;
  }

  function emitDefine(sexp) {
    var name = cadr(sexp);
    var body = emit(caddr(sexp));
    return name.emit('this') + ' = (' + body + ')';
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
    var lambda = list($lambda, reverse(formals), body);
    return emitApply(cons($apply, cons(lambda, reverse(params))));
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

  function emitPrimitive(sexp) {
    if (sexp instanceof Array)
      return emitQuote(list($quote, sexp));

    return sexp.toString();
  }

  function emitQuasiQuote(sexp) {
    var quoteId = Moosky.Top.$quoted.length;
    Moosky.Top.$quoted.push(cadr(sexp));

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
    Moosky.Top.$quoted.push(cadr(sexp));
    return '(this.$quoted[' + quoteId + '])';
  }

  function emitSequence(sexp) {
    var values = [];
    while (sexp != nil) {
      values.push(emit(car(sexp)));
      sexp = cdr(sexp);
    }
    return values.join(', ');
  }

  function emitSet(sexp) {
    return '(' + cadr(sexp).emit('this') + ' = ' + emit(caddr(sexp)) + ')';
  }

  return function compile(sexp, env) {
    var env = env || Moosky.Top.$makeFrame(Moosky.Top);
    var result = '(function () {\n'
		+ 'return ' + emit(parseBegin(cons('begin', sexp), env)) + ';\n'
		+ '}).call(Moosky.Top);';
    console.log(result);
    return result;
  }
}})();

//=============================================================================
//
//

Moosky.Top = (function ()
{ with (Moosky.Core.Primitives.exports)
{
  var Values = Moosky.Values;

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

  function isSymbol(sexp) {
    return sexp instanceof Values.Symbol;
  }

  function isList(sexp) {
    return sexp instanceof Values.Cons;
  }

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

  function assertIsSymbol(name, sym) {
    if (!isSymbol(sym))
      throw new SyntaxError(name + ': symbol expected: ' + sym);
  }

  function assertIsProcedure(name, fn) {
    if (!(typeof(fn) == 'function'))
      throw new SyntaxError(name + ': procedure expected: ' + fn);
  }

  function assertIsCharacter(name, ch) {
    if (!(typeof(ch) == 'string' || ch instanceof String) || ch.length != 1)
      throw new SyntaxError(name + ': character expected: ' + ch);
  }

  function characterComparator(name, kernel, prep) {
    return function(___) {
      prep = prep || function (x) { return x; };
      assertMinArgs(name, 2, arguments);
      assertIsCharacter(name, arguments[0]);
      var A = prep(arguments[0]).charCodeAt(0);
      for (var i = 1; i < arguments.length; i++) {
	assertIsCharacter(name, arguments[i]);
	var B = prep(arguments[i]).charCodeAt(0);
	if (!kernel(A, B))
	  return false;
      }
      return true;
    }
  }

  function characterComparatorCI(name, kernel) {
    return characterComparator(name, kernel, function(a) { return a.toLowerCase(); });
  }

  function characterPredicate(name, kernel) {
    return function(a) {
      assertArgCount(name, 1, arguments);
      assertIsCharacter(name, a);
      return kernel(a);
    }
  }

  var characterOperator = characterPredicate;


  function assertIsString(name, s) {
    if (!(typeof(s) == 'string' || s instanceof String))
      throw new SyntaxError(name + ': string expected: ' + s);
  }

  function stringComparator(name, kernel, prep) {
    return function(___) {
      prep = prep || function (x) { return x; };
      assertMinArgs(name, 2, arguments);
      assertIsString(name, arguments[0]);
      var A = prep(arguments[0]);
      for (var i = 1; i < arguments.length; i++) {
	assertIsString(name, arguments[i]);
	var B = prep(arguments[i]);
	if (!kernel(A, B))
	  return false;
      }
      return true;
    }
  }

  function stringComparatorCI(name, kernel) {
    return stringComparator(name, kernel, function(a) { return a.toLowerCase(); });
  }

  function stringPredicate(name, kernel) {
    return function(a) {
      assertArgCount(name, 1, arguments);
      assertIsString(name, a);
      return kernel(a);
    }
  }

  var stringOperator = stringPredicate;


  function assertIsInteger(name, i) {
    if (!(typeof(i) == 'number' || i instanceof Number) || Math.round(i) != i)
      throw new SyntaxError(name + ': integer expected: ' + i);
  }

  function assertIsNonNegativeInteger(name, i) {
    assertIsInteger(name, i);
    if (i < 0)
      throw new SyntaxError(name + ': non-negative integer expected: ' + i);
  }

  function integerPredicate(name, kernel) {
    return function (i) {
      assertArgCount(name, 1, arguments);
      assertIsInteger(name, i);
      return kernel(i);
    }
  }

  var integerOperator = integerPredicate;


  function assertIsVector(name, v) {
    if (!(v instanceof Array))
      throw new SyntaxError(name + ': vector expected: ' + v);
  }

  function assertVectorIndexInRange(name, v, k) {
    if (k >= v.length)
      throw new SyntaxError(name + ': index ' + k + ' out of range[0, '
			      + v.length-1 + '] for vector ' + v);
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
      if (isPair(A) && isSymbol(car(A)) && car(A) == 'unquote-splicing') {
	var unquoted = this[cadr(A)].call(this);

	if (isList(unquoted))
	  return append(unquoted, this.$quasiUnquote(cdr(sexp)));

	return cons(unquoted, this.$quasiUnquote(cdr(sexp)));
      }

      if (isSymbol(A)) {
	if (A == 'unquote-splicing')
	  throw new SyntaxError('quasiquote: illegal splice' + sexp);

	if (A == 'unquote')
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

    'char?': function(a) {
      return (typeof(a) == 'string' || a instanceof String) && a.length == 1;
    },

    'char=?':  characterComparator('char=?',  function(a, b) { return a == b; }),
    'char<?':  characterComparator('char<?',  function(a, b) { return a < b; }),
    'char>?':  characterComparator('char>?',  function(a, b) { return a > b; }),
    'char<=?': characterComparator('char<=?', function(a, b) { return a <= b; }),
    'char>=?': characterComparator('char>=?', function(a, b) { return a >= b ; }),

    'char-ci=?':  characterComparatorCI('char-ci=?',  function(a, b) { return a == b; }),
    'char-ci<?':  characterComparatorCI('char-ci<?',  function(a, b) { return a < b; }),
    'char-ci>?':  characterComparatorCI('char-ci>?',  function(a, b) { return a > b; }),
    'char-ci<=?': characterComparatorCI('char-ci<=?', function(a, b) { return a <= b; }),
    'char-ci>=?': characterComparatorCI('char-ci>=?', function(a, b) { return a >= b ; }),

    'char-alphabetic?': characterPredicate('char-alphabetic?', function(a) { return a.match(/\w/) != null; }),
    'char-numeric?':    characterPredicate('char-numeric?',    function(a) { return a.match(/\d/) != null; }),
    'char-whitespace?': characterPredicate('char-whitespace?', function(a) { return a.match(/\s/) != null; }),
    'char-upper-case?': characterPredicate('char-upper-case?', function(a) { return a == a.toUpperCase(); }),
    'char-lower-case?': characterPredicate('char-lower-case?', function(a) { return a == a.toLowerCase(); }),

    'char->integer': characterOperator('char->integer', function(a) { return a.charCodeAt(0); }),
    'char-upcase':   characterOperator('char-upcase',   function(a) { return a.toUpperCase(); }),
    'char-downcase': characterOperator('char-downcase', function(a) { return a.toLowerCase(); }),

    'integer->char': integerOperator('integer->char', function(i) { return String.fromCharCode(i); }),

    'string?': function(a) {
      return typeof(a) == 'string' || a instanceof String;
    },

    'make-string': function(k, ch) {
      assertArgRange('make-string', 1, 2, arguments);
      assertIsNonNegativeInteger('make-string', k);

      ch = ch !== undefined ? ch : ' ';
      assertIsCharacter('make-string', ch);

      var s = '';
      while (k > 0)
	s += ch;

      return s;
    },

    'string': function(___) {
      for (var i = 0; i < arguments.length; i++)
	assertIsCharacter('string', arguments[i]);

      return Array.apply(Array, arguments).join('');
    },

    'string-length': stringOperator('string-length', function(s) { return s.length; }),

    'string-ref': function(s, k) {
      assertArgCount('string-ref', 2, arguments);
      assertIsString('string-ref', s);
      assertIsNonNegativeInteger('string-ref', k);
      return s[k];
    },

    'string=?':  stringComparator('string=?',  function(a, b) { return a == b; }),
    'string<?':  stringComparator('string<?',  function(a, b) { return a < b; }),
    'string>?':  stringComparator('string>?',  function(a, b) { return a > b; }),
    'string<=?': stringComparator('string<=?', function(a, b) { return a <= b; }),
    'string>=?': stringComparator('string>=?', function(a, b) { return a >= b ; }),

    'string-ci=?':  stringComparatorCI('string-ci=?',  function(a, b) { return a == b; }),
    'string-ci<?':  stringComparatorCI('string-ci<?',  function(a, b) { return a < b; }),
    'string-ci>?':  stringComparatorCI('string-ci>?',  function(a, b) { return a > b; }),
    'string-ci<=?': stringComparatorCI('string-ci<=?', function(a, b) { return a <= b; }),
    'string-ci>=?': stringComparatorCI('string-ci>=?', function(a, b) { return a >= b ; }),

    'substring': function(s, start, end) {
      assertArgCount('substring', 2, arguments);
      assertIsNonNegativeInteger('substring', start);
      assertIsNonNegativeInteger('substring', end);
      if (end < start)
	throw new SyntaxError('substring: end < start.');

      return s.slice(start, end);
    },

    'string-append': function(___) {
      for (var i = 0; i < arguments.length; i++)
	assertIsString('string-append', arguments[i]);

      return Array.apply(Array, arguments).join('');
    },

    'string->list': function(s) {
      assertArgCount('string->list', 1, arguments);
      assertIsString('string->list', s);

      var lst = nil;
      for (var i = s.length-1; i >= 0; i--)
	lst = cons(s.charAt(i), lst);

      return lst;
    },

    'list->string': function(lst) {
      assertArgCount('list->string', 1, arguments);
      assertIsList('list->string', lst);

      var chs = [];
      while (lst != nil) {
	var ch = car(lst);
	assertIsCharacter('list->string', ch);
	chs.push(ch);
	lst = cdr(lst);
      }

      return chs.join('');
    },

    'string-copy': function(s) {
      assertArgCount('string-copy', 1, arguments);
      assertIsString('string-copy', s);
      return String(s);
    },

    'string-for-each': function(proc, s0, ___) {
      assertMinArgs('string-for-each', 2, arguments);
      assertIsProcedure('string-for-each', proc);
      assertIsString('string-for-each', s0);

      var strs = [s0];
      var length = s0.length;
      for (var i = 2; i < arguments.length; i++) {
	var s = arguments[i];
	assertIsString('string-for-each', s);
	if (s.length != length)
	  throw new SyntaxError('string-for-each: all strings must be the same length: '
				+ '(string-length "' + s0 + '") != (string-length "' + s + '")');

	strs.push(s);
      }

      for (i = 0; i < length; i++) {
	var chs = [];
	for (var j = 0; j < strs.length; j++)
	  chs.push(strs[j].charAt(i));

	proc.apply(this, chs);
      }
    },

    'vector?': function(v) {
      assertArgCount('vector?', 1, arguments);
      return v instanceof Array;
    },

    'make-vector': function(k, obj) {
      assertArgRange('make-vector', 1, 2, arguments);
      assertIsNonNegativeInteger('make-vector', k);

      var v = [];
      while (k-- > 0)
	v.push(obj);

      return v;
    },

    'vector': function(___) {
      var v = [];
      for (var i = 0; i < arguments.length; i++)
	v.push(arguments[i]);

      return v;
    },

    'vector-length': function(v) {
      assertArgCount('vector-length', 1, arguments);
      assertIsVector('vector-length', v);
      return v.length;
    },

    'vector-ref': function(v, k) {
      assertArgCount('vector-ref', 2, arguments);
      assertIsVector('vector-ref', v);
      assertIsNonNegativeInteger('vector-ref', k);
      assertVectorIndexInRange(v, k);
      return v[k];
    },

    'vector-set!': function(v, k, obj) {
      assertArgCount('vector-set!', 3, arguments);
      assertIsVector('vector-set!', v);
      assertIsNonNegativeInteger('vector-set!', k);
      assertVectorIndexInRange(v, k);
      v[k] = obj;
    },

    'vector->list': function(v) {
      assertArgCount('vector->list', 1, arguments);
      assertIsVector('vector->list', v);

      var lst = nil;
      for (var i = v.length-1; i >= 0; i--)
	lst = cons(v[i], lst);

      return lst;
    },

    'list->vector': function(lst) {
      assertArgCount('list->vector', 1, arguments);
      assertIsList('list->vector', lst);

      // use makeVector?
      var v = [];
      while (lst != nil) {
	v.push(car(lst));
	lst = cdr(lst);
      }

      return v;
    },

    'symbol?': function(s) {
      assertArgCount('symbol?', 1, arguments);
      return s instanceof Values.Symbol;
    },

    'symbol->string': function(sym) {
      assertIsSymbol('symbol->string', sym);
      assertArgCount('symbol->string', 1, arguments);
      return sym.$sym;
    },

    'string->symbol': function(s) {
      assertIsString('string->symbol', s);
      assertArgCount('string->symbol', 1, arguments);
      return new Values.Symbol(s);
    },

    gensym: (function () {
	       var symbolCount = 0;
	       return function (key) {
		 return new Values.Symbol('$' + (key || '') + '_' + symbolCount++);
	       }
	     })()
  };

  for (p in Moosky.Core.Primitives.mooskyExports) {
    Top[p] = Moosky.Core.Primitives.mooskyExports[p];
  }

  return Top;
}})();

//=============================================================================
//
//

Moosky.LexemeClasses = [ { tag: 'comment',
			 regexp: /;.*/ },

			{ tag: 'space',
			  regexp: /(\s|\n)+/ },

			{ tag: 'literal',
			  regexp: /#f|#n|#t|#u/ },

			{ tag: 'number',
			  regexp: /-?0?\.\d+|-?[1-9]\d*(\.\d*)?([eE][+-]?\d+)?|-?0([xX][0-9a-fA-F]+)?/ },

			// standard codes for control characters
			{ tag: 'character',
			  regexp: /#\\(NUL|SOH|STX|ETX|EOT|ENQ|ACK|BEL|BS|HT|LF|VT|FF|CR|SO|SI|DLE|DC1|DC2|DC3|DC4|NAK|SYN|ETB|CAN|EM|SUB|ESC|FS|GS|RS|US|DEL)/,
			  normalize: function(match) {
			    return { 'NUL': '\u0000', 'SOH': '\u0001', 'STX': '\u0002', 'ETX': '\u0003',
				     'EOT': '\u0004', 'ENQ': '\u0005', 'ACK': '\u0006', 'BEL': '\u0007',
 				     'BS':  '\u0008', 'HT':  '\u0009', 'LF':  '\u000a', 'VT':  '\u000b',
 				     'FF':  '\u000c', 'CR':  '\u000d', 'SO':  '\u000e', 'SI':  '\u000f',
 				     'DLE': '\u0010', 'DC1': '\u0011', 'DC2': '\u0012', 'DC3': '\u0013',
				     'DC4': '\u0014', 'NAK': '\u0015', 'SYN': '\u0016', 'ETB': '\u0017',
 				     'CAN': '\u0018', 'EM':  '\u0019', 'SUB': '\u001a', 'ESC': '\u001b',
 				     'FS':  '\u001c', 'GS':  '\u001d', 'RS':  '\u001e', 'US':  '\u001f',
 				     'DEL': '\u007f'}[match[1]];
			  }
			},

			// standard scheme names for control characters
			{ tag: 'character',
			  regexp: /#\\(nul|alarm|backspace|tab|linefeed|newline|vtab|page|return|esc|space|delete|altmode|backnext|call|rubout)/,
			  normalize: function(match) {
			    return { 'nul':     '\u0000', 'alarm':    '\u0007', 'backspace': '\u0008',
				     'tab':     '\u0009', 'linefeed': '\u000a', 'newline':   '\u000a',
				     'vtab':    '\u000b', 'page':     '\u000c', 'return':    '\u000d',
				     'esc':     '\u001b', 'space':    '\u0020', 'delete':    '\u007f',
				     'altmode': '\u001b', 'backnext': '\u001f', 'call':      '\u001a',
				     'rubout':  '\u007f'}[match[1]];
			  }
			},

			// standard general form
			{ tag: 'character',
			  regexp: /#\\([xu]([\da-fA-F]+)|.)/,
			  normalize: function(match) {
			    if (match[1].length == 1)
			      return match[1];
			    else
			      return String.fromCharCode(parseInt(match[2], 16));
			  }
			},

			{ tag: 'string',
			  regexp: /"([^"\\]|\\(.|\n))*"/m }, //"

			{ tag: 'regexp',
			  regexp: /#\/([^\/\\]|\\.)*\// },

			{ tag: 'javascript',
			  regexp: /\{[^}]*\}/ },

			{ tag: 'javascript',
			  regexp: /#\{([^\}]|\}[^#])*\}#/m },

			{ tag: 'punctuation',
			  regexp: /[\.\(\)\[\]'`]|,@?|#\(/ }, //'

			{ tag: 'symbol',
			  regexp: /[^#$\d\n\s\(\)\[\]'".`][^$\n\s\(\)"'`\[\]]*/ }
		      ];
