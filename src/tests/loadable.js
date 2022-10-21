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


(function () {
    eval($Moosky.Util.importExpression);
    eval($Moosky.Test.importExpression);

    const components = ["components/base.js",
		        "components/values-bare.js",
		        "components/values-safe.js",
		        "components/values.js",
		        "components/core-bare.js",
		        "components/core-safe.js",
		        "components/core.js",
		        "components/top-bare.js",
		        "components/top-safe.js",
		        "components/top.js",
		        "components/reader.js",
		        "components/inspector.js",
		        "components/tools.js",
		        "components/compiler-code.js",
		        "components/compiler-inlines.js",
		        "components/compiler.js",
		        "components/html.js"];

    addTest(new CompositeTest({ name: 'Individual files load test',
			        count: components.length,
			        prereqs: [ new FilesPreReq({ files: components }) ],
			        action: function() {
				    const test = this;
				    (new FramedEvaluator()).onReady(function(evaluator) {
				        map(function(file) {
				            if (tryEval(evaluator, test.texts[file]))
				                print(file + '\n');

				            else {
				                test.fail();
				                print(file + ' failed to load.\n');
				            }
				            test.complete();
				        }, components);
				    });
			        } }));


    map(function(file)
        { addTest(new TimedTest({ name: file + ' load test',
				  prereqs: [ new FilesPreReq({ files: [file] }) ],
				  action: function() {
				      const test = this;
				      (new FramedEvaluator()).onReady(function(evaluator) {
				          if (tryEval(evaluator, test.texts[file]))
				              print(file + '\n');

				          else {
				              test.fail();
				              print(file + ' failed to load.\n');
				          }
				          test.complete();
				      });
				  } }));
        }, ['standalone/runtime-bare.js',
	    'standalone/runtime-safe.js',
	    'standalone/compiler.js',
	    'standalone/compiler-inlining.js',
	    'standalone/repl.js']);
})();
