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
    new Module({ name: '$Moosky',
	         exports: {} });


    new Module({ name: 'Util',
	         parent: $Moosky,
	         exports: { Countdown: Countdown,
			    Timer: Timer,
			    Poll: Poll,
			    tryEval: tryEval,
			    tryApply: tryApply,
			    mapApply: mapApply,
			    map: map,
			    TaskQueue: TaskQueue,
			    OneShotTaskQueue: OneShotTaskQueue,
			    addBodyInit: addBodyInit,
			    print: print,
			    get: get,
			    callWithText: callWithText,
			    callWithTextSequentially: callWithTextSequentially,
			    FramedEvaluator: FramedEvaluator,
			    Module: Module } });

    //---------------------------------------------------------------------------
    //
    function Countdown(options) {
        this.count = options.limit || -1;
        options.action && (this.action = options.action);
    }

    Countdown.prototype.action = function() { };
    Countdown.prototype.down = function() { (this.count--, this.count == 0) && this.action(); };

    //---------------------------------------------------------------------------
    //
    function Timer(options) {
        this.timeout = options.timeout;
        options.expired && (this.expired = options.expired);

        this.timeoutID = 'waiting';
    }

    Timer.prototype.expired = function() { };
    Timer.prototype.cancel = function() {
        if (!this.waiting() && !this.canceled() && !this.timedOut()) {
            window.clearTimeout(this._timeoutID);
            this.timeoutID = 'canceled';
        }
    };

    Timer.prototype.waiting = function() { return this.timeoutID == 'waiting'; };
    Timer.prototype.canceled = function() { return this.timeoutID == 'canceled'; };
    Timer.prototype.timedOut = function() { return this.timeoutID == 'timedOut'; };

    Timer.prototype.start = function() {
        if (this.canceled())
            return;

        var _ = this;
        function receiver() {
            if (!_.canceled()) {
	        _.timeoutID = 'expired';
	        _.expired();
            }
        }

        this.timeoutID = window.setTimeout(receiver, this.timeout);
    }

    //---------------------------------------------------------------------------
    //
    // Poll(options)
    //
    // Generic poll-based execution.  Options:
    //
    //   action: a function to be called when isReady returns true; will not be
    //     called if timeout milliseconds elapses before isReady returns true.
    //     Defaults to a null function.
    //
    //   expired: a function to be called when isReady has not returned true and
    //     timeout milliseconds have already elapsed.  action will not be called.
    //     Defaults to a null function.
    //
    //   interval: milliseconds between calls to isReady and tick.  No default
    //     given.  Required for non-trivial uses.
    //
    //   isReady: a function to be called every interval milliseconds until
    //     isReady returns true, or until timeout milliseconds have elapsed.
    //     Defaults to a constantly true function.
    //
    //   tick: a function to be called every interval milliseconds.  It is called
    //     just prior to isReady.  It's argument is the number of times tick has
    //     been called, including the current call.
    //     Defaults to a null function.
    //
    //   timeout: either 'never' or milliseconds to wait calling expired and
    //     ceasing to poll isReady and tick.  action will no be called.
    //     Defaults to 'never'.
    //

    function Poll(options) {
        this.timeout = 'never';

        for (p in options)
            if (p !== 'wait')
	        this[p] = options[p];
    }

    Poll.prototype.isReady = function(counter) { return true; };
    Poll.prototype.tick = function(counter) { };
    Poll.prototype.action = function() { };
    Poll.prototype.expired = function() { };

    Poll.prototype.wait = function() {
        var interval = this.interval;
        var timeout = this.timeout;

        if (this.intervalID !== undefined && this.intervalID !== 'finished')
            return;

        var limit = timeout == 'never' ? Number.MAX_VALUE : timeout/interval + 1;

        var count = new Countdown({ limit: limit, action: finish });

        var _ = this;
        function poll() {
            count.down();
            if (!finished() && _.isReady()) {
	        finish();
	        _.action();
            }
        }

        function finish() {
            if (!finished())
	        window.clearInterval(_.intervalID);

            _.intervalID = 'finished';
        }

        function finished() {
            return _.intervalID == 'finished';
        }

        this.intervalID = window.setInterval(poll, interval);
    };



    //---------------------------------------------------------------------------
    //

    function map(fn, ___) {
        var result = [];
        var inputs = [];
        var length = Number.MAX_VALUE;

        for (var i = 1; i < arguments.length; i++) {
            inputs.push(arguments[i]);
            length = Math.min(length, arguments[i].length);
        }

        var width = inputs.length;

        for (i = 0; i < length; i++) {
            var section = [];
            for (var j = 0; j < width; j++)
	        section.push(inputs[j][i]);

            result.push(fn.apply(this, section));
        }

        return result;
    }

    function tryApply(fn, obj, args) {
        try {
            fn.apply(obj, args);
        } catch (e) {
            console.log(e, args);
            return false;
        }

        return true;
    }

    function tryEval(evaluator, s) {
        return tryApply(evaluator, null, [s]);
    }


    //---------------------------------------------------------------------------
    //

    function mapApply(a) {
        var i, length = a.length;
        for (i = 0; i < length; i++)
            a[i]();
    }


    //---------------------------------------------------------------------------
    //
    // TaskQueue
    //
    // Constructor for queue of thunks.  Methods:
    //
    //   add(task): adds the task to the end of the queue
    //   doAll(): calls all of the thunks in the queue in order, discarding them.
    //

    function TaskQueue() {
        this.queue = [];
    }

    TaskQueue.prototype.add = function(task) {
        if (this.queue == null)
            task();
        else
            this.queue.push(task);
    };

    TaskQueue.prototype.addToFront = function(task) {
        if (this.queue == null)
            task();
        else
            this.queue.unshift(task);
    };

    TaskQueue.prototype.doAll = function() {
        mapApply(this.queue);
        this.queue.length = 0;
    };

    TaskQueue.prototype.count = function() {
        return this.queue ? this.queue.length : 0;
    }


    //---------------------------------------------------------------------------
    //
    // OneShotTaskQueue (TaskQueue)
    //
    // Constructor for a task queue that collects only until the first call to
    // doAll; subsequent adds simply perform the action directly.
    //

    function OneShotTaskQueue() {
        return TaskQueue.call(this);
    }

    OneShotTaskQueue.prototype = new TaskQueue();

    OneShotTaskQueue.prototype.doAll = function() {
        TaskQueue.prototype.doAll.call(this);
        this.queue = null;
    }


    //---------------------------------------------------------------------------
    //
    // addBodyInit(fn)
    //
    // Schedule an initializer to run when document body is valid.  Initializers
    // are guaranteed to run in the order they are scheduled, and are guaranteed
    // to run whether or not document body already exists.
    //

    var bodyInitQueue = new OneShotTaskQueue();

    new Poll({ interval: 100,
	       isReady: function(_) { return document.body; },
	       action: function() { bodyInitQueue.doAll(); }
	     }).wait();

    function addBodyInit(fn) {
        bodyInitQueue.add(fn);
    }


    //---------------------------------------------------------------------------
    //
    // print(msg)
    //
    // A simple printing architecture.  Output goes to a PRE element in document
    // body.  print returns a new SPAN element containing the message.
    //

    var pre = document.createElement('pre');

    function initializePrint() {
        document.body.appendChild(pre);
    }

    function print(msg) {
        var span = document.createElement('span');
        span.appendChild(document.createTextNode(msg));

        pre.appendChild(span);
        return span;
    }

    addBodyInit(initializePrint);


    //---------------------------------------------------------------------------
    //
    // A Platform-independent XHR
    //

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


    //---------------------------------------------------------------------------
    //
    // get(url, params, options)
    //
    // A basic abstraction over XHR, exposing the get method in a convenient form.
    //

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


    //---------------------------------------------------------------------------
    //
    // Specializations of get(): callWithText and callWithTextSequentially.
    //
    // callWithText(url, fn)
    // callWithTextSequentially(urls, fn)
    //
    // These functions apply fn to the text returned by
    //    get(url, {}, { mimeType: 'text/plain' })
    //
    // callWithTextSequentially guarantees that fn will be called with each text
    // in turn, in the order that they are referenced by urls.
    //

    function callWithText(file, fn) {
        get(file, {},
	    { mimeType: 'text/plain',
	      handlers: { complete: function (state) {
                  return fn(state.currentTarget.responseText);
	      } } });
    }

    function callWithTextSequentially(files, fn) {
        var i, file, length = files.length;

        var index = {};
        var count = new Countdown({ limit: length,
				    action: function() {
				        map(function(file) {
					    fn(file, index[file]);
					}, files);
				    } });

        function makeResponder(file) {
            return function(text) {
       	        index[file] = text;
	        count.down();
            };
        }

        map(function(file) {
            callWithText(file, makeResponder(file));
        }, files);
    }


    //---------------------------------------------------------------------------
    //
    // FramedEvaluator()
    //
    // Creates a hidden iframe and appends it to the document body.  Returns a
    // function that evaluates strings -- using 'eval' -- in the context of
    // the document contained in the iframe.
    //

    function FramedEvaluator() {
        var frame = this.frame = document.createElement('iframe');
        frame.src = 'empty.html';
        frame.style.display = 'none';
        document.body.appendChild(frame);

        var script = document.createElement('script');
        script.type = 'text/javascript';
        script.text = 'function evaluate(s) { return eval(s); }';

        new Poll({ interval: 100,
	           isReady: function() { return frame.contentWindow.document.body; },
	           action: function() { frame.contentWindow.document.body.appendChild(script); } }).wait();
    }

    FramedEvaluator.prototype.onReady = function(fn) {
        var contentWindow = this.frame.contentWindow;

        new Poll({ interval: 100,
	           isReady: function() { return contentWindow.evaluate; },
	           action: function () { fn(contentWindow.evaluate); } }).wait();
    };


    //---------------------------------------------------------------------------
    //
    // makeImportExpression
    //
    // Support for code modularization.  makeImportExpression generates a snippet
    // of javascript that when passed to eval, imports values into the current
    // scope.  base should be a string giving an unqualified reference to the
    // object containing the exports, i.e. '$Moosky.Util' for this file.  exports
    // should be a reference to value of the exports member of the object
    // referred to by base, i.e. $Moosky.Util.exports.  The value of exports
    // should be an object whose keys are valid javascript identifiers, and whose
    // values are those to be imported.
    //
    // This behaves almost exactly like the with statement, and is in fact a bit
    // of a kludge to work around a bug in Chrome.
    //

    function makeImportExpression(base, exports) {
        var imports = [];
        for (var p in exports)
            imports.push(['  var ', p, ' = ', base, '.exports.', p, ';\n'].join(''));

        return imports.join('');
    }


    //---------------------------------------------------------------------------
    //
    // Module
    //
    // A simple modularization utility.  Options:
    //
    //   exports: an object whose keys and values represent the bindings to
    //     be added to the local scope when this module's importExpression
    //     is evaluated.
    //
    //   name: the name of this module.  It's generally best if this is a
    //     permissible javascript identifier.  The resulting module object
    //     will reside in the corresponding property of parent (or window,
    //     if parent is null).
    //
    //   parent: the parent module.  If it is omitted, then window is the parent.
    //

    function Module(options) {
        this.name = options.name;
        this.parent = options.parent;
        this.exports = options.exports;

        this.base = (this.parent ? this.parent.base + '.' : '') + this.name;
        this.importExpression = makeImportExpression(this.base, this.exports);

        (this.parent || window)[this.name] = this;
    }

})();
