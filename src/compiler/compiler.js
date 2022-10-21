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

//=============================================================================
//
// Recursion and Tail Call Optimization
//
// Mutable Symbols
//   A symbol is mutable if two conditions hold:
//     (i) if it is the target of a set! form, and
//     (ii) a. if it is the target of more than one set! form, or
//          b. if the set! form is preceded by anything but other set! forms in the
//            defining lambda, or
//          c. if the set! form occurs in an interior lambda.
//
//   In particular symbols which are immediately set! within the defining
//   lambda -- and nowhere else -- are not considered mutable.
//
// Definitely recursive applications:
//   Within the value of a set! statement
//     and the applicand is not mutable and is the target of a containing set!
//
// Possibly recursive applications:
//   application is definitely recursive or
//   applicand is an application or
//   applicand is a mutable symbol
//
// Definitively not recursive applications:
//   primitives (except call-with-values)
//   special forms
//
// Promise-making Lambdas
//   A lambda is promise-making if it has a potentially recursive application
//   in tail position.
//
// Examples:
//   A simple letrec-style case:
//     ((lambda (x)
//         (set! x (lambda (y) (if y (x #f) 'bar)))
//         (x #t))
//      #u)
//
//   x is not a mutable symbol, but application (x #f) is definitely recursive
//   and in tail position, the form (lambda (y) ...) must make a promise.
//   Beause (lambda (x) ...) contains no potentially recursive applications,
//   the application (x #t) of the promise-making form (lambda (y) ...) must be
//   forced.  Hence (lambda (x) ...) is not promise-making form.
//
//   Variation of the simple case:
//     ((lambda (x)
//         (set! x (lambda (y) (if y (cons 'foo (x #f)) 'bar)))
//         (x #t))
//      #u)
//
//   Many of the same observations apply, except that in this case the
//   application (x #f) is not in tail position. Hence (lambda (y) ...) need
//   not make a promise, and the application (x #t) is not forced.
//
//   Free-variable case:
//     (lambda (x)
//        (x x))
//
//   in this case, x is a free variable and may take arbitrary values.  x may
//   in fact take a reference to the form (lambda (x) ...). Since (x x) is
//   potentially recursive, the form (lambda (x) ...) must return a promise.
//
//   Application as applicand case:
//     (lambda (x)
//       ((foo) x))
//
//   Like the example above, (foo) may result in a reference to the enclosing
//   form (lambda (x) ...), and similarly, this form must return a promise.
//
//   Simple recursive definition:
//     (define foo)
//     (set! foo
//       (lambda (x)
//         (if (< 0 x)
//             (foo (- x 1))
//             'done)))
//
//   This is the expansion of
//     (define (foo x)
//       (if (< 0 x)
//           (foo (- x 1))
//           'done)))
//
//   (foo (- x 1)) is an explicitly recursive application because it is
//   within the content of a set! with foo as its target.  Hence the
//   form (lambda (x) ...) must promise.  No forcing appears in this case.
//
//   Closure with simple recursion:
//     (define foo)
//     (set! foo
//       ((lambda (counter)
//           (lambda (x)
//             (if (< 0 x)
//                 (begin
//                   (set! counter (+ 1 counter))
//                   (foo (- x 1)))
//                 'done)))
//        0))
//
//   This is the expansion of
//     (define foo
//       (let ([counter 0])
//         (lambda (x)
//           (if (< 0 x)
//               (begin
//                 (set! counter (+ 1 counter))
//                 (foo (- x 1)))
//               'done))))
//
//   In this case (foo (- x 1)) is still an explicitly recursive application,
//   and therefore (lambda (x) ...) must promise.  But the form (lambda (x) ...)
//   itself is not recursive, so the form (lambda (counter) ...) need not
//   promise.  Again, no forces appear here.
//

Moosky.Compiler = (
    function () {
        eval(Moosky.Runtime.importExpression);

        const Values = Moosky.Values;
        const Value = Values.Value;
        const Symbol = Values.Symbol;
        const Keyword = Values.Keyword;
        const Exception = Values.Exception;
        const Inspector = Moosky.Inspector;
        const Code = Moosky.Code;

        const APPLY       = new Symbol('apply');
        const BEGIN       = new Symbol('begin');
        const FORCE       = new Symbol('force');
        const INLINE      = new Symbol('inline');
        const JAVASCRIPT  = new Symbol('javascript');
        const LAMBDA      = new Symbol('lambda');
        const PROMISE     = new Symbol('promise');
        const PROMISING   = new Symbol('promising');
        const QUOTE       = new Symbol('quote');

        function isMacro(v) {
            return v !== undefined && typeof v == 'function' && v.tag == 'macro';
        }

        function isPromisingFunction(v) {
            return v !== undefined && typeof v == 'function' && v.promising;
        }

        function isSymbol(sexp) {
            return sexp instanceof Symbol;
        }

        function isKeyword(sexp) {
            return sexp instanceof Keyword;
        }

        function isJavascript(sexp) {
            var key;
            return isPair(sexp) && isSymbol(key = car(sexp)) && key == 'javascript';
        }

        function isLambdaForm(sexp) {
            var key;
            return isPair(sexp) && isSymbol(key = car(sexp)) && key == 'lambda';
        }

        function isPromisingLambdaForm(sexp) {
            var key;
            return isPair(sexp) && isSymbol(key = car(sexp)) && key == 'promising'
	        && isLambdaForm(cdr(sexp));
        }

        //===========================================================================
        //
        // Exceptions
        //

        function AssertFailure(message, inspector) {
            Exception.apply(this, arguments);
        }

        AssertFailure.prototype = new Exception();
        AssertFailure.prototype.name = 'AssertFailure';

        //===========================================================================
        //
        // Context Support
        //

        function Context(ctx, options) {
            if (ctx)
                this.parent = ctx;

            options = options || {};
            this.type = options.type;
            this.tail = options.tail;
            this.target = options.target;

            this.symbols = [];
            this.promising = false;
            this.id = Context.count++;
        }

        //---------------------------------------------------------------------------
        //
        // Lambda Contexts
        //

        function lambdaContext(ctx) {
            return new Context(ctx, { type: 'lambda', tail: true });
        }

        Context.prototype.containsContext = function(ctx) {
            var parent;
            return ctx && (ctx == this || (parent = ctx.parent) && this.containsContext(parent));
        };

        Context.prototype.innerLambda = function() {
            var ctx = this;
            while (ctx && ctx.type != 'lambda')
                ctx = ctx.parent;

            return ctx;
        };

        function findInnerLambdaContext(ctx) {
            return ctx && ctx.innerLambda();
        }

        //---------------------------------------------------------------------------
        //
        // Top
        //

        function topContext() {
            return new Context();
        }

        function findTopContext(ctx) {
            while (ctx.parent)
                ctx = ctx.parent;
            return ctx;
        }

        //---------------------------------------------------------------------------
        //
        // Context Guardians
        //

        Context.Guardian = function() {
            this.items = [];
        };

        Context.Guardian.prototype.add = function(ctx, value) {
            const lambdaCtx = ctx.innerLambda() || findTopContext(ctx);
            this.items.push({ ctx: lambdaCtx, value: value });
        };

        Context.Guardian.prototype.get = function(ctx) {
            const items = this.items;
            const length = items.length;

            const result = [];
            const remainder = [];

            for (var i = 0; i < length; i++) {
                const item = items[i];
                if (!ctx || ctx.containsContext(item.ctx))
	            result.push(item.value);
                else
	            remainder.push(item);
            }

            this.items = remainder;
            return result;
        };

        //---------------------------------------------------------------------------
        //
        // Quoted Expressions
        //

        Context.quotes = new Context.Guardian();

        function addQuote(ctx, symbol, value) {
            Context.quotes.add(ctx, { symbol: symbol, value: value });
        }

        function getQuotes(ctx) {
            return Context.quotes.get(ctx);
        }

        //---------------------------------------------------------------------------
        //
        // Defined Names
        //

        Context.definedNames = new Context.Guardian();

        function addDefinedName(ctx, symbol) {
            Context.definedNames.add(ctx, symbol);
        }

        function getDefinedNames(ctx) {
            const result = Context.definedNames.get(ctx);
            return result;
        }

        function getContextBindings(ctx) {
            const bindings = [];
            const quotes = getQuotes(ctx);

            for (var i = 0, length = quotes.length; i < length; i++) {
                const quote = quotes[i];
                bindings.push(quote);
            }

            const names = getDefinedNames(ctx);
            for (var i = 0, length = names.length; i < length; i++)
                bindings.push({ symbol: names[i], value: undefined });

            return bindings;
        }

        Context.count = 0;

        //---------------------------------------------------------------------------
        //
        // Symbol Tracking
        //

        Context.noValue = {};

        function addDefinedSymbol(ctx, sym) {
            bindSymbol(ctx, sym, Context.noValue,
	               findInnerLambdaContext(ctx) ? 'local' : 'module');
        }

        function addLocalSymbol(ctx, sym) {
            bindSymbol(ctx, sym, Context.noValue, 'local');
        }

        function bindSymbol(ctx, sym, value, scope) {
            ctx = findInnerLambdaContext(ctx) || findTopContext(ctx);
            ctx.symbols[sym] = { value: value,
			         mutable: false,
			         scope: scope,
			         free: value === Context.noValue,
			         setCount: 0,
			         ctx: ctx };
            if (scope == 'local')
                sym.munge();
        }

        function findSymbolDescriptor(sym, ctx) {
            while (ctx !== undefined) {
                const desc = ctx.symbols[sym];
                if (desc !== undefined)
	            return desc;

                ctx = ctx.parent;
            }

            return undefined;
        }

        function updateSymbolBinding(ctx, sym, value) {
            const desc = findSymbolDescriptor(sym, ctx);
            if (desc !== undefined)
                desc.value = value;
        }

        //---------------------------------------------------------------------------
        //
        // Tail-call Optimization Support
        //

        function tailContext(ctx) {
            return new Context(ctx, { tail: true });
        }

        function nonTailContext(ctx) {
            return new Context(ctx, { tail: false });
        }

        function isTailContext(ctx) {
            return ctx.tail;
        }

        function possiblyRecursive(applicand, ctx) {
            var desc;
            return (isList(applicand)
	            || (isSymbol(applicand)
		        && (beingDefined(applicand, ctx)
		            || ((desc = findSymbolDescriptor(applicand, ctx))
			        && (desc.mutable || desc.free)))));
        }

        function markLambdaAsPromising(ctx) {
            ctx = findInnerLambdaContext(ctx);
            if (ctx !== undefined)
                ctx.promising = true;
        }

        function isPromisingLambda(ctx) {
            return ctx !== undefined && ctx.promising;
        }

        function isApplicandPromising(applicand, env, ctx) {
            var desc, value;
            return (possiblyRecursive(applicand, ctx)
	            || isPromisingLambdaForm(applicand)
	            || (isSymbol(applicand)
		        && (((value = lookupSymbol(applicand, env))
		             && isPromisingFunction(value))
		            || ((desc = findSymbolDescriptor(applicand, ctx))
			        && (value = desc.value)
			        && isPromisingLambdaForm(value)))));
        }

        function isInline(applicand, env, ctx) {
            var value;
            return (isSymbol(applicand)
	            && !findSymbolDescriptor(applicand, ctx)
	            && (value = lookupSymbol(applicand, env))
	            && value.inline);
        }

        //---------------------------------------------------------------------------
        //
        // Set Value Contexts
        //

        function setValueContext(ctx, target, value) {
            const desc = findSymbolDescriptor(target, ctx);

            if (desc) {
                desc.free = false;
                desc.setCount++;
                desc.mutable = desc.setCount > 1
		    || findInnerLambdaContext(ctx) !== desc.ctx;
                desc.value = value;
            }

            return new Context(ctx, { type: 'set', tail: false, target: target });
        }

        function findSetValueContext(sym, ctx) {
            while (ctx !== undefined) {
                if (ctx.type == 'set' && sym.$sym == ctx.target.$sym)
	            return ctx;

                ctx = ctx.parent;
            }

            return false;
        }

        function beingDefined(sym, ctx) {
            return findSetValueContext(sym, ctx) !== false;
        }

        //==========================================================================
        //
        // Environment
        //

        // This replaces instances of env[symbol.raw()] because the symbol might be
        // e.g. 'core.index-offset' where core is a submodule.  In this case
        // env['core.index-offset'] does not find env['core']['index-offset'], so
        // a little more sophisticated handling is in order.
        function lookupSymbol(sym, env) {
            const components = sym.raw().split('.');
            var result = env;

            for (var i = 0; i < components.length; i++) {
                result = result[components[i]];
                if (!result || (typeof(result) != 'object' && typeof(result) != 'function'))
	            break;
            }

            return result;
        }

        //===========================================================================
        //
        // Parsing
        //

        function parseSexp(sexp, env, ctx) {
            //    console.log('parse sexp--', sexp, ''+sexp);
            if (env === undefined || ctx === undefined) {
                debugger;
            }

            if (!isList(sexp)) {
                if (sexp instanceof Array)
	            return parseVector(sexp, env, ctx);

                if (isSymbol(sexp))
	            return parseSymbol(sexp, env, ctx);

                return sexp;
            }

            const key = car(sexp);

            if (isSymbol(key)) {
                const applicand = lookupSymbol(key, env);
                if (isMacro(applicand)) {
	            // force may not be necessary here....
	            const result = $force(applicand.call(applicand.env, sexp));
	            return parseSexp(result, env, ctx);
                }

                const parsers = { 'and': parseAnd,
		                'begin': parseBegin,
		                '$define': parseDefine,
		                'define-macro': parseDefineMacro,
		                'if': parseIf,
		                'javascript': parseJavascript,
		                'lambda': parseLambda,
		                'or': parseOr,
		                'quote': parseQuote,
		                'quasiquote': parseQuasiQuote,
		                'set!': parseSet };

                const parser = parsers[key];
                if (parser)
	            return parser(sexp, env, ctx);
            }

            return parseApplication(sexp, env, ctx);
        }

        //---------------------------------------------------------------------------
        //
        // Auxiliary Parsing Functions
        //

        function parseNonTailedSequence(sexp, env, ctx) {
            var forms = nil;
            const nonTailCtx = nonTailContext(ctx);
            while (sexp != nil) {
                forms = syntaxStar(parseSexp(car(sexp), env, nonTailCtx), forms);
                sexp = cdr(sexp);
            }

            return reverseSyntax(forms);
        }

        function parseTailedSequence(sexp, env, ctx) {
            var forms = nil;
            var next;

            const parentCtx = ctx;
            const nonTailCtx = nonTailContext(ctx);

            ctx = nonTailCtx;
            while (sexp != nil) {
                next = cdr(sexp);

                if (next == nil)
	            ctx = parentCtx;

                forms = syntaxStar(parseSexp(car(sexp), env, ctx), forms);

                sexp = next;
            }

            return reverseSyntax(forms);
        }

        function parseSymbol(sexp, env, ctx) {
            if (sexp.raw().match(/\./))
                return parseDottedSymbol(sexp, env, ctx);

            if (sexp.requiresQuotes()) {
                const desc = findSymbolDescriptor(sexp, ctx);
                if (sexp.$sym == "$foo-bar_103")
	            debugger;
                if (desc && desc.scope == 'local')
	            sexp.munge();

                else
	            sexp.munge("$['" + sexp.raw() + "']");
            }

            return sexp;
        }

        function parseDottedSymbol(sexp, env, ctx) {
            // TRICKY: This little transformation allows the use of scheme variables
            // to hold javascript objects, and to access the properties of those
            // objects via the usual dot notation.  Hence, if the symbol 'ok-button'
            // refers to a DOM button object, then 'ok-button.title' would refer to
            // the title text and could be used both as a value, or as the target
            // to a set! form, eg, '(set! ok-button.title "Send")'.

            // has a dot that is not the first character
            const components = sexp.raw().split('.');

            const base = new Symbol(components[0]);

            const desc = findSymbolDescriptor(base, ctx);

            // base object symbol is a parameter (or a variety of let binding)
            // These are all munged.
            if (desc && desc.scope == 'local')
                components[0] = Symbol.munge(components[0]);

            // base object symbol is not a parameter but also evidently not
            // a javascript identifier.  Must be a module-level symbol that
            // requires bracketing with namespace referencing
            else if (base.requiresQuotes())
                components[0] = "$['" + components[0] + "']";

            for (var i = 1; i < components.length; i++) {
                const c = components[i];
                if (c.match(/[^\w$]/))
	            components[i] = "['" + c + "']";
                else
	            components[i] = '.' + c;
            }

            sexp.munge(components.join(''))
            return sexp;
        }

        function parseVector(sexp, env, ctx) {
            const result = [];
            var i;
            for (i = 0; i < sexp.length; i++)
                result[i] = parseSexp(sexp[i], env, ctx);

            return result;
        }

        //---------------------------------------------------------------------------
        //
        // Basic Assertions
        //

        function assertIsProperList(sexp) {
            var runner = sexp;
            while (runner != nil) {
                if (!isList(runner))
	            throw new AssertFailure('proper list expected, not ' + sexp);
                runner = cdr(runner);
            }
        }

        function assertIsSymbol(sexp) {
            if (!isSymbol(sexp))
                throw new AssertFailure('symbol expected, not ' + sexp);
        }

        function assertListLength(sexp, n) {
            if (length(sexp) != n)
                throw new AssertFailure('wrong number of parts: ' + n + ' expected, not ' + sexp);
        }

        function assertMinListLength(sexp, n) {
            if (length(sexp) < n)
                throw new AssertFailure('wrong number of parts: at least ' + n + ' expected, not ' + sexp);
        }

        function assertSymbolValue(sexp, s) {
            assertIsSymbol(sexp);
            if (sexp.toString() != s)
                throw new AssertFailure(s + ' expected, not ' + sexp.toString());
        }

        //---------------------------------------------------------------------------
        //
        // Syntax Validation
        //

        function assertApplicationWellFormed(sexp) {
            assertIsProperList(sexp);
        }

        function assertAndWellFormed(sexp) {
            assertIsProperList(sexp);
        }

        function assertBeginWellFormed(sexp) {
            assertIsProperList(sexp);
        }

        function assertDefineWellFormed(sexp) {
            assertIsProperList(sexp);
            assertListLength(sexp, 2);
        }

        function assertDefineMacroTargetWellFormed(sexp) {
            try {
                if (!isList(sexp))
	            assertIsSymbol(sexp);

                else {
	            assertIsProperList(sexp);
	            assertListLength(sexp, 2);
	            assertIsSymbol(car(sexp));
	            assertIsSymbol(cadr(sexp));
                }
            } catch (e) {
                throw new AssertFailure('a symbol, or a list of two symbols was expected, not ' + sexp);
            }
        }

        function assertDefineMacroWellFormed(sexp) {
            assertIsProperList(sexp);
            assertMinListLength(sexp, 3);
            assertDefineMacroTargetWellFormed(cadr(sexp));
        }

        function assertIfWellFormed(sexp) {
            assertIsProperList(sexp);
            assertListLength(sexp, 4);
        }

        function assertIsJavascript(sexp) {
            assertJavascriptWellFormed(sexp);
            assertSymbolValue(car(sexp), 'javascript');
        }

        function assertJavascriptWellFormed(sexp) {
            assertIsProperList(sexp);
        }

        function assertLambdaWellFormed(sexp) {
            assertIsProperList(sexp);
            assertMinListLength(sexp, 2);
            assertLambdaFormalParametersWellFormed(cadr(sexp));
        }

        function assertLambdaFormalParametersWellFormed(sexp) {
            try {
                while (isPair(sexp)) {
	            assertIsSymbol(car(sexp));
	            sexp = cdr(sexp);
                }

                if (!isList(sexp))
	            assertIsSymbol(sexp);
            } catch (e) {
                throw new AssertFailure('a symbol, a list of symbols, or a dotted list of symbols was expected, not ' + sexp);
            }
        }

        function assertOrWellFormed(sexp) {
            assertIsProperList(sexp);
        }

        function assertQuasiQuoteWellFormed(sexp) {
            assertIsProperList(sexp);
            assertListLength(sexp, 2);
        }

        function assertQuoteWellFormed(sexp) {
            assertIsProperList(sexp);
            assertListLength(sexp, 2);
        }

        function assertSetWellFormed(sexp) {
            assertIsProperList(sexp);
            assertMinListLength(sexp, 3);
            assertIsSymbol(cadr(sexp));
        }

        //---------------------------------------------------------------------------
        //
        // Application Parsers
        //

        function parseApplication(sexp, env, ctx) {
            assertApplicationWellFormed(sexp);

            if (isLambdaForm(car(sexp)))
                return parseAppliedLambda(sexp, env, ctx);

            const forms = parseNonTailedSequence(sexp, env, nonTailContext(ctx));
            const applicand = car(forms);
            const args = cdr(forms);

            if (isInline(applicand, env, ctx))
                return syntaxStar(INLINE, lookupSymbol(applicand, env), args); //DEMUNGE

            const isTail = isTailContext(ctx);
            const recursive = possiblyRecursive(applicand, ctx);
            const promising = isApplicandPromising(applicand, env, ctx);
            var application = syntaxStar(APPLY, applicand, args);

            if (isTail && recursive)
                application = syntaxStar(PROMISE, application);

            else if (!isTail && promising)
                application = syntaxStar(FORCE, application);

            if (isTail && (recursive || promising))
                markLambdaAsPromising(ctx);

            return application;
        }

        function parseAppliedLambda(sexp, env, ctx) {
            const lambdaExp = car(sexp);
            assertLambdaWellFormed(lambdaExp);

            const values = parseNonTailedSequence(cdr(sexp), env, ctx);
            var args = values;

            const lambdaCtx = lambdaContext(ctx);

            var formals = cadr(lambdaExp);
            if (!isList(formals))
                bindSymbol(lambdaCtx, formals, values, 'local'); //DEMUNGE -- add param binding to ctx

            else {
                while (formals != nil) {
	            bindSymbol(lambdaCtx, car(formals), car(args), 'local'); //DEMUNGE -- add param binding to ctx
	            formals = cdr(formals);
	            args = cdr(args);

	            if (!isList(formals))
	                // break for dotted list (rest argument)
	                break;
                }
                formals = cadr(lambdaExp);
            }

            const body = parseTailedSequence(cddr(lambdaExp), makeFrame(env), lambdaCtx);

            const lambda = syntaxStar(car(lambdaExp), formals, body);
            if (isPromisingLambda(lambdaCtx))
                markLambdaAsPromising(ctx);

            var application = syntaxStar(APPLY, lambda, values);
            if (!isTailContext(ctx) && isPromisingLambda(lambdaCtx))
                application = syntaxStar(FORCE, application);

            return application;

        }

        //---------------------------------------------------------------------------
        //
        // Special Form Parsers
        //

        function parseAnd(sexp, env, ctx) {
            assertAndWellFormed(sexp);
            return syntaxStar(car(sexp), parseTailedSequence(cdr(sexp), env, ctx));
        }

        function parseBegin(sexp, env, ctx) {
            assertBeginWellFormed(sexp);
            return syntaxStar(car(sexp), parseTailedSequence(cdr(sexp), env, ctx));
        }

        function parseDefine(sexp, env, ctx) {
            assertDefineWellFormed(sexp);
            addDefinedSymbol(ctx, cadr(sexp));
            return sexp;
        }

        function parseDefineMacro(sexp, env, ctx) {
            assertDefineMacroWellFormed(sexp);

            var name;
            const nameClause = cadr(sexp);
            var body = cddr(sexp);

            if (!isList(nameClause)) {
                name = nameClause.raw();
                body = car(body);

            } else {
                name = car(nameClause).raw();
                body = syntaxStar(LAMBDA, cdr(nameClause), body);
            }

            const code = emitTop(emit(parseSexp(body, env, ctx),
			            new Context(null, { tail: false })),
		               sexp,
		               { namespace: '{}' });

            //    console.log('macro --', code);
            var result;
            // namespace: '{} and the with statement below establish the
            // appropriate lexical environment for the body of the macro.
            with (env) result = eval(code);
            env[name] = result
            env[name].env = env;
            env[name].tag = 'macro';

            return undefined;
        }

        function parseIf(sexp, env, ctx) {
            assertIfWellFormed(sexp);

            return syntax(car(sexp),
		          parseSexp(cadr(sexp), env, nonTailContext(ctx)),
		          parseSexp(caddr(sexp), env, ctx),
		          parseSexp(cadddr(sexp), env, ctx));
        }

        function parseJavascript(sexp, env, ctx) {
            assertJavascriptWellFormed(sexp);

            return syntaxStar(car(sexp), parseNonTailedSequence(cdr(sexp), env, ctx));
        }

        function parseLambda(sexp, env, ctx) {
            assertLambdaWellFormed(sexp);

            ctx = lambdaContext(ctx);

            var formals = cadr(sexp);
            if (!isList(formals))
                addLocalSymbol(ctx, formals);  //DEMUNGE

            else {
                while (formals != nil) {
	            addLocalSymbol(ctx, car(formals));  //DEMUNGE
	            formals = cdr(formals);

	            if (!isList(formals))
	                // break for dotted list (rest argument)
	                break;
                }
                formals = cadr(sexp);
            }

            const body = parseTailedSequence(cddr(sexp), makeFrame(env), ctx);
            var result = syntaxStar(car(sexp), formals, body);
            if (isPromisingLambda(ctx))
                result = syntaxStar(PROMISING, result);
            return result;
        }

        function parseOr(sexp, env, ctx) {
            assertOrWellFormed(sexp);
            return syntaxStar(car(sexp), parseTailedSequence(cdr(sexp), env, ctx));
        }

        function parseQuasiQuote(sexp, env, ctx) {
            assertQuasiQuoteWellFormed(sexp);

            ctx = nonTailContext(ctx);

            const quoted = cadr(sexp);
            if (!isPair(quoted))
                return syntax(QUOTE, quoted);

            function parseQQ(sexp) {
                if (!isPair(sexp))
	            return sexp;

                const A = car(sexp);

                if (isSymbol(A)) {
	            if (A == 'unquote-splicing' || A == 'unquote')
	                return syntax(A, parseSexp(cadr(sexp), env, ctx));

	            if (A == 'quasiquote')
	                return sexp;
                }

                return syntaxStar(parseQQ(A), parseQQ(cdr(sexp)));
            }

            return syntax(car(sexp), parseQQ(quoted));
        }

        function parseQuote(sexp, env, ctx) {
            assertQuoteWellFormed(sexp);
            return sexp;
        }

        function parseSet(sexp, env, ctx) {
            assertSetWellFormed(sexp);

            const target = parseSymbol(cadr(sexp), env, ctx);

            if (target.requiresQuotes()) {
                const desc = findSymbolDescriptor(target, ctx);
                if (desc && desc.scope == 'local')
	            target.munge();

                else
	            target.munge("$['" + target.raw() + "']");
            }

            const value = parseSexp(caddr(sexp), env, setValueContext(ctx, target));

            updateSymbolBinding(ctx, target, value); //DEMUNGE?
            return syntax(car(sexp), target, value);
        }

        //===========================================================================
        //
        // Code Generation
        //

        function emit(sexp, ctx) {
            if (ctx === undefined) {
                debugger;
            }

            //    console.log('emit' + ': ' + sexp);
            if (!isList(sexp)) {
                return (sexp instanceof Value) ? sexp.emit() : '' + emitPrimitive(sexp, ctx);
            }

            const op = car(sexp);

            return ({'and': emitAnd,
	             'apply': emitApply,
	             'begin': emitBegin,
	             '$define': emitDefine,
	             'force': emitForce,
	             'if': emitIf,
	             'inline': emitInline,
	             'javascript': emitJavascript,
	             'lambda': emitLambda,
	             'or': emitOr,
	             'promise': emitPromise,
	             'promising': emitPromising,
	             'quasiquote': emitQuasiQuote,
	             'quote': emitQuote,
	             'set!': emitSet}[op.toString()])(sexp, ctx);
        }

        //---------------------------------------------------------------------------
        //
        // Miscellaneous Auxiliary Functions
        //

        function emitArray(sexp, ctx) {
            const chunks = ['['];
            var i;
            const items = [];
            for (i = 0; i < sexp.length; i++)
                items.push(emit(sexp[i], ctx));

            chunks.push(items.join(', '));
            chunks.push(']');
            return chunks.join('');
        }

        function emitBinding(symbol, value) {
            return Code('binding').fill({ symbol: symbol.emit(), //DEMUNGE -- this should stay munged
				          value: value });
        }

        function emitBindings(bindings) {
            const emitted = [];
            const length = bindings.length;

            for (var i = 0; i < length; i++) {
                const binding = bindings[i];
                emitted.push(emitBinding(binding.symbol, binding.value));
            }

            return (emitted.length > 0) ? emitted.join('  ;\n') + ';\n' : '';
        }

        function emitInline(sexp, ctx) {
            const applicand = cadr(sexp);
            var parameters = cddr(sexp);

            const values = [];
            while (parameters != nil) {
                values.push(emit(car(parameters), ctx));
                parameters = cdr(parameters);
            }

            var result;
            try {
                result = applicand.inline.fill(values);
            } catch (e) {
                throw "" + e + "\n  while emitting " + sexp;
            }
            return result;
        }

        function emitObject(sexp, ctx) {
            if (sexp instanceof Array)
                return emitArray(sexp, ctx);

            return sexp && sexp.toString && sexp.toString() || sexp;
        }

        function emitPrimitive(sexp, ctx) {
            return { 'undefined': function(u) { return 'undefined'; },
	             'boolean':   function(b) { return b ? 'true' : 'false'; },
	             'number' :   function(n) { return n.toString(); },
	             'string':    function(s) { return new Values.String(s).emit(); },
	             'object':    function(o, ctx) { return emitObject(sexp, ctx); },
	             'function':  function(f) {
	                 if (f.constructor !== RegExp)
		             throw new SyntaxError('cannot emit function literal.');

	                 return new Values.RegExp(f).emit();
	             }
	           }[typeof(sexp)](sexp, ctx);
        }

        function emitSequence(sexp, ctx) {
            const values = [];
            while (sexp != nil) {
                values.push(emit(car(sexp), ctx));
                sexp = cdr(sexp);
            }
            return ['(', values.join(', '), ')'].join('');
        }

        function emitTop(body, sexp, options) {
            const source = sexp.$source;
            const params =
                { bindings: emitBindings(getContextBindings()),
	          body: body,
	          namespace: 'Moosky.Top',
	          replId: 0,
	          sourceId: source && Inspector.registerSource(source.$text),
                  start: source && source.$start,
	          end: source && source.$end,
                  sexpId: Inspector.registerSexp(sexp) };

            for (var p in options)
                params[p] = options[p];

            return Code('Top').fill(params);
        }

        //---------------------------------------------------------------------------
        //
        // Special Forms
        //

        function emitAnd(sexp, ctx) {
            sexp = cdr(sexp);

            const values = length(sexp);
            if (values == 0)
                return 'true';

            if (values == 1)
                return emit(car(sexp), ctx);

            const chunks = ['('];
            while (sexp != nil) {
                const next = cdr(sexp);

                if (next == nil) {
	            chunks.push('(');
	            chunks.push(emit(car(sexp), ctx));
	            chunks.push(')');

                } else {
	            chunks.push('(');
	            chunks.push(emit(car(sexp), ctx));
	            chunks.push(') === false ? false : ');
                }

                sexp = next;
            }
            chunks.push(')');
            return chunks.join('');
        }

        function emitApply(sexp, ctx) {
            const applicand = cadr(sexp);
            var parameters = cddr(sexp);

            const values = [];
            while (parameters != nil) {
                values.push(emit(car(parameters), ctx));
                parameters = cdr(parameters);
            }

            const source = sexp.$source || {};
            return Code('application').fill({ body: [emit(applicand, ctx), '(', values.join(', '), ')'].join(''),
				              start: source.$start,
				              end: source.$end,
				              sexpId: Inspector.registerSexp(sexp) });
        }

        function emitBegin(sexp, ctx) {
            const body = cdr(sexp);
            if (body == nil)
                return emit(undefined, ctx);
            else
                return emitSequence(cdr(sexp), ctx);
        }

        function emitDefine(sexp, ctx) {
            const name = cadr(sexp);

            if (!findInnerLambdaContext(ctx))
                // TRICKY: This allocates a member of Moosky.Top with value undefined.
                // The 'with (Moosky.Top)' generated by emitTop will put this value in
                // the undecorated namespace, so that a subsequent 'name = ...' will
                // deposit the rhs into Moosky.Top, rather than creating a new global.
                return Code('top-level-define').fill({ name: name.raw() });

            // emitLambda will put 'var <name> = undefined;' statements in the function
            // preamble.
            addDefinedName(ctx, cadr(sexp));
            return 'undefined';
        }

        function emitForce(sexp, ctx) {
            return Code('force').fill({ expression: emitApply(cdr(sexp), ctx) });
        }

        function emitIf(sexp, ctx) {
            return Code('if').fill({ test: emit(car(sexp = cdr(sexp)), ctx),
			             consequent: emit(car(sexp = cdr(sexp)), ctx),
			             alternate: emit(car(sexp = cdr(sexp)), ctx) });
        }

        function emitJavascript(sexp, ctx) {
            sexp = cdr(sexp);
            const chunks = [];
            while (sexp != nil) {
                const chunk = car(sexp);

                if (chunk instanceof Values.Javascript)
	            chunks.push(chunk.raw());
                else
	            chunks.push(emit(chunk, ctx));

                sexp = cdr(sexp);
            }
            const js = chunks.join('');
            return js;
        }

        function emitLambda(sexp, ctx) {
            const bodyCtx = lambdaContext(ctx);
            const body = emitSequence(cddr(sexp), bodyCtx);

            var formals = cadr(sexp);
            const emittedFormals = [];
            const bindings = getContextBindings(bodyCtx);

            if (isSymbol(formals)) {
                bindings.push({ symbol: formals,
		                value: '$argumentsList(arguments, 0)' }); //DEMUNGE
                emittedFormals.push('___');
            }

            else {
                var i = 0;
                while (formals != nil) {
	            if (!isList(formals)) {
	                bindings.push({ symbol: formals,
			                value: '$argumentsList(arguments, ' + i + ')' }); //DEMUNGE
	                emittedFormals.push('___');
	                break;
	            } else
	                emittedFormals.push(car(formals).emit()); //DEMUNGE

	            formals = cdr(formals);
	            i++;
                }
            }

            const source = sexp.$source || {};

            return Code('lambda').fill({ formals: emittedFormals.join(', '),
				         bindings: emitBindings(bindings),
				         body: body,
				         start: source.$start,
				         end: source.$end,
				         sexpId: Inspector.registerSexp(sexp) });
        }

        function emitOr(sexp, ctx) {
            sexp = cdr(sexp);
            const values = length(sexp);
            if (values == 0)
                return 'false';

            if (values == 1)
                return emit(car(sexp), ctx);

            // ($or_45 = (expr)) != false ? $or_45 : ... : false)
            const $temp = gensym('or');
            addDefinedName(ctx, $temp);

            const chunks = ['('];
            while (sexp != nil) {
                const next = cdr(sexp);

                if (next == nil) {
	            chunks.push('(');
	            chunks.push(emit(car(sexp), ctx));
	            chunks.push(')');

                } else {
	            chunks.push('(');
	            chunks.push($temp.emit());
	            chunks.push(' = (');
	            chunks.push(emit(car(sexp), ctx));
	            chunks.push(')) !== false ? ');
	            chunks.push($temp.emit());
	            chunks.push(' : ');
                }
                sexp = cdr(sexp);
            }
            chunks.push(')');
            return chunks.join('');
        }

        function emitPromise(sexp, ctx) {
            return Code('promise').fill({ expression: emitApply(cdr(sexp), ctx) });
        }

        function emitPromising(sexp, ctx) {
            return Code('promising').fill({ lambda: emitLambda(cdr(sexp), ctx),
				            temp: gensym('promising') });
        }

        function emitQuasiQuote(sexp, ctx) {
            const lambdas = [];

            function emitQQ(sexp) {
                if (!isPair(sexp))
	            return sexp;

                const A = car(sexp);

                if (isSymbol(A) && A == 'unquote-splicing' || A == 'unquote') {
	            // this should be moved to the parse phase
	            lambdas.push(emit(syntaxStar(LAMBDA, nil, cdr(sexp)), ctx));
	            return syntax(A);
                }

                if (isSymbol(A) && A == 'quasiquote')
	            return sexp;

                return syntaxStar(emitQQ(A), emitQQ(cdr(sexp)));
            }

            const quoted = syntax(QUOTE, emitQQ(cadr(sexp)));

            return ['$quasiUnquote(', emitQuote(quoted, ctx), ', [', lambdas.join(', '), '])'].join('');
        }

        function emitQuote(sexp, ctx) {
            const quoted = cadr(sexp);
            if (quoted == nil)
                return '$nil';

            if (isSymbol(quoted))
                return ['$symbol(', (new Values.String(quoted.$sym)).emit(), ')'].join('');

            if (!isList(quoted)) {
                return (quoted instanceof Value) ? quoted.emit() : '' + emitPrimitive(quoted, ctx); //DEMUNGE
            }

            function emitQ(sexp, ctx) {
                if (sexp == nil)
	            return '$nil';

                if (isSymbol(sexp))
	            return ['$symbol(', (new Values.String(sexp.$sym)).emit(), ')'].join('');

                if (!isList(sexp)) {
	            return (sexp instanceof Value) ? sexp.emit() : '' + emitPrimitive(sexp, ctx); //DEMUNGE
                }

                return ['cons(', emitQ(car(sexp), ctx), ', ', emitQ(cdr(sexp), ctx), ')'].join('');
            }
            const $temp = gensym('quote');
            addQuote(ctx, $temp, emitQ(quoted, ctx));

            return $temp.emit();
        }

        function emitSet(sexp, ctx) {
            return Code('set').fill({ target: emit(cadr(sexp), ctx),  //DEMUNGE
			              value: emit(caddr(sexp), ctx) });
        }

        function compile(sexp, env, options) {
            env = env || makeFrame(Moosky.Top);
            options = options || { namespace: env.$namespace };
            //    if (isSymbol(options.namespace))      options.namespace = options.namespace.munge().emit();
            const ctx = new Context(null, { tail: true });
            const parsed = parseSexp(sexp, env, topContext());
            //    console.log('========================================================');
            //    console.log("" + parsed);
            const result = emitTop(emit(parsed, ctx), sexp, options);
            //    if (true) {
            //      console.log('--------------------------------------------------------');
            //      console.log(result);
            //    }
            return result;
        }

        const Compiler = {};

        Compiler.Context = Context;
        Compiler.emit = emit;
        Compiler.parseSexp = parseSexp;
        Compiler.compile = compile;

        return Compiler;
    }
)();
