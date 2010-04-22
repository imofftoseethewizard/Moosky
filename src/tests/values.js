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
// test/values.js
// 
// Test unit for runtime/values.js.
// 
//=============================================================================

(function () {
  eval($Moosky.Util.importExpression);
  eval($Moosky.Test.importExpression);

  map(
    function (options) { 
      addTest(new MooskyRuntimeTest({ name: options.label + ' unit',
				      action: new DataDrivenTestAction(options) })); 
    },

      [ { label: 'Character',
	  applicand: function (ch, str, code) {
	    var v = new this.Moosky.Values.Character(ch);

	    this.assert(v.toString() == str, 'Character#toString failed for 0x' + ch.charCodeAt(0) +
			': expected "' + str + '" not "' + v.toString() + '"');
	    this.assert(v.emit() == code, 'Character#emit failed for 0x' + ch.charCodeAt(0) +
			': expected "' + code + '" not "' + v.emit() + '"');
	  },
	  data: [
	    ['\u0000', '#\\nul', '"\u0000"'],
	    ['\u0001', '#\\SOH', '"\u0001"'],
	    ['\u0002', '#\\STX', '"\u0002"'],
	    ['\u0003', '#\\ETX', '"\u0003"'],
	    ['\u0004', '#\\EOT', '"\u0004"'],
	    ['\u0005', '#\\ENQ', '"\u0005"'],
	    ['\u0006', '#\\ACK', '"\u0006"'],
	    ['\u0007', '#\\alarm', '"\u0007"'],
	    ['\u0008', '#\\backspace', '"\u0008"'],
	    ['\u0009', '#\\tab', '"\u0009"'],
	    ['\u000a', '#\\newline', '"\\n"'],
	    ['\u000b', '#\\vtab', '"\u000b"'],
	    ['\u000c', '#\\page', '"\u000c"'],
	    ['\u000d', '#\\return', '"\\r"'],
	    ['\u000e', '#\\SO', '"\u000e"'],
	    ['\u000f', '#\\SI', '"\u000f"'],
	    ['\u0010', '#\\DLE', '"\u0010"'],
	    ['\u0011', '#\\DC1', '"\u0011"'],
	    ['\u0012', '#\\DC2', '"\u0012"'],
	    ['\u0013', '#\\DC3', '"\u0013"'],
	    ['\u0014', '#\\DC4', '"\u0014"'],
	    ['\u0015', '#\\NAK', '"\u0015"'],
	    ['\u0016', '#\\SYN', '"\u0016"'],
	    ['\u0017', '#\\ETB', '"\u0017"'],
	    ['\u0018', '#\\CAN', '"\u0018"'],
	    ['\u0019', '#\\EM', '"\u0019"'],
	    ['\u001a', '#\\SUB', '"\u001a"'],
	    ['\u001b', '#\\esc', '"\u001b"'],
	    ['\u001c', '#\\FS', '"\u001c"'],
	    ['\u001d', '#\\GS', '"\u001d"'],
	    ['\u001e', '#\\RS', '"\u001e"'],
	    ['\u001f', '#\\US', '"\u001f"'],
	    ['\u0020', '#\\space', '"\u0020"'],
	    ['"', '#\\"', '"\\""'],
	    ['\u007f', '#\\delete', '"\u007f"']
	  ] },


	{ label: 'String',
	  applicand: function(s, str, code) {
	    var v = new this.Moosky.Values.String(s);

	    this.assert(v.toString() == str, 'String#toString failed for 0x' + s +
			': expected "' + str + '" not "' + v.toString() + '"');
	    this.assert(v.emit() == code, 'String#emit failed for 0x' + s +
			': expected "' + code + '" not "' + v.emit() + '"');
	  },
	  data: [
	    ['', '""', '""'],
	    ['"', '"""', '"\\""'],
	    ['\n', '"\n"', '"\\n"'],
	    ['\r', '"\r"', '"\\r"'],
	    ['Two\nLines.\n', '"Two\nLines.\n"', '"Two\\nLines.\\n"'],
	    ['"Quoted String"', '""Quoted String""', '"\\"Quoted String\\""'],
	    ['\'Single Quoted\'', '"\'Single Quoted\'"', '"\'Single Quoted\'"']
	  ] },


	{ label: 'Symbol',
	  applicand: function(s, str, code) {
	    var sym = new this.Moosky.Values.Symbol(s);

	    this.assert(sym.toString() == str, 'Symbol#toString failed for ' + s +
			': expected "' + str + '" not "' + sym.toString() + '"');
	    this.assert(sym.emit() == code, 'Symbol#emit failed for ' + s +
			': expected "' + code + '" not "' + sym.emit() + '"');
	  },
	  data: [
	    ['', '||', ''],
	    ['a', 'a', 'a'],
	    ['foo.bar', 'foo.bar', 'foo.bar'],
	    ['foo-bar', 'foo-bar', 'fooBar'],
	    ['[foo', '|[foo|', '_foo'],
	    ['string?', 'string?', 'isString'],
	    ['map*', 'map*', 'mapExt'],
	    ['char->list', 'char->list', 'charToList'],
	    ['<=', '<=', 'Lte'],
	    ['<', '<', 'Lt'],
	    ['>=', '>=', 'Gte'],
	    ['>', '>', 'Gt'],
	    ['string=?', 'string=?', 'isStringEq'],
	    ['abcdefghijklmnopqrstuvwxyz', 'abcdefghijklmnopqrstuvwxyz', 'abcdefghijklmnopqrstuvwxyz'],
	    ['0123456789', '0123456789', '0123456789'],
	    ['foo[', '|foo[|', 'foo_'],
	    ['"foo"', '|"foo"|', '_foo_'],
	    ['\'foo\'', '|\'foo\'|', '_foo_$0'],
	    ['(foo', '|(foo|', '_foo$1'],
	    ['foo)', '|foo)|', 'foo_$2'],
	    [',foo', '|,foo|', '_foo$3'],
	    [';foo', '|;foo|', '_foo$4'],
	    ['foo@bar', '|foo@bar|', 'foo_bar'],
	    ['#foo', '|#foo|', '_foo$5'],
	    ['`foo', '|`foo|', '_foo$6'],
	    ['\\foo', '|\\foo|', '_foo$7'],
	    ['{foo', '|{foo|', '_foo$8'],
	    ['}foo', '|}foo|', '_foo$9']
	  ] },


	{ label: 'Keyword',
	  applicand: function(k, str, code) {
	    var kwd = new this.Moosky.Values.Keyword(k);

	    this.assert(kwd.toString() == str, 'Keyword#toString failed for ' + k +
			': expected "' + str + '" not "' + kwd.toString() + '"');
	    this.assert(kwd.emit() == code, 'Keyword#emit failed for ' + k +
			': expected "' + code + '" not "' + kwd.emit() + '"');
	  },
	  data: [
	    ['', '||', 'stringToSymbol("")'],
	    ['a', 'a', 'stringToSymbol("a")'],
	    ['foo.bar', 'foo.bar', 'stringToSymbol("foo.bar")'],
	    ['foo-bar', 'foo-bar', 'stringToSymbol("foo-bar")'],
	    ['[foo', '|[foo|', 'stringToSymbol("[foo")'],
	    ['string?', 'string?', 'stringToSymbol("string?")'],
	    ['map*', 'map*', 'stringToSymbol("map*")'],
	    ['char->list', 'char->list', 'stringToSymbol("char->list")'],
	    ['<=', '<=', 'stringToSymbol("<=")'],
	    ['<', '<', 'stringToSymbol("<")'],
	    ['>=', '>=', 'stringToSymbol(">=")'],
	    ['>', '>', 'stringToSymbol(">")'],
	    ['string=?', 'string=?', 'stringToSymbol("string=?")'],
	    ['abcdefghijklmnopqrstuvwxyz', 'abcdefghijklmnopqrstuvwxyz', 'stringToSymbol("abcdefghijklmnopqrstuvwxyz")'],
	    ['0123456789', '0123456789', 'stringToSymbol("0123456789")'],
	    ['foo[', '|foo[|', 'stringToSymbol("foo[")'],
	    ['"foo"', '|"foo"|', 'stringToSymbol("\\"foo\\"")'],
	    ['\'foo\'', '|\'foo\'|', 'stringToSymbol("\'foo\'")'],
	    ['(foo', '|(foo|', 'stringToSymbol("(foo")'],
	    ['foo)', '|foo)|', 'stringToSymbol("foo)")'],
	    [',foo', '|,foo|', 'stringToSymbol(",foo")'],
	    [';foo', '|;foo|', 'stringToSymbol(";foo")'],
	    ['foo@bar', '|foo@bar|', 'stringToSymbol("foo@bar")'],
	    ['#foo', '|#foo|', 'stringToSymbol("#foo")'],
	    ['`foo', '|`foo|', 'stringToSymbol("`foo")'],
	    ['\\foo', '|\\foo|', 'stringToSymbol("\\foo")'],
	    ['{foo', '|{foo|', 'stringToSymbol("{foo")'],
	    ['}foo', '|}foo|', 'stringToSymbol("}foo")'],
	    ['"', '|"|', 'stringToSymbol("\\"")'],
	    ['\n', '|\n|', 'stringToSymbol("\\n")'],
	    ['\r', '|\r|', 'stringToSymbol("\\r")'],
	    ['Two\nLines.\n', '|Two\nLines.\n|', 'stringToSymbol("Two\\nLines.\\n")'],
	    ['"Quoted String"', '|"Quoted String"|', 'stringToSymbol("\\"Quoted String\\"")'],
	    ['\'Single Quoted\'', '|\'Single Quoted\'|', 'stringToSymbol("\'Single Quoted\'")']
	  ] } ]);
 
  
})();

