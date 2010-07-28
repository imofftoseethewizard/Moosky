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
// General test of the scheme language implemented by Moosky.
// 
//=============================================================================

(function () {
  eval($Moosky.Util.importExpression);
  eval($Moosky.Test.importExpression);

  addTest(new MooskyCompilerTest({
    name: 'Language',
    prereqs: [ new FilesPreReq({ files: ['lib/preamble.ss',
				         'lib/r6rs-list.ss',
					 'platform.ss',
					 'core.ss',
					 'lambda.ss'] }) ],
    action: function() {
//      console.log('starting compiler test action --- \n\n\n\n\n\n\n\n\n\n\n.');
      var Moosky = this.Moosky;
      var nil = Moosky.Values.Cons.nil;
      var Top = Moosky.Top
      var compile = Top.compile;
      var car = Top.car;
      var cdr = Top.cdr;

      var texts = this.texts;
      var files = this.files;
      var evaluator = this.evaluator;

      evaluator('Moosky.Top.printd = window.parent.$Moosky.Util.exports.print;');

      map(function (file) {
//	console.log('compiling---', file, '\n\n\n\n\n\n\n\n\n\n\n\n');
	var sexp = compile(texts[file]);
//	console.log("sexp in action: ", ''+sexp);
	while (sexp != nil) {
//	  console.log("evaluating ==", car(sexp));
	  evaluator(car(sexp)); 
	  sexp = cdr(sexp);
	}
      }, files);

      print('Language ok.');
      this.complete();
    } }));

})();

