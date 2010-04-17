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
   var print = $Tests.print;

   var TestFramePoll = $Tests.TestFramePoll;
   
   var units = [ { title: 'Loadable', src: 'loadable.html' },
		 { title: 'Values', src: 'values-test.html' } ];

   var unitsCount = units.length;
   
   function SuiteTestFramePoll(___) {
     TestFramePoll.apply(this, arguments);
   }
   
   SuiteTestFramePoll.prototype = new TestFramePoll;
   SuiteTestFramePoll.prototype.action = function() {
     TestFramePoll.prototype.action.apply(this);
     
     if (unitsCount-- == 1) {
       if (this.failures == 0)
	 print('\n\nAll units pass.');
       window.mooskyTestFailures = this.failures;
     }
   };

   $Tests.queue.push(function () {
		       var length = units.length;
		       for (var i = 0; i < length; i++) {
			 var unit = units[i];
			 new SuiteTestFramePoll(unit.title, unit.src);
		       }
		     });
 })();
