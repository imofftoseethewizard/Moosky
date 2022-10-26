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
// test/language.js
//
// General test of the scheme language implemented by Scheme.
//
//=============================================================================

(function () {
    eval($Scheme.Util.importExpression);
    eval($Scheme.Test.importExpression);

    addTest(new SchemeCompilerTest({
        name: 'Language',
        prereqs: [ new FilesPreReq({ files: ['lib/preamble.ss',
				             'lib/r6rs-list.ss',
					     'platform.ss',
					     'core.ss',
					     'lambda.ss'] }) ],
        action: function() {
            //      console.log('starting compiler test action --- \n\n\n\n\n\n\n\n\n\n\n.');
            var Scheme = this.Scheme;
            var nil = Scheme.Values.Cons.nil;
            var Top = Scheme.Top

            var cons = Top.cons;
            var car = Top.car;
            var cdr = Top.cdr;
            var reverse = Top.reverse;

            var texts = this.texts;
            var files = this.files;
            var evaluator = this.evaluator;

            function compile (source) {
	        var read = Scheme.Reader.read;
	        var END = Scheme.Reader.END;
	        var compile = Scheme.Compiler.compile;

	        var tokens = new Scheme.Reader.TokenStream(source);

	        var result = nil;
	        while (!tokens.finished() && (sexp = read(tokens)) != END)
	            result = cons(compile(sexp, Top), result);

	        return reverse(result);
            }

            evaluator('Scheme.Top.printd = window.parent.$Scheme.Util.exports.print;');

            map(function (file) {
	        var sexp = compile(texts[file]);
	        while (sexp != nil) {
	            evaluator(car(sexp));
	            sexp = cdr(sexp);
	        }
            }, files);

            print('Language ok.');
            this.complete();
        } }));

})();
