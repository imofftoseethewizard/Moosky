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


Moosky.HTML = (function ()
{
  eval(Moosky.Runtime.importExpression);

  var Symbol = Moosky.Values.Symbol;

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

  function observe(element, eventName, handler) {
    if (element.addEventListener) {
      element.addEventListener(eventName, handler, false);
    } else {
      element.attachEvent("on" + eventName, handler);
    }
  }

  function stopObserving(element, eventName, handler) {
    if (element.removeEventListener) {
      element.removeEventListener(eventName, handler, false);
    } else {
      element.detachEvent("on" + eventName, handler);
    }
  }

  function makeScriptElement(text) {
    var script = document.createElement('script');
    script.type = 'text/javascript';
    script.text = text;

    return script;
  }

  function makeMooskySrcElement(location) {
    var script = document.createElement('script');
    script.type = 'text/moosky';
    script.src = src;

    return script;
  }

  function compileScripts() {
    var scripts = document.getElementsByTagName('script');

    var waitCount = 0, loopFinished = false;
    var sources = [];

    function makeScriptElements() {
      var read = Moosky.Reader.read;
      var END = Moosky.Reader.END;
      var compile = Moosky.Compiler.compile;
      var evaluate = Moosky.Evaluator.evaluate;
      var Top = Moosky.Top;
      var compile = Top.compile;
      var stringAppend = Top.stringAppend;

      for (var j = 0, length = sources.length; j < length; j++) {
	// parentNode becomes null after the script has been processed
//	if (sources[j] != undefined && sources[j].script.parentNode) {
//	  console.log('compiling ' + sources[j].script.src + '...');
//	  var lst = compile(sources[j].text);
//	  var replacement = makeScriptElement(stringAppend.apply(lst));
//	  sources[j].script.parentNode.replaceChild(replacement, sources[j].script);
//	}
	var source = sources[j];
	var script = source.script
	// This ensures we won't process the script twice.
	script.parentNode.removeChild(script);
	Moosky(source.text);
      }
    }

    for (var i = 0, length = scripts.length; i < length; i++) {
      var s = scripts[i];
      if (s.type == 'text/moosky' || s.type == 'text/x-script.scheme') {
	if (s.text)
	  sources[i] = { script: s, text: s.text };

	if (s.src) {
	  waitCount++;
	  var r = new XMLHttpRequest();
	  r.open('get', s.src, true);
	  r.overrideMimeType('text/plain');
	  r.onreadystatechange =
	    (function (script, index) {
	       return function(state) {
		 var response = state.currentTarget;
		 if (response.readyState == 4) {

		   sources[index] = { script: script,
				      text: response.responseText };
//		   console.log('response text: ', response.responseText);
		   if (--waitCount == 0 && loopFinished) {
		     makeScriptElements();
		   }
		 }
	       };
	     })(s, i);
	  r.send();
	}
      }
    }

    if (waitCount != 0)
      loopFinished = true;
    else
      makeScriptElements();
  }

  function dragStartREPL(div, event) {
    var style = window.getComputedStyle(div, null);
    div.style.zIndex = '10';
    div.startX = parseFloat(style.left);
    div.startY = parseFloat(style.top);
    div.originX = event.clientX;
    div.originY = event.clientY;
    div.moveHandler = function() { dragMoveREPL.apply(null, [].concat.apply([div], arguments)); };
    div.endHandler = function() { dragEndREPL.apply(null, [].concat.apply([div], arguments)); };
    observe(document, 'mousemove', div.moveHandler);
    observe(document, 'mouseup', div.endHandler);
  }

  function dragMoveREPL(div, event) {
    var deltaX = event.clientX - div.originX;
    var deltaY = event.clientY - div.originY;

    div.style.left = div.startX + deltaX + 'px';
    div.style.top = div.startY + deltaY + 'px';
  }

  function dragEndREPL(div, event) {
    stopObserving(document, 'mousemove', div.moveHandler);
    stopObserving(document, 'mouseup', div.endHandler);
  }

  function setLastResult(v) {
    Moosky.Top[Symbol.munge('_')] = v;
  }

  function setLastException(e) {
    Moosky.Top[Symbol.munge('!')] = e;
  }

  function setLastInspector(i) {
    Moosky.Top.$lastInspector = i;
  }

  function setTemporaries(v, e, i) {
    v != undefined && setLastResult(v);
    e != undefined && setLastException(e);
    i != undefined && setLastInspector(i);
  }

  function REPL() {
    function Div() { return document.createElement('div'); }
    function Pre() { return document.createElement('pre'); }
    function TextArea() { return document.createElement('textarea'); }
    function TextNode(text) { return document.createTextNode(text); }
    function Span(text) {
      var span = document.createElement('span');
      span.appendChild(new TextNode(text));
      return span;
    }

    var div = new Div();
    div.style.position = 'absolute';
    div.style.width = '896px';
    console.log(document.innerWidth);
    div.style.background = '#202090';

    var titleBar = new Div();
    div.appendChild(titleBar);
    titleBar.appendChild(new TextNode('Moosky'));
    titleBar.style.width = '100%';
    titleBar.style.color = 'white';
    titleBar.style.textAlign = 'center';
    titleBar.style.cursor = 'move';
    observe(titleBar, 'mousedown', function() { dragStartREPL.apply(null, [].concat.apply([div], arguments)); });

    var responseArea = new Div();
    div.appendChild(responseArea);
    responseArea.style.border = '2px solid #4040c2';
    responseArea.style.margin = '0';
    responseArea.style.padding = '0';

    var responseHolder = new Pre();
    responseArea.appendChild(responseHolder);
    responseHolder.style.margin = '0';
    responseHolder.style.padding = '0';
    responseHolder.style.width = parseFloat(div.style.width) - 8 + 'px';
    responseHolder.style.background = "white";
    responseHolder.style.overflow = "scroll";
    responseHolder.style.height = '40em';
    responseHolder.style.border = '2px solid white';

    var divTextAreaCtnr = new Div();
    div.appendChild(divTextAreaCtnr);
    divTextAreaCtnr.style.border = '2px solid #4040c2';
    divTextAreaCtnr.style.margin = '0';
    divTextAreaCtnr.style.padding = '0';

    var textArea = new TextArea();
    divTextAreaCtnr.appendChild(textArea);
    textArea.style.margin = '0';
    textArea.style.padding = '0';
    textArea.style.width = parseFloat(div.style.width) - 8 + 'px';
    textArea.style.height = '5em';
    textArea.style.border = '2px solid white';

    var prompt = '> ';
    responseHolder.appendChild(new Span(Moosky.Top.greeting() + '\n'));

    var last = textArea.value.length;
    textArea.focus();
    setTemporaries();
    observe(textArea, 'keydown',
	    function(event) {
	      var printSexp = Moosky.Values.Cons.printSexp;
	      var TokenStream = Moosky.Reader.TokenStream;
	      var read = Moosky.Reader.read;
	      var END = Moosky.Reader.END;
	      var compile = Moosky.Compiler.compile;
	      var Top = Moosky.Top;
	      var evaluate = Moosky.Evaluator.evaluate;

	      if (event.keyCode == 13) { // RETURN
		if (event.preventDefault)
		  event.preventDefault();
		else
		  event.returnValue = false;
		textArea.value += '\n';
		var sexp, code, result;

		var requestSpan = new Span(prompt + textArea.value);
		requestSpan.style.color = 'blue';
		responseHolder.appendChild(requestSpan);

/*		try*/ {
		  var tokens = new TokenStream(textArea.value);
                   while (!tokens.finished() && (sexp = read(tokens)) != END) {
		    console.log('read --', sexp, sexp.toString());
		    
		    code = compile(sexp, Top);
		    console.log('compile --', code);

		    result = evaluate(code);
		    console.log('evaluate --', result, ''+result);

		    if (result !== undefined) {
		      if (result && result.$values) {
			var resultSpan = new Span(map(printSexp, result.$values).concat('').join('\n'));
			responseHolder.appendChild(resultSpan);
		      }
		      else {
			resultSpan = new Span(printSexp(result) + '\n');
			responseHolder.appendChild(resultSpan);
		      }
		    }
		    textArea.value = '';
		    responseHolder.scrollTop = responseHolder.scrollHeight;
		  }
		  
		  setTemporaries(result);

		} /*catch(e) {
		  if (!(e instanceof Moosky.Reader.IncompleteInputError)) {
		    setTemporaries(undefined, e.exception, e.inspector);
		    var errorSpan = new Span(e.toString() + '\n');
		    errorSpan.style.color = 'red';
		    responseHolder.appendChild(errorSpan);

		    textArea.value = '';
		  }
		}*/
	      }
	    });

    return div;
  }

  function bookmarklet() {
    var dir = window.location.replace(/moosky\.js$/, '');
    for (script in ['preamble.ss', 'r6rs-list.ss'])
      document.body.appendChild(makeMooskySrcElement(dir + script));

    compileScripts();
  }

  return { get: get,
	   compileScripts: compileScripts,
	   REPL: REPL };
})();

Moosky.HTML.compileScripts();
