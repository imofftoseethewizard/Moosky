(define (find proc lst)
  (if (null? lst)
      #f
      (if (proc (car lst))
          (car lst)
          (find proc (cdr lst)))))

(define (reduce combine zero . lsts)
  
(define (list-tail lst k)
  (if (not (positive? k))
      lst
      (list-tail (cdr lst) (- k 1))))

(define (list-ref lst k)
  (car (list-tail lst k)))
