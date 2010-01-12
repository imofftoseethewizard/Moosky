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


(define (find proc lst)
  (if (null? lst)
      #f
      (if (proc (car lst))
          (car lst)
          (find proc (cdr lst)))))

(define (for-all proc . lists)
  (or (null? lists)
      (if (null? (car lists))
          ; all lists must be empty
          (let loop ([lists (cdr lists)])
            (or (null? lists)
                (if (not (null? (car lists)))
                    '&exception
                    (loop (cdr lists)))))
          ; all lists must have at least one element
          (let loop ([lists lists]
                     [args '()]
                     [remainders '()])
            (if (null? lists)
                (and (apply proc args)
                     (apply for-all proc remainders))
                (let ([lst (car lists)])
                  (if (null? lst)
                      ; should be an exception
                      '&exception
                      (loop (cdr lists)
                            (cons (car lst) args)
                            (cons (cdr lst) remainders)))))))))

(define (exists proc . lists)
  (not (apply for-all (lambda args
                        (not (apply proc args))) lists)))

(define (filter proc lst)
  (let-values ([(matches misses) (partition proc lst)])
    matches))

(define (partition proc lst)
  (let loop ([lst lst]
             [matches '()]
             [misses '()])
    (if (null? lst)
        (values (reverse matches)
                (reverse misses))
        (let ([head (car lst)])
          (if (proc head)
              (loop (cdr lst)
                    (cons head matches)
                    misses)
              (loop (cdr lst)
                    matches
                    (cons head misses)))))))



(define (fold-left combine nil . lists) 'not-implemented)
(define (fold-right combine nil . lists) 'not-implemented)

(define (remp proc  lst) 'not-implemented)
(define (remove obj lst) 'not-implemented)
(define (remv obj lst) 'not-implemented)
(define (remq obj lst) 'not-implemented)

(define (memp proc  lst) 'not-implemented)
(define (member obj lst) 'not-implemented)
(define (memv obj lst) 'not-implemented)
(define (memq obj lst) 'not-implemented)

(define (assp proc  lst) 'not-implemented)
(define (assoc obj lst) 'not-implemented)
(define (assv obj lst) 'not-implemented)
(define (assq obj lst) 'not-implemented)

(define (cons* . objs) 'not-implemented)

;(define (reduce combine zero . lists) 'not-implemented)
;
;(define (list-tail lst k)
;  (if (not (positive? k))
;      lst
;      (list-tail (cdr lst) (- k 1))))
;
;(define (list-ref lst k)
;  (car (list-tail lst k)))
