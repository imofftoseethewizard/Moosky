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
    var span = document.createElement('span');
    span.appendChild(document.createTextNode(msg));

    pre.appendChild(span);
    return span;
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
  
  function makeFileLoadableTest(file) {
    function onComplete(state) {
      var response = state.currentTarget;
      var text = response.responseText;

      if (tryEval(text)) {
	print(file + ' loaded successfully.\n');
	window.mooskyTestFailures = 0;

      } else {
	print(file + ' failed to load.\n');
	window.mooskyTestFailures = 1;
      }
    };

    function tryEval(src) {
      try {
	eval(src);
      } catch (e) {
	return false;
      }
      return true;
    }

    return function() {
      get(file, {}, 
	  { mimeType: 'text/plain',
	    handlers: { complete: onComplete }
	    });
    };
  }

  function Poll(interval, timeout) {
    this.interval = interval;
    this.timeout = timeout;
  }
   
  Poll.prototype.isReady = function(counter) { return true; };
  Poll.prototype.tick = function(counter) { };
  Poll.prototype.action = function() { };
  Poll.prototype.expired = function() { };

  Poll.prototype.wait = function() {
    if (this.intervalID !== undefined && this.intervalID !== 'finished')
      return;

    var counter = 0;
    var limit = this.timeout/this.interval + 1;

    var _ = this;
    var poll = function() {
      if (counter++ < limit && !_.isReady(counter))
	return;

      _.tick(counter);

      window.clearInterval(_.intervalID);
      _.intervalID = 'finished';

      if (counter <= limit)
	_.action();
      else
	_.expired();
    };

    this.intervalID = window.setInterval(poll, this.interval);
  };

   
  function TestFramePoll(title, src) {
    if (arguments.length == 0)
      return;

    Poll.call(this, 100, 10*1000);

    this.title = title;
    this.src = src;
    this.failures = 0;

    this.indicator = print(title);
    print('\n');

    this.frame = document.createElement('iframe');
    document.body.appendChild(this.frame);
    this.frame.src = src;
    this.frame.style.display = 'none';

    this.wait();
  }

  TestFramePoll.prototype = new Poll();

  TestFramePoll.prototype.isReady = function(counter) {
    return this.frame.contentWindow.mooskyTestFailures !== undefined;
  };

  TestFramePoll.prototype.tick = function(counter) {
    if (counter % 10 == 0)
      this.indicator.firstChild.data += '.';
  };

  TestFramePoll.prototype.action = function() {
    if (this.frame.contentWindow.mooskyTestFailures === undefined ||
	this.frame.contentWindow.mooskyTestFailures > 0)
      this.fail(' -- failed;');
  };

  TestFramePoll.prototype.fail = function(expl) {
    this.indicator.firstChild.data += expl;
    this.provideRunTestLink();
    this.failures++;
  };

  TestFramePoll.prototype.expired = function() {
    this.fail(' -- timed out');
    unitsCount--;
  };

  TestFramePoll.prototype.provideRunTestLink = function() {
    var link = document.createElement('a');
    link.href = this.frame.src;
    link.appendChild(document.createTextNode(' run'));
    this.indicator.appendChild(link);
  };

  return { get: get,
	   makeFileLoadableTest: makeFileLoadableTest,
	   print: print,
	   Poll: Poll,
	   TestFramePoll: TestFramePoll,
	   queue: [] };
})();


