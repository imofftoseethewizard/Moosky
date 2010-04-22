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


; (unit <label> . <forms>)
; defines _unit-label
;
(define-macro (unit stx)
  (let ([label (cadr stx)]
	[forms (cddr stx)])
    `(let ([_unit-label (quote ,label)]
	   [_log-trials #f])
       ,@forms)))
 
; (test . <test-items>)
(define-macro (test* stx)
  (letrec ([comparator (cadr stx)]
	   [items (cddr stx)]
	   [make-test-item (lambda (label trials)
			     `(let* ([_test-label (quote ,label)]
				     [_trial-results
				      (list ,@(map (lambda (trial)
						     (make-trial (car trial) (cadr trial)
								 (or (and (pair? (cddr trial))
									  (caddr trial))
								     "")))
						   trials))])
				(and _log-trials
				     (test-console (format "completed: %s: %s.\n" _unit-label _test-label)))
				(filter (lambda (result)
					  (not (eq? result 'ok)))
					_trial-results)))]
	   [make-trial (lambda (form value comment)
			 (if (eq? value '!)
			     'not-implemented
			     `(let ([_trial-value ,form]
				    [_comment ,comment])
				(and _log-trials
				     (test-console (format "attempting: %s: %s: %s\n" _unit-label _test-label (quote ,form))))
				(if (_comparator _trial-value ,value)
				    'ok
				    (format "%s: %s%s: FAILED on %s\n"
					    _unit-label _test-label
					    (if (and (string? _comment)
						     (not (string=? _comment "")))
						(string-append
						 " (" _comment ")")
						"")
					    (quote ,form))))))])
    `(let* ([_comparator ,comparator]
	    [_failed-trials
	     (apply append
		    (list ,@(map (lambda (item)
				   (make-test-item (car item) (cdr item)))
				 items)))])
       (if (zero? (length _failed-trials))
	   (test-console (format "%s: ok\n" _unit-label))
	   (for-all (lambda (result) (test-console result)) _failed-trials)))))

(define-macro (test stx)
  `(test* equal? ,@(cdr stx)))

(define-macro (testq stx)
  `(test* eq? ,@(cdr stx)))

(define-macro (testv stx)
  `(test* eqv? ,@(cdr stx)))

(define-macro (test-console stx)
  `(printd ,@(cdr stx)))

;(define foo #t)

; ?? what to do about exceptions??
; <value> :: a value or !, ! indicating that the form throws an exception
; 
; example:
; (unit "math"
;   (let ([PI 3.14])
;     (test ('multiplication
;            ((* 1 2) 2 "identity")
;            ((* 2 1) 2 "commutativity")
;            ((* 3 (* 1 2)) (* (* 3 1) 2) "associativity"))
;           ('division
;            ((/ 1 0) ! "divide by zero")))))



   