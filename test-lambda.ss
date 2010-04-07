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

(unit lambda
  (letrec ([foo (lambda () 'ok)]
	   [bar (lambda () (foo))]
	   [baz (lambda () #f)]
	   [quux (lambda () (baz))])

    (test [and
	   ((and (bar)) 'ok "trivial true")
	   ((and (quux)) #f "trivial false")
	   ((and (bar) #f) #f "binary false I")
	   ((and #t (quux)) #f "binary false II")
	   ((and #t (bar)) 'ok "binary true II")]

	  [or
	   ((or (bar)) 'ok "trivial true")
	   ((or (quux)) #f "trivial false")
	   ((or #f (quux)) #f "binary false")
	   ((or (quux) 'ok) 'ok "binary true I")
	   ((or #f (bar)) 'ok "binary true II")]

	  [begin
	   ((begin (bar)) 'ok "simple true")
	   ((begin (bar) (quux)) #f "multiple")]

	  [case
	   ((case (quux) 
	       [(#t #f #u #n) 'ok]
	       [(#\space #\a #\newline) 'wrong]
	       [(1 2 3 4) 'wrong]
	       [else 'none]) 'ok "value")
	    ((case #\newline
	       [(#t #f #u #n) 'wrong]
	       [(#\space #\a #\newline) (bar)]
	       [(1 2 3 4) 'wrong]
	       [else 'none]) 'ok "result")]

	  [cond
	   ((cond
	     [(bar) 'ok]) 'ok "test")
	   ((cond
	     [#f 'wrong]
	     [#t (bar)]) 'ok "result")
	   ((cond
	     [(quux) 'wrong]
	     [#t 'ok]) 'ok "false test")]

	  [if
	   ((if (quux) 'wrong 'ok) 'ok "test false")
	   ((if (bar) 'ok 'wrong) 'ok "test true")
	   ((if #t (bar) 'wrong) 'ok "consequent")
	   ((if #f 'wrong (bar)) 'ok "alternate")]

	  [javascript
	   ({ @(bar) } 'ok "simple value")
	   (#{ @(quux) }# #f "block simple value")]

	  [lambda
	   (((lambda () (bar))) 'ok "body")
	   (((lambda (x) x) (quux)) #f "parameter")]

	  [let
	   ((let ([a (bar)]) a) 'ok "binding")
	   ((let () (quux)) #f "body")]

	  [let-values
	   ((let-values ([(a b) (values (bar) (quux))])
	      (list a b)) '(ok #f) "simplest")]

	  [quasiquote
	   (`(,(foo)) '(ok) "substitution")
	   (`(a ,@(quux)) '(a . #f) "splice")]

	  [set!
	   ((let ([a 'foo])
	      (set! a (bar))
	      a) 'ok "simplest")])))

