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

Moosky.Values.Safe = (
    function () {
        const Safe = {}, Bare = Moosky.Values.Bare;

        for (var p in Bare)
            Safe[p] = Bare[p];

        // --------------------------------------------------------------------------

        function Cons(a, d) {
            this.$a = a,
            this.$d = d;
        }

        Cons.prototype = new Bare.Cons();

        Cons.nil = Bare.Cons.nil;
        Cons.isCons = function(a) {
            return a === Cons.nil || a instanceof Cons;
        };

        Cons.safe_traverse = function(list, step) {
            var fast = list;
            var slow = list;

            function adv() {
                step(fast);
                fast = fast.$d;
                if (!Cons.isCons(fast)) {
	            debugger;
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
            const argCount = arguments.length;

            if (argCount == 0)
                return Cons.nil;

            const resultHead = new Cons();
            var tail = resultHead;

            for (var i = 0; i < argCount-1; i++) {
                Cons.safe_traverse(arguments[i],
			           function(lst) {
			               const next = new Cons();
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
                return "()";

            if (!Cons.isCons(sexp)) {
                switch (sexp) {
	        case false: return '#f';
	        case null: return '#n';
	        case true: return '#t';
	        case undefined: return '#u';
                }

                if (sexp instanceof Array) {
	            const chunks = [];
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

            const result = [];
            while (sexp != Cons.nil) {
                const A = sexp.$a;
                const D = sexp.$d;

                if (!Cons.isCons(D)) {
	            result.push(Cons.printSexp(A));
	            result.push('.');
	            result.push(Cons.printSexp(D));
	            break;
                }

                if (result.length == 0 && A instanceof Bare.Symbol && A.$sym == 'quote' && D.$d == Cons.nil)
	            return "'" + Cons.printSexp(D.$a);

                result.push(Cons.printSexp(A));
                sexp = D;
            }

            return '(' + result.join(' ') + ')';
        };

        Cons.prototype.toString = function() { return Cons.printSexp(this); };

        Safe.Cons = Cons;
        return Safe;
    }
)();
