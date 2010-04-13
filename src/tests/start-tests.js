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

$Tests = (function ()
{
  function onDocumentBody(fn) {
    var intervalID = window.setInterval(pollBody, 100);

    function pollBody() {
      if (!document.body)
	return;

      window.clearInterval(intervalID);
      fn();
    }
  }

  onDocumentBody(function() {
		   initializePrint();
		   var queue = $Tests.queue, length = queue.length;
		   for (var i = 0; i < length; i++)
		     queue[i]();
		 });

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
  
  return { get: get,
	   print: print,
	   queue: [] };
})();


