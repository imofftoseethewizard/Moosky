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
   onDocumentBody(runTests);
   
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

   function onDocumentBody(fn) {
     var intervalID = window.setInterval(pollBody, 100);

     function pollBody() {
       if (!document.body)
	 return;

       window.clearInterval(intervalID);
       fn();
     }
   }
   
   function runTests() {
     initializePrint();

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
				 print('\n\nall files loaded successfully.');
			     }
			   };
			 })(file);

       var src = get(file, {}, 
		     { mimeType: 'text/plain',
		       handlers: { complete: onComplete }
		     });
     }
   }

   function tryEval(src) {
     try {
       eval(src);
     } catch (e) {
       return false;
     }
     return true;
   }
   
   var pre;

   function initializePrint() {
     pre = document.createElement('pre');
     document.body.appendChild(pre);
   }
   
   function print(msg) {
     pre.appendChild(document.createTextNode(msg));
   }

   if (typeof(XMLHttpRequest)  === "undefined") {
     XMLHttpRequest = function() {
       try { return new ActiveXObject("Msxml2.XMLHTTP.6.0"); }
	 catch(e) {}
       try { return new ActiveXObject("Msxml2.XMLHTTP.3.0"); }
	 catch(e) {}
       try { return new ActiveXObject("Msxml2.XMLHTTP"); }
	 catch(e) {}
       try { return new ActiveXObject("Microsoft.XMLHTTP"); }
	 catch(e) {}
       throw new Error("This browser does not support XMLHttpRequest.");
     };
    }

    function loggingHandler(state) {
  //    console.log('readyState: ' + state.currentTarget.readyState);
  //    console.log(state);
    }

    var readyStateAliases = {
      0: 'uninitialized',
      1: 'initialized',
      2: 'sent',
      3: 'receiving',
      4: 'complete'
    };

    var readyStateDispatchLoggingHandlers = {
      'uninitialized': loggingHandler,
      'initialized': loggingHandler,
      'sent': loggingHandler,
      'receiving': loggingHandler,
      'complete': loggingHandler
    };

    var readyStateDispatchNullHandlers = {};

    function makeReadyStateDispatcher(options) {
      var aliases = options.aliases || readyStateAliases;
      var handlers = options.log ? readyStateDispatchLoggingHandlers
				 : options.handlers || readyStateDispatchNullHandlers;

      return function(state) {
	var response = state.currentTarget;
	var key = aliases[response.readyState];
	var handler = key && handlers[key];
	return handler && handler(state);
      };
    }

    function get(url, params, options) {
      options = options || {};
      var r = new XMLHttpRequest();
      r.open('get', url, true);
      r.onreadystatechange = options.dispatch || makeReadyStateDispatcher(options);
      if (options.mimeType)
	r.overrideMimeType(options.mimeType);
      r.send();
    }
 })();


