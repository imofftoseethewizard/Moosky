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

Moosky.Values = {};

Moosky.Values.Bare = (
    function () {
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
        };

        Character.prototype.emit = function() {
            return '"' + escapeString(this.$ch) + '"';
        };

        // --------------------------------------------------------------------------
        function MooskyString(str) {
            this.$str = str;
        }

        MooskyString.escapeString = escapeString;

        MooskyString.prototype = new Value();

        MooskyString.prototype.toString = function () {
            return '"' + this.$str + '"';
        };

        MooskyString.prototype.emit = function() {
            return '"' + escapeString(this.$str) + '"';
        };

        MooskyString.prototype.raw = function() {
            return this.$str;
        };

        // --------------------------------------------------------------------------
        function Symbol(sym) {
            this.$sym = sym;
        }

        Symbol.prototype = new Value();
        Symbol.prototype.constructor = Symbol;
        Symbol.prototype.toString = function () {
            return this.$sym;
        };

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

        var jsReservedRE = new RegExp('^(' + jsKeywords.join('|') + '|'
				      + jsReservedWords.join('|') + ')$');

        Symbol.prototype.requiresQuotes = function() {
            var value = this.toString();
            return !value.match(jsIdentifierRE) || value.match(jsReservedRE);
        };

        Symbol.translationResults = {};
        Symbol.translationOrigins = {};
        Symbol.collisionCount = 0;

        Symbol.setTranslations = function(dict) {
            for (s in dict) {
                Symbol.translationResults[s] = dict[s];
                Symbol.translationOrigins[dict[s]] = s;
            }
        };

        Symbol.nomunge = function(s) {
            var obj = {};
            obj[s] = s;
            Symbol.setTranslations(obj);
        }

        Symbol.camelize = function(str) {
            var parts = str.split('-'), len = parts.length;
            if (len == 1) return parts[0];

            var camelized = str.charAt(0) == '-'
                ? parts[0].charAt(0).toUpperCase() + parts[0].substring(1)
                : parts[0];

            for (var i = 1; i < len; i++)
                camelized += parts[i].charAt(0).toUpperCase() + parts[i].substring(1);

            return camelized;
        };

        Symbol.prototype.raw = function () {
            return this.$sym;
        };

        Symbol.prototype.munge = function (munged) {
            if (!this.$munged)
                this.$munged = munged || Symbol.munge(this.$sym);

            return this;
        };

        Symbol.prototype.emit = function() {
            //    if (this.$sym.match(/\./))
            //      return this.$sym;

            if (this.$munged)
                return this.$munged;

            return this.$sym;
            //    return Symbol.munge(this.$sym);
        };

        Symbol.munge = function(sym) {
            var cached = Symbol.translationResults[sym];
            if (cached)
                return cached;

            var value = sym;
            if (value.match(jsReservedRE))
                value = '_' + value;

            if (value.match(/\?$/))
                value = 'is-' + value.replace(/\?$/, '');

            value = value.replace(/->/g, '-to-')
                .replace(/\*$/, '-ext')
		.replace(/<=/, '-lte-')
                .replace(/</, '-lt-')
		.replace(/>=/, '-gte-')
                .replace(/>/, '-gt-')
		.replace(/=/, '-eq-');

            value = Symbol.camelize(value);
            value = value.replace(/[^_$a-zA-Z0-9]/g, '_');

            var originalForValue = Symbol.translationOrigins[value];
            if (originalForValue && originalForValue != sym)
                value += '$' + Symbol.collisionCount++;

            Symbol.translationResults[sym] = value;
            Symbol.translationOrigins[value] = sym;

            return value;
        };

        Symbol.prototype.toString = function() {
            if (this.$sym.length == 0)
                return '||';

            if (this.$sym.match(/[\]\n\r["'\(\),;@#`\\\{\}]/g)) //" ])))
                return '|' + this.$sym + '|';

            return this.$sym.replace(/\|/g, '\\|');
        };

        // --------------------------------------------------------------------------

        function Keyword($sym) {
            this.$sym = $sym;
        }

        Keyword.prototype = new Value();
        Keyword.prototype.emit = function() {
            return ['$keyword("', escapeString(this.$sym), '")'].join('');
        };

        Keyword.prototype.toString = Symbol.prototype.toString;

        // --------------------------------------------------------------------------
        function MooskyRegExp(regexp) {
            this.$regexp = regexp;
        }

        MooskyRegExp.prototype = new Value();
        MooskyRegExp.prototype.emit = function() {
            return this.$regexp.toString();
        };

        MooskyRegExp.prototype.toString = function () {
            return '#' + this.$regexp.toString();
        };

        // --------------------------------------------------------------------------
        function Javascript(js) {
            this.$js = js;
        }

        Javascript.prototype = new Value();

        Javascript.prototype.emit = function () {
            return '$js("' + escapeString(this.$js) + '")';
        };

        Javascript.prototype.toString = function () { return this.$js; };
        Javascript.prototype.raw = function () { return this.$js; };



        // --------------------------------------------------------------------------
        function Token(lexeme, tag, cite, norm) {
            this.$lexeme = lexeme;
            this.$tag = tag;
            this.$cite = cite;
            this.$norm = norm;
        }

        Token.prototype = new Value();

        // --------------------------------------------------------------------------
        function Cite(text, start, end, sexp) {
            this.$text = text;
            this.$start = start;
            this.$end = end;
            this.$sexp = sexp;
        }

        Cite.prototype = new Value();

        Cite.prototype.merge = function(cite) {
            if (cite instanceof Cite) {
                if (this.$text && this.$text != cite.$text) {
	            debugger;
	            throw new Error('cannot merge citations on different texts.');
                }
                this.$text = cite.$text;
                this.$start = Math.min(this.$start, cite.$start);
                this.$end = Math.max(this.$end, cite.$end);
            }
        };

        Cite.prototype.content = function (pre, post) {
            if (!this.$text)
                return "No content available.";

            return this.$text.substring(this.$start, this.$end);
        };

        Cite.prototype.context = function (pre, post) {
            if (!this.$text)
                return "No context available.";

            pre =  pre  != undefined ? pre  : 1;
            post = post != undefined ? post : 1;

            var start = this.findPriorLineStart(pre);
            var end = this.findPostLineEnd(post);

            return this.$text.substring(start, end);
        };

        Cite.prototype.findPriorLineStart = function(lines) {
            var index = this.$start;
            while (lines > 0) {
                index = this.$text.lastIndexOf('\n', index-1);
                if (index <= 0)
	            return 0;

                lines--;
            }
            return index+1;
        };

        Cite.prototype.findPostLineEnd = function(lines) {
            var index = this.$end;
            while (lines > 0) {
                index = this.$text.indexOf('\n', index+1);
                if (index == -1)
	            return this.$text.length;

                lines--;
            }
            return index;
        };

        // --------------------------------------------------------------------------
        function MooskyNumber(n) {
            this.$n = n;
        }

        MooskyNumber.prototype = new Number();
        MooskyNumber.prototype.valueOf = function() {
            return this.$n;
        };

        MooskyNumber.prototype.toString = function() {
            return this.valueOf().toString();
        };

        // --------------------------------------------------------------------------
        function Complex(z) {
            this.$z = z;
        }

        Complex.prototype = new MooskyNumber();
        Complex.prototype.valueOf = function() {
            return this.$z;
        };


        // --------------------------------------------------------------------------
        function Real(s) {
            this.$s = s;
        }

        Real.prototype = new Complex();
        Real.prototype.valueOf = function() {
            return this.$s;
        };

        // --------------------------------------------------------------------------
        function Rational(n, d) {
            this.$n = n;
            this.$d = d;
        }

        Rational.prototype = new Real();

        Rational.prototype.valueOf = function() {
            return this.$n/this.$d;
        };


        Rational.prototype.toString = function() {
            return '' + this.$n + '/' + this.$d;
        };

        Rational.prototype.emit = function() {
            return '$makeRational(' + this.$n + ', ' + this.$d + ')';
        };

        // --------------------------------------------------------------------------
        function Integer(i) {
            this.$i = i;
        }

        Integer.prototype = new Rational();

        Integer.prototype.valueOf = function() {
            return this.$i;
        };

        Integer.prototype.toString = function() {
            return '' + this.$i;
        };

        Integer.prototype.emit = Integer.prototype.toString;

        // --------------------------------------------------------------------------

        function Promise(p) {
            if (p.$has_promise)
                return p;

            p.$has_promise = true;
            p.$is_pending = true;

            p.$p = p;
            p.$v = undefined;

            p.force = function () {
                if (!this.$is_pending) return this.$v;
                var result = this();
                while (result && result.$has_promise)
	            result = result();
                this.$is_pending = false;
                return this.$v = result;
            };

            return p;
        }


        // --------------------------------------------------------------------------

        function Exception(message, inspector) {
            this.message = message;
            this.$i = inspector;
        }

        Exception.prototype = new Error();
        Exception.prototype.name = 'Exception';

        // --------------------------------------------------------------------------
        function Cons(a, d) {
            this.$a = a,
            this.$d = d;
        }

        Cons.prototype = new Value();

        Cons.nil = new Cons();

        Cons.isCons = function(a) {
            return a === Cons.nil || a instanceof Cons;
        };

        Cons.prototype.car = function() { return this.$a; };
        Cons.prototype.cdr = function() { return this.$d; };
        Cons.prototype.setCar = function(a) { this.$a = a; };
        Cons.prototype.setCdr = function(a) { this.$d = a; };

        Cons.prototype.length = function() {
            var length = 0;
            var lst = this;
            while (lst != Cons.nil) {
                length++;
                lst = lst.$d;
            }

            return length;
        };

        Cons.prototype.reverse = function() {
            var result = Cons.nil;

            var lst = this;
            while (lst != Cons.nil) {
                result = new Cons(lst.$a, result);
                lst = lst.$d;
            }

            return result;
        };

        Cons.append = function(___) {
            var argCount = arguments.length;

            if (argCount == 0)
                return Cons.nil;

            var resultHead = new Cons();
            var tail = resultHead;

            for (var i = 0; i < argCount-1; i++) {
                var lst = arguments[i];
                while (lst != Cons.nil) {
	            var next = new Cons();
	            tail.$d = next;
	            tail = next;
	            tail.$a = lst.$a;
	            lst = lst.$d;
                }
            }

            tail.$d = arguments[argCount-1];

            return resultHead.$d;
        };

        Cons.printSexp = function(sexp) {
            if (sexp == Cons.nil)
                return "()";

            if (!Cons.isCons(sexp)) {
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
	            return '"' + sexp.replace(/\"/g, '\\"') + '"';

                if (sexp && sexp.$has_promise)
	            return Cons.printSexp(sexp.force());

                return sexp.toString();
            }

            var result = [];
            while (sexp != Cons.nil) {
                var A = sexp.$a;
                var D = sexp.$d;

                if (!Cons.isCons(D)) {
	            result.push(Cons.printSexp(A));
	            result.push('.');
	            result.push(Cons.printSexp(D));
	            break;
                }

                if (result.length == 0 && A instanceof Symbol && A.$sym == 'quote' && D.$d == Cons.nil)
	            return "'" + Cons.printSexp(D.$a);

                result.push(Cons.printSexp(A));
                sexp = D;
            }

            return '(' + result.join(' ') + ')';
        };

        Cons.prototype.toString = function() { return Cons.printSexp(this); };

        return { Value: Value, Character: Character, String: MooskyString,
	         Symbol: Symbol, Keyword: Keyword, RegExp: MooskyRegExp,
	         Javascript:Javascript, Token: Token, Cite: Cite, Number: MooskyNumber,
	         Complex: Complex,  Real: Real, Rational: Rational, Integer: Integer,
	         Promise: Promise, Exception: Exception, Cons: Cons };
    }
)();
