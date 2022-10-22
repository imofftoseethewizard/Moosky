;;;----------------------------------------------------------------------------
;;;
;;;  This file is part of Moosky.
;;;
;;;  Moosky is free software: you can redistribute it and/or modify
;;;  it under the terms of the GNU General Public License as published by
;;;  the Free Software Foundation, either version 3 of the License, or
;;;  (at your option) any later version.
;;;
;;;  Moosky is distributed in the hope that it will be useful,
;;;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;;;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;;  GNU General Public License for more details.
;;;
;;;  You should have received a copy of the GNU General Public License
;;;  along with Moosky.  If not, see <http://www.gnu.org/licenses/>.
;;;
;;;____________________________________________________________________________

(unit core
  (test [and
         ((and) #t "null")
         ((and #t) #t "trivial true")
         ((and #f) #f "trivial false")
         ((and 'foo) 'foo "trivial foo")
         ((and #f #t) #f "binary false I")
         ((and #t #f) #f "binary false II")
         ((and #f #f) #f "binary false III")
         ((and #t #t) #t "binary true")
         ((and #f (/ 1 0)) #f "binary short-circuit")
         ((and 1 'a "b" #(2 3) (lambda x x) #u #n #t)
          #t "multiple miscellaneous types")]

        [or
         ((or) #f "null")
         ((or #t) #t "trivial true")
         ((or #f) #f "trivial false")
         ((or 'foo) 'foo "trivial foo")
         ((or #f #t) #t "binary true I")
         ((or #t #f) #t "binary true II")
         ((or #t #t) #t "binary true III")
         ((or #f #f) #f "binary false")
         ((or #t (/ 1 0)) #t "binary short-circuit")
         ((or #f #f #f #t #f) #t "multiple simple")]

        [begin
         ((begin) #u "null")
         ((begin #t) #t "simple true")
         ((begin 'foo) 'foo "simple foo")
         ((begin 1 2 3 4 5 6) 6 "multiple")]

        [case
         ((case #f) #u "null")
         ((case #f [else 'ok]) 'ok "default")
         ((case #f
            [(#t #f #u #n) 'ok]
            [(#\space #\a #\newline) 'wrong]
            [(1 2 3 4) 'wrong]
            [else 'none]) 'ok "default")
         ((case #\newline
            [(#t #f #u #n) 'wrong]
            [(#\space #\a #\newline) 'ok]
            [(1 2 3 4) 'wrong]
            [else 'none]) 'ok "default")
         ((case 1
            [(#t #f #u #n) 'wrong]
            [(#\space #\a #\newline) 'wrong]
            [(1 2 3 4) 'ok]
            [else 'none]) 'ok "default")]

        [cond
         ((cond) #u "null")
         ((cond
           [#t 'ok]) 'ok "simple")
         ((cond
           [#f 'wrong]
           [#t 'ok]) 'ok "simple")
         ((cond
           [#f (/ 1 0)]
           [#t 'ok]) 'ok "no-execute")

         ((cond
           [#f 'wrong]
           ['(1 2) => reverse]) '(2 1) "anaphoric")]

        [if
         ((if #f 'wrong 'ok) 'ok "false")
         ((if #t 'ok 'wrong) 'ok "true")
         ((if #u 'ok 'wrong) 'ok "undefined")
         ((if #n 'ok 'wrong) 'ok "null")
         ((if 0 'ok 'wrong) 'ok "zero")
         ((if '() 'ok 'wrong) 'ok "nil")]

        [javascript
         ({ true } #t "simple value")
         (#{ true }# #t "block simple value")
         ((let ([foo 'bar])
            { @^(foo) }) 'bar "variable insertion")
         ((let ([foo 'bar])
            #{ @^(foo) }#) 'bar "block variable insertion")
         ({ @(symbol->string 'foo) } "foo" "form evaluation")
         (#{ @(symbol->string 'foo) }# "foo" "block form evaluation")
         (#{ (function () {
                var i = 0;
                while (i < 10) {
                  if (i == 5)
                    return "ok";
                  i++;
                }
              })() }# "ok" "block structure")]

         [lambda
          (((lambda (x) x) #t) #t "simplest")
          (((lambda x x) 'a 1.5 "hello") '(a 1.5 "hello") "variable arguments")
          (((lambda (x . y) (list x y)) 1 2 3) '(1 (2 3)) "dotted list")
          (((lambda (x y) (list x y)) 1) '(1 #u) "missing argument")]

         [let
          ((let ([a 'foo]) a) 'foo "simplest")
          ((let ([a 'foo]
                 [b 'bar])
             (let ([a b]
                   [b a])
               (list a b))) '(bar foo) "simple nesting")
          ((let () #t) #t "no bindings case")]

         [let*
          ((let* ([a 'foo]) a) 'foo "simplest")
          ((let* ([a 'foo]
                  [b a])
             (list a b)) '(foo foo) "simple prior reference")
          ((let* ([a 'foo]
                  [b 'bar])
             (let* ([a b]
                    [b a])
               (list a b))) '(bar bar) "simple nesting")
          ((let* () #t) #t "no bindings case")]

         [letrec
          ((letrec ([a 'foo]) a) 'foo "simplest")
          ((letrec ([a 'foo]
                    [b a])
             (list a b)) '(foo #u) "simple prior reference")
          ((letrec ([a 'foo]
                    [b 'bar])
             (letrec ([a b]
                      [b a])
               (list a b))) '(#u #u) "simple nesting")
          ((letrec () #t) #t "no bindings case")
          ((letrec ([foo (lambda (x) (if x 'bar (baz #t)))]
                    [baz (lambda (y) (if y 'quux (foo #t)))])
             (list (foo #f) (baz #f))) '(quux bar))]

         [letrec*
          ((letrec* ([a 'foo]) a) 'foo "simplest")
          ((letrec* ([a 'foo]
                    [b a])
             (list a b)) '(foo foo) "simple prior reference")
          ((letrec* ([a 'foo]
                    [b 'bar])
             (letrec* ([a b]
                      [b a])
               (list a b))) '(#u #u) "simple nesting")
          ((letrec* () #t) #t "no bindings case")
          ((letrec* ([foo (lambda (x) (if x 'bar (baz #t)))]
                    [baz (lambda (y) (if y 'quux (foo #t)))])
             (list (foo #f) (baz #f))) '(quux bar))]

         [let-values
          ((let-values ([(foo bar) (values 1 2)])
             (list foo bar)) '(1 2) "simplest")]

         [let*-values
          ((let*-values ([(foo bar) (values 1 2)])
             (list foo bar)) '(1 2) "simplest")
          ((let*-values ([(foo bar) (values 1 2)]
                         [(baz quux) (values foo bar)])
             (list baz quux)) '(1 2) "simplest")]

         [quasiquote
          (`a 'a "simplest")
          (`(1 2 3) '(1 2 3) "simple list")
          ((let ([foo 'bar])
             `(foo ,foo)) '(foo bar) "simple substitution")
          ((let ([foo '(bar baz)])
             `(foo ,foo)) '(foo (bar baz)) "simple list substitution")
          ((let ([foo '(bar baz)])
             `(foo ,@foo)) '(foo bar baz) "simple splice")]

         [set!
          ((let ([a 'foo])
             (set! a 'bar)
             a) 'bar "simplest")
          ((let ([a { new Object() }])
             (set! a.name "foo-bar")
             a.name) "foo-bar" "simple object case")]))
