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

    new Module({ name: 'Test',
	         parent: $Moosky,
	         exports: { PreReq: PreReq,
			    FilesPreReq: FilesPreReq,
			    EnvironmentPreReq: EnvironmentPreReq,
			    MooskyRuntimePreReq: MooskyRuntimePreReq,
			    MooskyCompilerPreReq: MooskyCompilerPreReq,
			    Test: Test,
			    TimedTest: TimedTest,
			    CompositeTest: CompositeTest,
			    MooskyRuntimeTest: MooskyRuntimeTest,
			    MooskyCompilerTest: MooskyCompilerTest,
			    DataDrivenTestAction: DataDrivenTestAction,
			    addTest: addTest,
			    assert: assert,
			    DEBUG: DEBUG,
			    NODEBUG: NODEBUG,
			    LOG: LOG,
			    NOLOG: NOLOG,
			    ERROR: ERROR,
			    NOERROR: NOERROR,
			    assertMode: assertMode } });

    function PreReq(options) {
    }

    PreReq.prototype.fill = function(test) { test.reqFilled(this); };


    function FilesPreReq(options) {
        if (options === undefined)
            return;

        PreReq.call(this, options);

        const files = this.files = options.files;
        const prereq = this;

        this.ready = false;
        const count = new Countdown({ limit: files.length,
				    action: function () { prereq.ready = true; } });
        this.texts = {};
        callWithTextSequentially(options.files,
			         function(file, s) {
			             prereq.texts[file] = s;
			             count.down();
			         });
    }

    FilesPreReq.prototype = new PreReq();
    FilesPreReq.prototype.fill = function(test) {
        const prereq = this;

        this.waitForTexts(function() {
            test.texts = prereq.texts;
            test.files = prereq.files;
            test.reqFilled(prereq);
        });
    };

    FilesPreReq.prototype.waitForTexts = function(fn) {
        const prereq = this;

        new Poll({ interval: 100,
	           isReady: function() { return prereq.ready; },
	           action: fn }).wait();
    }

    function EnvironmentPreReq(options) {
        FilesPreReq.call(this, options);
    }

    EnvironmentPreReq.prototype = new FilesPreReq();

    EnvironmentPreReq.prototype.fill = function(test) {
        const prereq = this;

        this.waitForTexts(function() {
            (new FramedEvaluator()).onReady(function (evaluator) {
	        test.evaluator = prereq.evaluator = evaluator;
	        map(function(file) { tryEval(evaluator, prereq.texts[file]); }, prereq.files);
	        test.reqFilled(prereq);
            });
        });
    };

    function MooskyRuntimePreReq() {
        EnvironmentPreReq.call(this, { files: ["components/base.js",
					       "components/values-bare.js",
					       "components/values.js"] });
    }

    MooskyRuntimePreReq.prototype = new EnvironmentPreReq();

    function MooskyCompilerPreReq() {
        EnvironmentPreReq.call(this, { files: ["standalone/compiler-inlining.js" ] });
    }

    MooskyCompilerPreReq.prototype = new EnvironmentPreReq();

    function Test(options) {
        if (options === undefined)
            return;

        this.action = options.action;

        const test = this;
        const prereqs = this.prereqs = new TaskQueue();
        map(function (pr) { prereqs.add(function() { pr.fill(test); }); }, options.prereqs || []);

        this.failed = 0;
        this.completed = false;
    }

    Test.prototype.run = function () {
        const test = this;
        this.reqCount = new Countdown({ limit: this.prereqs.count(),
				        action: function() { test.action(); } });

        this.prereqs.doAll();
    };

    Test.prototype.reqFilled = function(prereq) { this.reqCount.down(); };

    Test.prototype.fail = function() { Test.failures++; this.failed++; };
    Test.prototype.complete = function () { Test.count.down(); this.completed = true; };
    Test.prototype.assert = assert;

    Test.queue = new OneShotTaskQueue();
    Test.failures = 0;

    addBodyInit(function() {
        Test.count = new Countdown({ limit: Test.queue.count(),
				     action: function() {
					 if (Test.failures == 0)
					     print('\n\nAll tests completed successfully.');
					 else
					     print('\n\nAll tests completed.');
				     } });
    });

    addBodyInit(function() { Test.queue.doAll(); });

    function TimedTest(options) {
        if (options === undefined)
            return;

        Test.call(this, options);

        const test = this;

        this.name = options.name;
        this.timer =  new Timer({ timeout: options.timeout || 10*1000,
			          expired: function() {
				      print(test.name + ' timed out.\n');
				      test.fail();
				      Test.prototype.complete.call(test);
			          } });

        this.timer.start();
    }

    TimedTest.prototype = new Test();

    TimedTest.prototype.timedOut = function() { return this.timer.timedOut(); };
    TimedTest.prototype.complete = function() {
        if (this.timedOut())
            return;

        Test.prototype.complete.call(this);
        this.timer.cancel();
    };

    function CompositeTest(options) {
        if (options === undefined)
            return;

        TimedTest.call(this, options);

        const ctx = this;

        this.count = new Countdown({ limit: options.count,
				     action: function() {
				         TimedTest.prototype.complete.call(ctx);
				     } });
    }

    CompositeTest.prototype = new TimedTest();
    CompositeTest.prototype.complete = function() { this.count.down(); };

    function MooskyTest(options) {
        if (options === undefined)
            return;

        const action = options.action;
        options.action = function() {
            this.Moosky = this.evaluator('Moosky');
            action.apply(this, arguments);
        };

        TimedTest.call(this, options);
    }

    MooskyTest.prototype = new TimedTest();


    function MooskyRuntimeTest(options) {
        if (options === undefined)
            return;

        (options.prereqs = options.prereqs || []).push(new MooskyRuntimePreReq());

        MooskyTest.call(this, options);
    }

    MooskyRuntimeTest.prototype = new MooskyTest();


    function MooskyCompilerTest(options) {
        if (options === undefined)
            return;

        (options.prereqs = options.prereqs || []).push(new MooskyCompilerPreReq());

        MooskyTest.call(this, options);
    }

    MooskyCompilerTest.prototype = new MooskyTest();


    //---------------------------------------------------------------------------
    //
    // addTest(fn)
    //
    // Provides access to a task queue of tests to be performed; fn should be a
    // function of no arguments.  Tests are performed after document has a body.
    //

    function addTest(test) {
        Test.queue.add(function () { test.run(); });
    }

    function DataDrivenTestAction(options) {
        if (options === undefined)
            return;

        this.label = options.label;
        this.applicand = options.applicand;
        this.data = options.data;

        const kernel = this;

        return function() {
            const test = this;

            map(function(args) { kernel.applicand.apply(test, args); }, kernel.data);

            if (!test.failed)
	        print(kernel.label + ' passed\n');

            test.complete();
        }
    }

    //---------------------------------------------------------------------------
    //
    function assert(cond, msg) {
        if (!cond) {
            //      if (this.fail)
            //	fail();

            if (assertDebug)
	        debugger;

            if (assertLog)
	        print('ASSERT FAILURE: ' + msg + '\n.');

            if (assertError) {
	        complete();
	        throw msg;
            }
        }
    }

    var assertDebug, assertLog, assertError;

    //---------------------------------------------------------------------------
    //
    function DEBUG()   { assertDebug = true; }
    function NODEBUG() { assertDebug = false; }
    function LOG()     { assertLog = true; }
    function NOLOG()   { assertLog = false; }
    function ERROR()   { assertError = true; }
    function NOERROR() { assertError = false; }

    function assertMode(___) {
        mapApply(arguments);
    }

    assertMode(LOG, NODEBUG, NOERROR);

})();

/*


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
	   queue: [] }; */
