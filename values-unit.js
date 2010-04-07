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

//=============================================================================
//
// values-unit.js
// 
// Test unit for values.js.
// 
//=============================================================================

(function ()
{
  var Values = Moosky.Values;
  var Character = Values.Character;
  
  function assert(cond, msg) {
    if (!cond) {
      if (assert.debug)
	debugger;      
      
      if (assert.log)
	console.log(msg);
      
      if (assert.error)
	throw msg;
    }
  }
  
  assert.debug = false;
  assert.log = true;
  assert.error = false;
  
  Character.test = function(ch, str, code) {
    var v = new Character(ch);

    assert(v.toString() == str, 'Character#toString failed for 0x' + ch.charCodeAt(0));
    assert(v.emit() == code, 'Character#emit failed for 0x' + ch.charCodeAt(0));
  };
  
  Character.testData = [
    [0, '#\\nul', '\u0000'],
    [1, '#\\SOH', '\u0000']
  ];
    
  var data = Character.testData;
  var length = data.length;
  for (var i = 1; i < data; i++)
    Character.test.apply(null, data[i]);
  
})();