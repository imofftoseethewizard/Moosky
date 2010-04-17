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


(function ()
{
  var get = $Tests.get;
  var print = $Tests.print;

  var files = ["base.js",
	       "values-bare.js",
	       "values-safe.js",
	       "values.js",
	       "core-bare.js",
	       "core-safe.js",
	       "core.js",
	       "top-bare.js",
	       "top-safe.js",
	       "top.js",
	       "reader.js",
	       "inspector.js",
	       "tools.js",
	       "compiler-code.js",
	       "compiler-inlines.js",
	       "compiler.js",
	       "html.js"];

  $Tests.queue.push(function () {
    var i, length = files.length;
    var failures = 0;
    var completions = 0;
    var texts = {};
    for (i = 0; i < length; i++) {
      var file = files[i];
      var onComplete = (function (file) {
			  return function(state) {
			    var response = state.currentTarget;
			    texts[file] = response.responseText;
			    completions++;
			    if (completions == length) {
			      var j;
			      for (j = 0; j < length; j++) {
				var file = files[j];
				var text = texts[file];
				if (tryEval(text)) 
				  print(file + '\n');
				else {
				  print(file + ' failed to load.\n');
				  failures++;
				}
			      }
			      if (failures == 0)
				print('\n\nAll tests completed successfully.');

			      window.mooskyTestFailures = failures;
			    }
			  };
			})(file);

      var src = get(file, {}, 
		    { mimeType: 'text/plain',
		      handlers: { complete: onComplete }
		    });
    }
  });

  function tryEval(src) {
    try {
      eval(src);
    } catch (e) {
      return false;
    }
    return true;
  }

})();


