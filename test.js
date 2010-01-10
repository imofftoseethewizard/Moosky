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


function observe(element, eventName, handler) {
  if (element.addEventListener) {
    element.addEventListener(eventName, handler, false);
  } else {
      element.attachEvent("on" + eventName, handler);
  }
}

var intervalID = window.setInterval(startREPL, 100);

function startREPL() {
  var textArea = document.getElementById('id_textarea');
  if (!textArea)
    return;

  window.clearInterval(intervalID);

  var prompt = '> ';
  textArea.value = Moosky.Top.greeting() + '\n' + prompt;
  var last = textArea.value.length;
  var env = Moosky.Core.Primitives.exports.makeFrame(Moosky.Top);
  textArea.focus();
  observe(textArea, 'keyup',
	  function(event) {
	    if (event.keyCode == 13) { // RETURN
	      var sexp;
	      var source;
	      var result;
	      try {
		sexp = Moosky.Core.read(textArea.value.substring(last));
		source = Moosky.compile(sexp, env);
		result = eval(source);
		if (result !== undefined)
		  textArea.value += Moosky.Values.Cons.printSexp(result) + '\n';
		textArea.value += prompt;
		last = textArea.value.length;
	      } catch(e) {
		if (!(e instanceof Moosky.Core.read.IncompleteInputError)) {
		  textArea.value += [e.name, ': ', e.message, '\n', source, '\n', prompt].join('');
		  last = textArea.value.length;
		}
	      }
	    }
	  });
}



