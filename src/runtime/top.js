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

Moosky.Top = (function ()
{
  var Bare = {};

  var Values = Moosky.Values;
  var Symbol = Values.Symbol;
  
  Symbol.setTranslations({ '+': '$plus',
			   '-': '$minus',
			   '*': '$times',
			   '/': '$divides' });

  var Runtime = Moosky.Runtime;
  var RuntimeTop = Runtime.Safe && Runtime.Safe.Top 
		     || Runtime.Bare && Runtime.Bare.Top;

  var Top = {};
  Top.$frame = Top;

  var munge = Symbol.munge;
  
  for (var p in RuntimeTop) {
    var munged = munge(p);
    var target = RuntimeTop[p];
    Top[munged] = target;
    if (typeof(target) == "function")
      target.$primitive = true; 
  }

  return Top;
})();
