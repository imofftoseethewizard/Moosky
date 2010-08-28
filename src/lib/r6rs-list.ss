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

(define (for-all P . Ls)
  (or (null? Ls)
      (if (null? (car Ls))
          ;; all Ls must be empty
          (let loop ([Ls (cdr Ls)])
            (or (null? Ls)
                (if (not (null? (car Ls)))
                    '&exception
                    (loop (cdr Ls)))))
          ;; all Ls must have at least one element
          (let loop ([Ls Ls]
                     [args '()]
                     [remainders '()])
            (if (null? Ls)
                (and (apply P (reverse args))
                     (apply for-all P (reverse remainders)))
                (let ([L (car Ls)])
                  (if (null? L)
                      ;; should be an exception
                      '&exception
                      (loop (cdr Ls)
                            (cons (car L) args)
                            (cons (cdr L) remainders)))))))))


(define (exists P . Ls)
  (not (apply for-all (lambda args
                        (not (apply P args))) Ls)))

(define (filter P L)
  (let-values ([(matches misses) (partition P L)])
    matches))

(define (partition P L)
  (let loop ([L L]
             [matches '()]
             [misses '()])
    (if (null? L)
        (values (reverse matches)
                (reverse misses))
        (let ([head (car L)])
          (if (P head)
              (loop (cdr L)
                    (cons head matches)
                    misses)
              (loop (cdr L)
                    matches
                    (cons head misses)))))))

(define (fold-left combine nil . Ls)
  (if (null? Ls)
      nil
      (if (null? (car Ls))
          ; all Ls must be empty
          (let loop ([Ls (cdr Ls)])
            (if (null? Ls)
                nil
                (if (not (null? (car Ls)))
                    '&exception1
                    (loop (cdr Ls)))))
          ; all Ls must have at least one element
          (let loop ([Ls Ls]
                     [args '()]
                     [remainders '()])
            (if (null? Ls)
                (apply fold-left combine (apply combine nil (reverse args))
                       (reverse remainders))
                (let ([L (car Ls)])
                  (if (null? L)
 ; should be an exception
                      '&exception2
                      (loop (cdr Ls)
                            (cons (car L) args)
                            (cons (cdr L) remainders)))))))))

(define (fold-right combine nil . Ls)
  (if (null? Ls)
      nil
      (if (null? (car Ls))
          ; all Ls must be empty
          (let loop ([Ls (cdr Ls)])
            (if (null? Ls)
                nil
                (if (not (null? (car Ls)))
                    '&exception3
                    (loop (cdr Ls)))))
          ; all Ls must have at least one element
          (let loop ([Ls Ls]
                     [args '()]
                     [remainders '()])
            (if (null? Ls)
                (apply combine (reverse (cons (apply fold-right combine nil (reverse remainders))
                                              args)))
                (let ([L (car Ls)])
                  (if (null? L)
                      ; should be an exception
                      '&exception
                      (loop (cdr Ls)
                            (cons (car L) args)
                            (cons (cdr L) remainders)))))))))


(define (remp P L)
  (let-values ([(matches misses) (partition P L)])
    misses))

(define (remove x L)
  (remp (lambda (a)
          (equal? a x))
        L))

(define (remv x L)
  (remp (lambda (a)
          (eqv? a x))
        L))

(define (remq x L)
  (remp (lambda (a)
          (eq? a x))
        L))

(define (memp P L)
  (if (null? L)
      #f
      (if (P (car L))
          L
          (memp P (cdr L)))))

(define (member
         x L)
  (memp (lambda (a)
          (equal? a x))
        L))

(define (memv x L)
  (memp (lambda (a)
          (eqv? a x))
        L))

(define (memq x L)
  (memp (lambda (a)
          (eq? a x))
        L))

(define (assp P L)
  (find (lambda (pair)
          (P (car pair)))
        L))

(define (assoc x L)
  (assp (lambda (a)
          (equal? a x))
        L))

(define (assv x L)
  (assp (lambda (a)
          (eqv? a x))
        L))

(define (assq x L)
  (assp (lambda (a)
          (eq? a x))
        L))

(define (find P L)
  (let ([tail (memp P L)])
    (and tail (car tail))))

(define (cons* . xs)
  (fold-right (lambda (L nil)
                      (if (null? nil)
                          L
                          (cons L nil)))
              '() xs))

(define (mapcdr P . Ls)
  (if (null? Ls)
      '()
      (if (null? (car Ls))
          ;; all Ls must be empty
          (let loop ([Ls (cdr Ls)])
            (if (null? Ls)
                '()
                (if (not (null? (car Ls)))
                    '&exception1
                    (loop (cdr Ls)))))
          ;; all Ls must have at least one element
          (let loop ([Ls Ls]
                     [result '()])
            (if (null? (car Ls))
                (let check-loop ([Ls (cdr Ls)])
                  (if (null? Ls)
                      (reverse result)
                      (if (not (null? (car Ls)))
                          '&exception2
                          (check-loop (cdr Ls)))))
                (loop (map cdr Ls)
                      (cons (apply P Ls) result)))))))

