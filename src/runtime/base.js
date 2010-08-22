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
//

Moosky = (function ()
{
  return function (str, env) {
    var read = Moosky.Reader.read;
    var END = Moosky.Reader.END;
    var compile = Moosky.Compiler.compile;
    var Top = Moosky.Top;
    var evaluate = Moosky.Evaluator.evaluate;

    var tokens = new Moosky.Reader.TokenStream(str);

    var result;
    while (!tokens.finished() && (sexp = read(tokens)) != END) {
      var code = compile(sexp, Top);
//      console.log('evaluating---', code);
      result = evaluate(code);
//      console.log('evaluated---', result, ''+result);
    }

    return result;
//      return eval(Moosky.Compiler.compile(Moosky.Reader.read(str), env));
  };
})();

Moosky.Version = '0.1';
Moosky.License = '\
Moosky is free software: you can redistribute it and/or modify \n\
it under the terms of the GNU General Public License as published by \n\
the Free Software Foundation, either version 3 of the License, or \n\
(at your option) any later version. \n\
\n\
Moosky is distributed in the hope that it will be useful, \n\
but WITHOUT ANY WARRANTY; without even the implied warranty of \n\
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the \n\
GNU General Public License for more details. \n\
\n\
You should have received a copy of the GNU General Public License \n\
along with Moosky.  If not, see <http://www.gnu.org/licenses/>. \n';



