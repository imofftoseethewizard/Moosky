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

{ (window.__counter = 0) }
(define (for-all proc . lists)
  (or (null? lists)
      (if (null? (car lists))
          ;; all lists must be empty
          (let loop ([lists (cdr lists)])
            (or (null? lists)
                (if (not (null? (car lists)))
                    '&exception
                    (loop (cdr lists)))))
          ;; all lists must have at least one element
          (let loop ([lists lists]
                     [args '()]
                     [remainders '()])
            (if (null? lists)
                (and (apply proc (reverse args))
                     (apply for-all proc (reverse remainders)))
                (let ([lst (car lists)])
                  (if (null? lst)
                      ;; should be an exception
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

(define (fold-left combine nil . lists)
  (if (null? lists)
      nil
      (if (null? (car lists))
          ; all lists must be empty
          (let loop ([lists (cdr lists)])
            (if (null? lists)
                nil
                (if (not (null? (car lists)))
                    '&exception1
                    (loop (cdr lists)))))
          ; all lists must have at least one element
          (let loop ([lists lists]
                     [args '()]
                     [remainders '()])
            (if (null? lists)
                (apply fold-left combine (apply combine nil (reverse args))
                       (reverse remainders))
                (let ([lst (car lists)])
                  (if (null? lst)
                      ; should be an exception
                      '&exception2
                      (loop (cdr lists)
                            (cons (car lst) args)
                            (cons (cdr lst) remainders)))))))))

(define (fold-right combine nil . lists)
  (if (null? lists)
      nil
      (if (null? (car lists))
          ; all lists must be empty
          (let loop ([lists (cdr lists)])
            (if (null? lists)
                nil
                (if (not (null? (car lists)))
                    '&exception3
                    (loop (cdr lists)))))
          ; all lists must have at least one element
          (let loop ([lists lists]
                     [args '()]
                     [remainders '()])
            (if (null? lists)
                (apply combine (reverse (cons (apply fold-right combine nil (reverse remainders))
                                              args)))
                (let ([lst (car lists)])
                  (if (null? lst)
                      ; should be an exception
                      '&exception
                      (loop (cdr lists)
                            (cons (car lst) args)
                            (cons (cdr lst) remainders)))))))))


(define (remp proc lst)
  (let-values ([(matches misses) (partition proc lst)])
    misses))

(define (remove obj lst)
  (remp (lambda (a)
          (equal? a obj))
        lst))

(define (remv obj lst)
  (remp (lambda (a)
          (eqv? a obj))
        lst))

(define (remq obj lst)
  (remp (lambda (a)
          (eq? a obj))
        lst))

(define (memp proc lst)
  (if (null? lst)
      #f
      (if (proc (car lst))
          lst
          (memp proc (cdr lst)))))

(define (member
         obj lst)
  (memp (lambda (a)
          (equal? a obj))
        lst))

(define (memv obj lst)
  (memp (lambda (a)
          (eqv? a obj))
        lst))

(define (memq obj lst)
  (memp (lambda (a)
          (eq? a obj))
        lst))

(define (assp proc lst)
  (find (lambda (pair)
          (proc (car pair)))
        lst))

(define (assoc obj lst)
  (assp (lambda (a)
          (equal? a obj))
        lst))

(define (assv obj lst)
  (assp (lambda (a)
          (eqv? a obj))
        lst))

(define (assq obj lst)
  (assp (lambda (a)
          (eq? a obj))
        lst))

(define (find proc lst)
  (let ([tail (memp proc lst)])
    (and tail (car tail))))

(define (cons* . objs)
  (fold-right (lambda (lst nil)
                      (if (null? nil)
                          lst
                          (cons lst nil)))
              '() objs))

