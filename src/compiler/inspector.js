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


Moosky.Inspector = (
    function () {
        const Values = Moosky.Values;
        const Symbol = Values.Symbol;
        const Cite = Values.Cite;

        //  with (Moosky.Runtime.exports) {
        {
            eval(Moosky.Runtime.importExpression);

            function Inspector(inspector, evaluator, citation) {
                evaluator.children = [];
                evaluator.citation = citation;
                evaluator.inspector = inspector;
                inspector && inspector.children.push(evaluator);
                evaluator.c = [citation];
                return evaluator;
            }

            Inspector.Debug = false;
            Inspector.Citant = function(text) {
                return function(start, end, sexpId) {
	            return new Cite(text, start, end, Moosky.Inspector.Sexps[sexpId]);
                };
            };

            Inspector.Sexps = [];
            Inspector.Sources = [];
            Inspector.Abort = function(inspector, exception) {
                this.inspector = inspector;
                this.exception = exception;
            };

            Inspector.Abort.prototype = new Error();
            Inspector.Abort.prototype.name = 'Abort';

            Inspector.Abort.prototype.toString = function() {
                const insp = this.inspector, e = this.exception;
                if (insp) {
	            var citation;
	            if (insp.c.length > 0)
	                citation = insp.c[insp.c.length-1];
	            else
	                citation  = insp.citation;

	            return [citation.context(3, 3), '\n',
		            e.name, ': while evaluating |', citation.content(), '|: ', e.message].join('');
                }
                return undefined;
            };

            Inspector.Abort.Compiler = function(sexp) {
                return Moosky.Compiler.compile(sexp, null, { namespace: '{}' });
            };

            Inspector.registerSexp = function(sexp) {
                const id = Inspector.Sexps.length;
                Inspector.Sexps.push(sexp);
                return id;
            };

            Inspector.registerSource = function(text) {
                const id = Inspector.Sources.length;
                Inspector.Sources.push(text);
                return id;
            };

            return Inspector;
        }
    }
)();
