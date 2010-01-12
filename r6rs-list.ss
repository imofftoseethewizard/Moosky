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
  (console.log lists)
  (or (null? lists)
      (if (null? (car lists))
          ; all lists must be empty
          (let loop ([lists (cdr lists)])
            (console.log 'null)
            (or (null? lists)
                (if (not (null? (car lists)))
                    '&exception
                    (loop (cdr lists)))))
          ; all lists must have at least one element
          (let loop ([lists lists]
                     [args '()]
                     [remainders '()])
            (console.log 'check)
            (if (null? lists)
                (and (begin
                       (console.log 'applying-args)
                       (apply proc args))
                     (begin
                       (console.log 'recurring
                       (apply for-all proc remainders))))
                (let ([lst (car lists)])
                  (if (null? lst)
                      ; should be an exception
                      '&exception
                      (loop (cdr lists)
                            (cons (car lst) args)
                            (cons (cdr lst) remainders)))))))))

(define (exists proc . lists)
  (not (apply for-all (lambda args
                        (console.log args)
                        (not (apply proc args))) lists)))
;;
;;  (and (not (null? lists))
;;       (if (null? (car lists))
;;           ;; all lists must be empty
;;           (let loop ([lists (cdr lists)])
;;             (and (not (null? lists))
;;                  (if (not (null? (car lists)))
;;                      '&exception
;;                      (loop (cdr lists)))))
;;           ;; all lists must have at least one element
;;           (let loop ([lists lists]
;;                      [args '()]
;;                      [remainders '()])
;;             (if (null? lists)
;;                 (or (apply proc args)
;;                     (apply for-all proc remainders))
;;                 (let ([lst (car lists)])
;;                   (if (null? lst)
;;                       '&exception
;;                       (loop (cdr lists)
;;                             (cons (car lst) args)
;;                             (cons (cdr lst) remainders)))))))))

(define (filter proc lst)
  (let loop ([lst lst]
             [result '()])
    (if (null? lst)
        (reverse result)
        (let ([head (car lst)])
          (loop (cdr lst)
                (if (proc head)
                    (cons head result)
                    result))))))

;;; TODO: implement values
(define (partition proc ls) 'not-implemented)


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
