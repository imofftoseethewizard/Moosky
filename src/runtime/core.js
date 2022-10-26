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

(
    function () {
        var Runtime = Scheme.Runtime;
        var RuntimeVariant = Runtime.Safe || Runtime.Bare;
        Runtime.exports = RuntimeVariant.exports;

        var imports = ['with (Scheme.Runtime) {'];
        for (var p in Runtime.exports)
            imports.push(['var ', p, ' = exports.', p, ';'].join(''));

        imports.push('}');

        Runtime.importExpression = imports.join('');
    }
)();
