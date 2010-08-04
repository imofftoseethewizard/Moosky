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

(function ()
{
  var InlineTemplate = Moosky.Tools.InlineTemplate;
  
  with (Moosky.Top) {
    $['symbol?'].inline = new InlineTemplate({ 1: "(<<0>>) instanceof Moosky.Values.Symbol" });
    $['keyword?'].inline = new InlineTemplate({ 1: "(<<0>>) instanceof Moosky.Values.Keyword" });
    $['list?'].inline = new InlineTemplate({ 1: "Moosky.Values.Cons.isCons(<<0>>)" });
    $['null?'].inline = new InlineTemplate({ 1: "(<<0>>) === Moosky.Values.Cons.nil" });
    cons.inline = new InlineTemplate({ 2: "new Moosky.Values.Cons(<<0>>, <<1>>)" });
    car.inline = new InlineTemplate({ 1: "(<<0>>).$a" });
    cdr.inline = new InlineTemplate({ 1: "(<<0>>).$d" });
    $['set-car!'].inline = new InlineTemplate({ 2: "((<<0>>).$a = (<<1>>))" });
    $['set-cdr!'].inline = new InlineTemplate({ 2: "((<<0>>).$d = (<<1>>))" });
    
    caar.inline = new InlineTemplate({ 1: "(<<0>>).$a.$a" });
    cadr.inline = new InlineTemplate({ 1: "(<<0>>).$d.$a" });
    cdar.inline = new InlineTemplate({ 1: "(<<0>>).$a.$d" });
    cddr.inline = new InlineTemplate({ 1: "(<<0>>).$d.$d" });

    caaar.inline = new InlineTemplate({ 1: "(<<0>>).$a.$a.$a" });
    caadr.inline = new InlineTemplate({ 1: "(<<0>>).$d.$a.$a" });
    cadar.inline = new InlineTemplate({ 1: "(<<0>>).$a.$d.$a" });
    caddr.inline = new InlineTemplate({ 1: "(<<0>>).$d.$d.$a" });
    cdaar.inline = new InlineTemplate({ 1: "(<<0>>).$a.$a.$d" });
    cdadr.inline = new InlineTemplate({ 1: "(<<0>>).$d.$a.$d" });
    cddar.inline = new InlineTemplate({ 1: "(<<0>>).$a.$d.$d" });
    cdddr.inline = new InlineTemplate({ 1: "(<<0>>).$d.$d.$d" });

    caaaar.inline = new InlineTemplate({ 1: "(<<0>>).$a.$a.$a.$a" });
    caaadr.inline = new InlineTemplate({ 1: "(<<0>>).$d.$a.$a.$a" });
    caadar.inline = new InlineTemplate({ 1: "(<<0>>).$a.$d.$a.$a" });
    caaddr.inline = new InlineTemplate({ 1: "(<<0>>).$d.$d.$a.$a" });
    cadaar.inline = new InlineTemplate({ 1: "(<<0>>).$a.$a.$d.$a" });
    cadadr.inline = new InlineTemplate({ 1: "(<<0>>).$d.$a.$d.$a" });
    caddar.inline = new InlineTemplate({ 1: "(<<0>>).$a.$d.$d.$a" });
    cadddr.inline = new InlineTemplate({ 1: "(<<0>>).$d.$d.$d.$a" });
    cdaaar.inline = new InlineTemplate({ 1: "(<<0>>).$a.$a.$a.$d" });
    cdaadr.inline = new InlineTemplate({ 1: "(<<0>>).$d.$a.$a.$d" });
    cdadar.inline = new InlineTemplate({ 1: "(<<0>>).$a.$d.$a.$d" });
    cdaddr.inline = new InlineTemplate({ 1: "(<<0>>).$d.$d.$a.$d" });
    cddaar.inline = new InlineTemplate({ 1: "(<<0>>).$a.$a.$d.$d" });
    cddadr.inline = new InlineTemplate({ 1: "(<<0>>).$d.$a.$d.$d" });
    cdddar.inline = new InlineTemplate({ 1: "(<<0>>).$a.$d.$d.$d" });
    cddddr.inline = new InlineTemplate({ 1: "(<<0>>).$d.$d.$d.$d" });
    
    length.inline = new InlineTemplate({ 1: "(<<0>>).length()" });
//    append.inline = new InlineTemplate({ 1: "Moosky.Values.Cons.append(<<0>>)",
//					 '...n': 
    reverse.inline = new InlineTemplate({ 1: "(<<0>>).reverse()" });
  }
})();
