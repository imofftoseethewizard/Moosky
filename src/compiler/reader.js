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


Moosky.Reader = (
    function () {
        const Values = Moosky.Values;
        const Symbol = Values.Symbol;
        const Keyword = Values.Keyword;
        const Token = Values.Token;
        const Cite = Values.Cite;
        const Javascript = Values.Javascript;

        //  with (Moosky.Runtime.exports) {
        {
            eval(Moosky.Runtime.importExpression);

            function TokenStream(lexemeClasses, str, predicate) {
                this.lexemeClasses = map(function (lexemeClass) {
                    return { tag: lexemeClass.tag,
                             regexp: new RegExp(lexemeClass.regexp.source, 'g'),
                             normalize: lexemeClass.normalize,
                             condition: lexemeClass.condition,
                             nextMatch: { index: -1 } };
                }, lexemeClasses);
                this.index = 0;
                this.length = str.length;
                this.text = str;
                this.predicate = predicate || function() { return true; };
            }

            TokenStream.prototype.constructor = TokenStream;

            TokenStream.prototype.makeCite = function(lexeme) {
                return new Cite(this.text, this.index, this.index+lexeme.length);
            };

            TokenStream.prototype.getIndex = function() { return this.index; };
            TokenStream.prototype.setIndex = function(i) {
                this.resetLexemesNextMatch();
                return this.index = Math.max(0, Math.min(i, this.length));
            };
            TokenStream.prototype.finished = function() { return this.index >= this.length };


            TokenStream.prototype.resetLexemesNextMatch = function() {
                map(function(lexemeClass) {
                    lexemeClass.nextMatch = { index: -1 };
                }, this.lexemeClasses);
            };


            TokenStream.prototype.next = function() {
                while (!this.finished()) {
                    const token =
                          any.call(this,
                                   function (lexemeClass) {
                                       if (lexemeClass.nextMatch === null)
                                           return false;

                                       if (lexemeClass.nextMatch.index < this.index) {
                                           lexemeClass.regexp.lastIndex = this.index;
                                           lexemeClass.nextMatch = lexemeClass.regexp.exec(this.text);
                                       }

                                       if (lexemeClass.nextMatch === null)
                                           return false;

                                       if (lexemeClass.nextMatch.index == this.index) {
                                           const lexeme = lexemeClass.nextMatch[0];
                                           var norm;

                                           if (lexemeClass.normalize)
                                               norm = lexemeClass.normalize(lexemeClass.nextMatch);

                                           if (!lexemeClass.condition || lexemeClass.condition(this, lexeme))
                                               return new Token(lexeme, lexemeClass.tag, this.makeCite(lexeme), norm);
                                       }

                                       return false;
                                   }, this.lexemeClasses);

                    if (!token) {
                        const preview = this.text.slice(Math.max(0, this.index-30), this.index);
                        const remainder = this.text.slice(this.index, Math.min(this.length, this.index+30));
                        const caret_position = preview.slice(preview.lastIndexOf('\n')+1).length-1;
                        const message = 'lexing failure at: \n'
                              + preview + remainder + '\n'
                              + map(constant(' '), range(caret_position)).join('') + '^';

                        throw message;
                    }

                    if (token.$lexeme.length == 0)
                        throw 'zero length lexeme: ' + token.$tag;

                    this.index += token.$lexeme.length;
                    if (this.predicate(token))
                        return token;
                }
                return null;
            };

            function MooskyTokenStream(str) {
                TokenStream.call(this, Moosky.Reader.LexemeClasses, str,
                                 function (token) {
                                     return token.$tag != 'comment' && token.$tag != 'space';
                                 });
            }

            MooskyTokenStream.prototype = new TokenStream([], '');
            MooskyTokenStream.prototype.constructor = MooskyTokenStream;

            function makeVector(lst) {
                const v = [];
                while (lst != nil) {
                    v.push(car(lst));
                    lst = cdr(lst);
                }

                return v;
            }

            function ReaderError() {
            }
            ReaderError.prototype = new Error();

            function IncompleteInputError() {
            }
            IncompleteInputError.prototype = new ReaderError();
            IncompleteInputError.prototype.name = 'IncompleteInputError';
            IncompleteInputError.prototype.message = 'Input does not form a complete s-expression.';

            function MismatchedDelimitersError(msg) {
                this.$msg = msg;
            }
            MismatchedDelimitersError.prototype = new ReaderError();

            const END = {_: 'end of stream'};
            END.toString = function () { return '<end of input stream>'; };

            function parseAtom(tokens) {
                const start = tokens.getIndex();
                const token = tokens.next();

                if (!token)
                    return END;

                if (token.$lexeme.match(/^[\[\(]|#\(/)) {
                    const result = parseList(tokens, token);

                    if (token.$lexeme == '#(')
                        return makeVector(result);

                    return result;
                }

                if (token.$lexeme.match(/^[\]\)]/)) {
                    tokens.setIndex(start);
                    return END;
                }

                const atom = parseToken(token);

                const implicitList = { "'":  'quote',
                                       '`':  'quasiquote',
                                       ',':  'unquote',
                                       ',@': 'unquote-splicing' }[atom && atom.$sym];

                if (!implicitList)
                    return atom;

                const result = syntaxStar(parseToken(new Token(implicitList, 'symbol', token.$cite, token.$norm)),
                                          syntaxStar(parseAtom(tokens), nil));

                result.$source = new Cite(tokens.text, start, tokens.getIndex());

                return result;
            }


            function parseList(tokens, openDelimiter) {
                const start = tokens.index;
                const delimiter = {'[': ']', '(': ')', '#(': ')'}[openDelimiter.$lexeme];

                var token, next, last = nil;

                var sexp = nil;
                while (true) {
                    next = parseAtom(tokens);

                    if (next == END) {
                        if (tokens.finished()) {
                            debugger;
                            throw new IncompleteInputError();
                        }
                        // parseAtom found a closing delimiter
                        token = tokens.next();
                        if (token.$lexeme != delimiter)
                            throw 'Mismatched ' + openDelimiter.$lexeme + ': found ' + token.$lexeme;

                        break;
                    }

                    //  console.log("next --", next, ''+next);
                    if (isSymbol(next) && next == '.') {
                        last = parseAtom(tokens);

                        if (last == null || last.$lexeme == '.' ||
                            !(token = tokens.next()) || token.$lexeme != delimiter)
                            throw new SyntaxError('improper dotted list');

                        break;
                    }

                    sexp = syntaxStar(next, sexp);
                }

                // reverse, using last (instead of nil) to handle dotted lists.
                var result = last;
                while (sexp != nil) {
                    result = syntaxStar(car(sexp), result);
                    sexp = cdr(sexp);
                }

                if (result != nil)
                    result.$source = new Cite(tokens.text, start, tokens.getIndex());

                return result;
            }

            function parseToken(token) {
                const result = { 'character':   function(token) { return new Values.Character(token.$norm); },
                                 'javascript':  parseJavascript,
                                 'literal':     parseLiteral,
                                 'number':      parseNumber,
                                 'punctuation': function(token) { return new Symbol(token.$lexeme); },
                                 'regexp':      function(token) { return new Values.RegExp(new RegExp(token.$norm)); },
                                 'string':      function(token) { return new Values.String(token.$norm); },
                                 'symbol':      parseSymbol }[token.$tag](token);

                if (result != null && typeof(result) == 'object' && result != nil)
                    result.$source = token.$cite;

                return result;
            }

            function parseJavascript(token) {
                const text = token.$cite.$text;
                const tokens = new MooskyTokenStream(text);

                const block = token.$lexeme[0] == '#';
                var components = block ? cons(new Javascript('(function () { return '), nil) : nil;

                var start = token.$cite.$start + (block ? 2 : 1);
                const end = token.$cite.$end - (block ? 2 : 1);

                const interpolateRE = /[^\\](\\\\)*(@\^?)\(/mg;

                // A little special handling for the initial segments of block quotes
                // is needed.  Since the js is interpolated literally into the emitted code,
                // any CRs at the outset will trigger the automatic semicolon rule
                // after the return in the initial segment '(function () { return '.
                // To fix this, any initial whitespace is skipped.

                if (block) {
                    const blockStartRE = /\s*/mg;
                    blockStartRE.lastIndex = start;
                    start += (blockStartRE.exec(text)[0] || '').length;
                }

                // Interpolate consumes an extra character at the beginning, [^\\], to
                // ensure that the potential string of backslashes (\\\\)* is an even-
                // numbered length.  In the case that the splice indicator is the first
                // character, start one earlier.

                interpolateRE.lastIndex = start-1;
                var last = start;

                var match;
                while ((match = interpolateRE.exec(text))) {
                    if (match.index > token.$cite.$end)
                        break;

                    // The -1 is necessary because parseAtom will return the list enclosed
                    // in parens after the interpolation marker, and it needs the open
                    // paren in the token stream.  The open paren was consumed by the
                    // interpolateRE expression as its last atom.

                    tokens.setIndex(match.index + match[0].length - 1);

                    // The +1 is a compensatory factor for the [^\\] element in the RE
                    // See the comment above at interpolateRE.lastIndex = start-1 for a
                    // discussion.

                    components = syntaxStar(new Javascript(text.substring(last, match.index+1)),
                                            components);

                    const splice = match[2] == '@^';

                    var sexp = parseAtom(tokens);
                    if (!splice)
                        components = syntaxStar(sexp, components);

                    else if (sexp != nil) {
                        components = syntaxStar(car(sexp), components);
                        sexp = cdr(sexp);
                        while (sexp != nil) {
                            components = syntaxStar(new Javascript(', '), components);
                            components = syntaxStar(car(sexp), components);
                            sexp = cdr(sexp);
                        }
                    }

                    last = tokens.getIndex();
                }

                if (last < end)
                    components = syntaxStar(new Javascript(text.substring(last, end)),
                                            components);

                if (block)
                    components = syntaxStar(new Javascript(' })()'), components);

                const js = syntaxStar(new Symbol('javascript'), reverseSyntax(components));
                return js;
            }


            function parseLiteral(token) {
                return { '#f': false,
                         '#n': null,
                         '#t': true,
                         '#u': undefined }[token.$lexeme];
            }

            function parseNumber(token) {
                const lexeme = token.$lexeme;
                if (lexeme.match(/^-?([\d]+|0[xX][\da-fA-F]+)$/))
                    return new Values.Integer(parseInt(lexeme));

                if (lexeme.match(/^-?[\d]+\/[\d]+$/)) {
                    const nd = lexeme.split('/');
                    return new Values.Rational(nd[0], nd[1]);
                }

                return new Values.Real(parseFloat(lexeme));
            }


            function parseDottedSymbol(token) {
                // TRICKY: This little transformation allows the use of scheme variables
                // to hold javascript objects, and to access the properties of those
                // objects via the usual dot notation.  Hence, if the symbol 'ok-button'
                // refers to a DOM button object, then 'ok-button.title' would refer to
                // the title text and could be used both as a value, or as the target
                // to a set! form, eg, '(set! ok-button.title "Send")'.

                // has a dot that is not the first character
                const components = token.$lexeme.split('.');

                components[0] = Symbol.munge(components[0]);

                for (var i = 1; i < components.length; i++) {
                    const c = components[i];
                    if (c.match(/[^\w$]/))
                        components[i] = "['" + c + "']";
                    else
                        components[i] = '.' + c;
                }

                const result = components.join('')
                Symbol.nomunge(result);
                return new Symbol(result, token.$cite, token.$norm);
            }


            function parseSymbol(token) {
                // self-quoting symbols end with a colon, used as keywords
                if (token.$lexeme.match(/:$/))
                    return new Keyword(token.$lexeme.slice(0, -1));

                //      if (token.$lexeme.match(/\./))
                //      return parseDottedSymbol(token)

                return new Symbol(token.$lexeme);
            }

            function read(tokens) {
                return parseAtom(tokens);
            }

            const Reader = { read: read,
                             END: END,
                             IncompleteInputError: IncompleteInputError,
                             TokenStream: MooskyTokenStream,
                           };

            return Reader;
        }
    }
)();

Moosky.Reader.LexemeClasses =
    [ { tag: 'comment',
        regexp: /;.*/ },

      { tag: 'space',
        regexp: /(\s|\n)+/ },

      { tag: 'literal',
        regexp: /#f|#n|#t|#u/ },

      { tag: 'number',
        regexp: /-?0?\.\d+|-?[1-9]\d*(\.\d*)?([eE][+-]?\d+)?|-?0([xX][0-9a-fA-F]+)?/ },

      // standard codes for control characters
      { tag: 'character',
        regexp: /#\\(NUL|SOH|STX|ETX|EOT|ENQ|ACK|BEL|BS|HT|LF|VT|FF|CR|SO|SI|DLE|DC1|DC2|DC3|DC4|NAK|SYN|ETB|CAN|EM|SUB|ESC|FS|GS|RS|US|DEL)/,
        normalize: function(match) {
            return { 'NUL': '\u0000', 'SOH': '\u0001', 'STX': '\u0002', 'ETX': '\u0003',
                     'EOT': '\u0004', 'ENQ': '\u0005', 'ACK': '\u0006', 'BEL': '\u0007',
                     'BS':  '\u0008', 'HT':  '\u0009', 'LF':  '\u000a', 'VT':  '\u000b',
                     'FF':  '\u000c', 'CR':  '\u000d', 'SO':  '\u000e', 'SI':  '\u000f',
                     'DLE': '\u0010', 'DC1': '\u0011', 'DC2': '\u0012', 'DC3': '\u0013',
                     'DC4': '\u0014', 'NAK': '\u0015', 'SYN': '\u0016', 'ETB': '\u0017',
                     'CAN': '\u0018', 'EM':  '\u0019', 'SUB': '\u001a', 'ESC': '\u001b',
                     'FS':  '\u001c', 'GS':  '\u001d', 'RS':  '\u001e', 'US':  '\u001f',
                     'DEL': '\u007f'}[match[1]];
        }
      },

      // standard scheme names for control characters
      { tag: 'character',
        regexp: /#\\(nul|alarm|backspace|tab|linefeed|newline|vtab|page|return|esc|space|delete|altmode|backnext|call|rubout)/,
        normalize: function(match) {
            return { 'nul':     '\u0000', 'alarm':    '\u0007', 'backspace': '\u0008',
                     'tab':     '\u0009', 'linefeed': '\u000a', 'newline':   '\u000a',
                     'vtab':    '\u000b', 'page':     '\u000c', 'return':    '\u000d',
                     'esc':     '\u001b', 'space':    '\u0020', 'delete':    '\u007f',
                     'altmode': '\u001b', 'backnext': '\u001f', 'call':      '\u001a',
                     'rubout':  '\u007f'}[match[1]];
        }
      },

      // standard general form
      { tag: 'character',
        regexp: /#\\([xu]([\da-fA-F]+)|.)/,
        normalize: function(match) {
            if (match[1].length == 1)
                return match[1];
            else
                return String.fromCharCode(parseInt(match[2], 16));
        }
      },

      { tag: 'string',
        regexp: /"([^"\\]|\\(.|\n))*"/m, //"
        normalize: function(match) {
            return eval(match[0].replace(/^"\s*\\\s*\n\s*/, '"')
                        .replace(/\s*\\\s*\n\s*"$/, '"')
                        .replace(/\n/, '\\n')
                        .replace(/\r/, '\\r'));
        }
      },

      { tag: 'regexp',
        regexp: /#\/(([^\/\\]|\\.)*)\//,
        normalize: function(match) { return match[1]; }
      },

      { tag: 'javascript',
        regexp: /\{[^}]*\}/ },

      { tag: 'javascript',
        regexp: /#\{([^\}]|\}[^#])*\}#/m },

      { tag: 'symbol',
        regexp: /[^#$\d\n\s\(\)\[\],@'"`][^$\n\s\(\)"'`\[\]]*/ },

      { tag: 'punctuation',
        regexp: /[\.\(\)\[\]'`]|,@?|#\(/ } //'
    ];
