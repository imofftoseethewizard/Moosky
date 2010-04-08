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


Moosky.Code = (function ()
{
  var Inspector = Moosky.Inspector;

  function Code(item) {
    return (Inspector.Debug ? Code.debug : Code.bare)[item];
  }

  Code.bare = {
    application: '<<body>>',
    binding: 'var <<symbol>> = <<value>>',
    
    'if': '((<<test>>) !== false ? (<<consequent>>) : (<<alternate>>))',

    lambda: '(function (<<formals>>) {\n <<bindings>> return <<body>>;\n })\n',
    
    force: '$force(<<expression>>)',
    promise: '$promise(function () {\n  return <<expression>>;\n})',
    promising: '((<<temp>> = <<lambda>>), <<temp>>.promising = true, <<temp>>)',

    set: '((<<target>> = <<value>>), undefined)',

    'top-level-define': '(Moosky.Top.<<name>> = undefined)',
    
    Top:
      ['(function () {\n  ',
       '  with (<<namespace>>) {\n',
       '<<bindings>>',
       '    return <<body>>;\n',
       '  }\n',
       '})()'].join('')
  };

  Code.debug = {
    application: '($i.c.push($C(<<start>>, <<end>>, <<sexpId>>)), <<body>>)',
    binding: 'var <<symbol>> = <<value>>',
    
    'if': '((<<test>>) !== false ? (<<consequent>>) : (<<alternate>>))',
    
    lambda:
      ['(function(<<formals>>) {\n',
       '<<bindings>>',
       '  return (function ($i) {\n',
       '    return <<body>>;\n',
       '  })($I($i, function(x) { return eval($T(x)); },\n',
       '        $C(<<start>>, <<end>>, <<sexpId>>)));\n',
       '})\n'].join(''),
    
    force: '$force(<<expression>>)',
    promise: ['$promise(function () {\n',
	      '  try {\n',
	      '    return <<expression>>;\n',
	      '  } catch (e) {\n',
	      '    if (e.$i) throw e;\n',
	      '    throw new $E(e.message, $i);\n',
	      '  }\n',
	      '})\n'].join(''),
    
    promising: '((<<temp>> = <<lambda>>), <<temp>>.promising = true, <<temp>>)',

    set: '((<<target>> = <<value>>), undefined)',
    
    'top-level-define': '(Moosky.Top.<<name>> = undefined)',
    
    Top:
      ['(function () {\n  ',
       '  var $I = Moosky.Inspector;\n',
       '  var $C = $I.Citant($I.Sources[<<sourceId>>]);\n',
       '  var $i = $I(null, function(x) { return eval($T(x)); }, $C(<<start>>, <<end>>, <<sexpId>>));\n',
       '  var $E = Moosky.Values.Exception;\n',
       '  var $A = $I.Abort;\n',
       '  var $T = $A.Compiler;\n',
       '  with (<<namespace>>) {\n',
       '<<bindings>>',
       '    try {\n',
       '      return <<body>>;\n',
       '    } catch (e) {\n',
       '      throw new $A(e.$i || $i, e);',
       '    }\n',
       '  }\n',
       '})()'].join('')
  };

  var Template = Moosky.Tools.Template;
  
  for (var p in Code.bare)
    Code.bare[p] = new Template(Code.bare[p]);

  for (var p in Code.debug)
    Code.debug[p] = new Template(Code.debug[p]);

  return Code;
})();

