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

(
    function () {
        const Values = Moosky.Values;
        const Symbol = Values.Symbol;
        const Keyword = Values.Keyword;

        //  with (Moosky.Runtime.exports) {
        {
            eval(Moosky.Runtime.importExpression);

            Moosky.Runtime.Bare.Top = {
                '$namespace': 'Moosky.Top',
                '$nil': nil,
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
                syntax: syntax,
                'syntax*': syntaxStar,
                'append-syntax': appendSyntax,
                'reverse-syntax': reverseSyntax,
                'quote-string': Values.String.escapeString,
                $promise: $promise,
                $force: $force,
                $quasiUnquote: $quasiUnquote,
                values: values,
                'call-with-values': callWithValues,

                $argumentsList: function(args, n) {
	            var list = nil;
	            for (var i = args.length-1; i >= n; i--)
	                list = cons(args[i], list);

	            return list;
                },

                $keyword: function(str) {
	            return new Keyword(str);
                },

                $makeFrame: makeFrame,
                gensym: gensym,

                '#f': false,
                '#n': null,
                '#t': true,
                '#u': undefined,

                alert: function(v) {
	            alert(v);
	            return true;
                },

                'quasi-unquote': function (t, ___) {
	            var i, arg, lambdas = [];
	            for (i = 1; i < arguments.length; i++) {
	                v = arguments[i];
	                lambdas.push(function () { return v; });
	            }
	            return $quasiUnquote(t, lambdas);
                },

                'eqv?': function(a, b) {
	            return a === b
	                || ((isSymbol(a) || isKeyword(a))
	                    && (isSymbol(b) || isKeyword(b))) && a.toString() == b.toString()
	                || isNumber(a) && isNumber(b) && a.valueOf() == b.valueOf()
	                || isString(a) && isString(b) && a == b;
                },

                'eq?': function(a, b) {
	            return a === b
	                || ((isSymbol(a) || isKeyword(a))
	                    && (isSymbol(b) || isKeyword(b))) && a.toString() == b.toString()
	            //	  || isSymbol(a) && isSymbol(b) && a.toString() == b.toString()
	            //	  || isKeyword(a) && isKeyword(b) && a.toString() == b.toString()
	                || isNumber(a) && isNumber(b) && a.valueOf() == b.valueOf()
	                || isString(a) && isString(b) && a == b
	                || (a && a.$values ? a.$values[0] : a) == (b && b.$values ? b.$values[0] : b);
                },

                'equal?': function(a, b) {
	            if (Moosky.Top['eq?'](a, b))
	                return true;

	            if (!isList(a) || !isList(b))
	                return false;

	            return Moosky.Top['equal?'](car(a), car(b)) && Moosky.Top['equal?'](cdr(a), cdr(b));
                },

                'number?': function(a) {
	            return typeof(a) == 'number';
                },

                'complex?': function(a) {
	            return false;
                },

                'real?': function(a) {
	            return Moosky.Top['number?'](a);
                },

                'rational?': function(a) {
	            return false;
                },

                'integer?': function(a) {
	            return IsInteger(a);
                },

                'exact?': function(a) {
	            return false;
                },

                'inexact?': function(a) {
	            return Moosky.Top['number?'](a);
                },

                '=': numericComparator('=', function(a, b) { return a == b; }),
                '<': numericComparator('<', function(a, b) { return a < b; }),
                '>': numericComparator('>', function(a, b) { return a > b; }),
                '<=': numericComparator('<=', function(a, b) { return a <= b; }),
                '>=': numericComparator('>=', function(a, b) { return a >= b; }),

                'zero?': function(a) {
	            return isNumber(a) && a.valueOf() == 0;
                },

                'positive?': function(a) {
	            return isNumber(a) && a.valueOf() > 0;
                },

                'negative?': function(a) {
	            return isNumber(a) && a.valueOf() < 0;
                },

                'odd?': function(a) {
	            return isNumber(a) && Math.abs(a.valueOf() % 2) == 1;
                },

                'even?': function(a) {
	            return isNumber(a) && a.valueOf() % 2 == 0;
                },

                max: numericFold('max', function(m, a) { return m > a ? m : a; }),
                min: numericFold('min', function(m, a) { return m < a ? m : a; }),
                '+': numericFold('+', function(s, a) { return s + a; }, 0),
                '-': numericFold('-', function(d, a) { return d - a; }, 0),
                '*': numericFold('*', function(p, a) { return p * a; }, 1),
                '/': numericFold('/', function(q, a) { return q / a; }, 1),

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
	            if (arguments.length == 1)
	                return Math.atan(a.valueOf());

	            return Math.atan2(a.valueOf(), b.valueOf());
                },

                sqrt: numericUnop('sqrt', function(a) { return Math.sqrt(a); }),

                expt: numericBinop('expt', function(a, b) { return Math.pow(a, b); }),

                'string->number': function(str, radix) {
	            if (radix === undefined)
	                return parseFloat(str);

	            return parseInt(str, radix);
                },

                'number->string': function(a, radix) {
	            return (new Number(a.valueOf())).toString(radix);
                },

                not: function(a) {
	            return a == false;
                },

                'boolean?': function(a) {
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
	            ch = ch !== undefined ? ch : ' ';
	            var s = '';
	            while (k-- > 0)
	                s += ch;

	            return s;
                },

                'string': function(___) {
	            return Array.apply(Array, arguments).join('');
                },

                'string-length': stringOperator('string-length', function(s) { return s.length; }),

                'string-ref': function(s, k) {
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
	            return s.slice(start, end);
                },

                'string-append': function(___) {
	            return Array.apply(Array, arguments).join('');
                },

                'string->list': function(s) {
	            var lst = nil;
	            for (var i = s.length-1; i >= 0; i--)
	                lst = cons(s.charAt(i), lst);

	            return lst;
                },

                'list->string': function(lst) {
	            const chs = [];
	            while (lst != nil) {
	                const ch = car(lst);
	                chs.push(ch);
	                lst = cdr(lst);
	            }

	            return chs.join('');
                },

                'string-copy': function(s) {
	            return String(s);
                },

                'string-for-each': function(proc, s0, ___) {
	            const strs = [s0];
	            const length = s0.length;
	            for (var i = 2; i < arguments.length; i++) {
	                const s = arguments[i];
	                strs.push(s);
	            }

	            for (i = 0; i < length; i++) {
	                const chs = [];
	                for (var j = 0; j < strs.length; j++)
	                    chs.push(strs[j].charAt(i));

	                $force(proc(chs));
	            }
                },

                'vector?': function(v) {
	            return v instanceof Array;
                },

                'make-vector': function(k, obj) {
	            const v = new Array();
	            while (k-- > 0)
	                v.push(obj);

	            return v;
                },

                'vector': function(___) {
	            const v = new Array;
	            for (var i = 0; i < arguments.length; i++)
	                v.push(arguments[i]);

	            return v;
                },

                'vector-length': function(v) {
	            return v.length;
                },

                'vector-ref': function(v, k) {
	            return v[k];
                },

                'vector-set!': function(v, k, obj) {
	            v[k] = obj;
                },

                'vector->list': function(v) {
	            var lst = nil;
	            for (var i = v.length-1; i >= 0; i--)
	                lst = cons(v[i], lst);

	            return lst;
                },

                'list->vector': function(lst) {
	            // use makeVector?
	            const v = new Array();
	            while (lst != nil) {
	                v.push(car(lst));
	                lst = cdr(lst);
	            }

	            return v;
                },

                'vector-for-each': (function () {
	            const iter = vectorIterator('vector-for-each');
	            return function(___) { iter.apply(null, arguments); };
                })(),

                'vector-map': (function () {
	            const iter = vectorIterator('vector-map', cons);
	            return function(___) { return reverse(iter.apply(null, arguments)); };
                })(),

                'symbol?': function(s) {
	            return s instanceof Symbol;
                },

                'keyword?': function(k) {
	            return k instanceof Keyword;
                },

                'symbol->string': function(sym) {
	            return sym.$sym;
                },

                'string->symbol': function(s) {
	            return s.match(/:$/) ? new Keyword(s) : new Symbol(s);
                },

                'procedure?': function(p) {
	            return typeof(p) == 'function';
                },


                'for-each': (function () {
	            const iter = iterator('for-each');
	            return function(___) { iter.apply(null, arguments); };
                })(),

                'map': (function () {
	            const iter = iterator('map', cons);
	            return function(___) { return reverse(iter.apply(null, arguments)); };
                })(),

                'range': function (n, m, step) {
	            return Moosky.Top['vector->list'](range(n, m, step));
                },

                'apply': function(proc, ___, lst) {
	            const tailIndex = arguments.length-1;
	            var tail = arguments[tailIndex];

	            const args = [];
	            for (var i = 1; i < tailIndex; i++)
	                args.push(arguments[i]);

	            while (tail != nil) {
	                args.push(car(tail));
	                tail = cdr(tail);
	            }

	            return $force(proc.apply(null, args));
                },

                get: function(url, ___) {
	            const options = argsToObject(arguments, 1);
	            if (options.handlers)
	                options.handlers = sexpToObject(options.handlers);

	            const handlers = options.handlers;
	            if (handlers)
	                for (p in handlers)
	                    handlers[p] = (function(h) { return function(s) { return $force(h(s)); }; })(handlers[p]);

	            return Moosky.HTML.get(url, nil, options);
                },

                compile: function(sexp, module) {
	            return Moosky.Compiler.compile(sexp, module || Moosky.Top);
                },

                'js-quote': function(str) {
	            return new Values.Javascript(str);
                },

                'new!': function(constructor) {
	            return new constructor();
                },

                '?>>': function() {
	            const insp = Moosky.Top.$lastInspector;
	            if (insp && insp.children.length > 0)
	                Moosky.Top.$lastInspector = insp.children[insp.children.length-1];
                },

                '<<?': function() {
	            const insp = Moosky.Top.$lastInspector;
	            if (insp && insp.inspector)
	                Moosky.Top.$lastInspector = insp.inspector;
                },

                ':?': function() {
	            const insp = Moosky.Top.$lastInspector;
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

                greeting: function() {
	            return "Welcome to Moosky v0.1, Copyright 2010 Pat M. Lasswell.";
                },

                license: function() {
	            return Moosky.License;
                },

                version: function() {
	            return Moosky.Version;
                }
            };

            Moosky.Runtime.Bare.Top.$symbol = Moosky.Runtime.Bare.Top['string->symbol'];
            Moosky.Runtime.Bare.Top.$js = Moosky.Runtime.Bare.Top['js-quote'];

        }
    }
)();
