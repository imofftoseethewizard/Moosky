(define (make-counter)
  (let ([counter -1])
    (lambda ()
      (set! counter (+ counter 1))
      counter)))

(define (make-countdown N action)
  (let ([counter (make-counter)])
    (lambda ()
      (let ([i (- N (counter))])
        (and (zero? i)
             action (action))
        i))))


(define (reverse-tuple N T)
  (if (= N 1)
      T
      (cons (reverse-tuple (- N 1) (cdr T)) (car T))))


(define (group-by N type L)
  (let-values ([(reverse-group begin-group)
                (if (eq? type 'lists)
                    (values reverse list)
                    (values (lambda (T) (reverse-tuple N T))
                            (lambda (x) x)))])
      (reverse 
       (map reverse-group
            (fold-left (let ([count (make-counter)])
                         (lambda (groups next)
                           (if (zero? (modulo (count) N))
                               (cons (begin-group next) groups)
                               (cons (cons next (car groups)) (cdr groups)))))
                         '()
                         L)))))

(define (pairs L)
  (group-by 2 'tuples L))


(define (join comma L)
  (if (null? L)
      L
      (reverse
       (fold-left (lambda (result next)
                    (cons next (cons comma result)))
                  (list (car L))
                  (cdr L)))))

(define (splice-join comma L)
  (if (null? L)
      L
      (reverse
       (fold-left (lambda (result next)
                    (cons next (let loop ([comma comma]
                                          [result result])
                                 (if (null? comma)
                                     result
                                     (loop (cdr comma) (cons (car comma) result))))))
                  (list (car L))
                  (cdr L)))))

(define (string-join comma L)
  (apply string-append (join comma L)))

(define (string-split s d l)
  (vector->list (s.split (if (undefined? d) " " d) l)))

(define (string-search s r)
  (s.search r))

(define (string-slice s F L)
  (s.slice F L))

(define-macro (object stx)
  `(javascript ,(js-quote "{")
               ,@(apply append
                        (join (list (js-quote ", "))
                              (map (lambda (T)
                                     (list (js-quote (format "'%s':" (symbol->string (car T))))
                                           (cdr T)))
                                   (group-by 2 tuples: (cdr stx)))))
               ,(js-quote "}")))

(define (object? x)
  { typeof(x) == "object" })

(define (function? x)
  { typeof(x) == "function" })
                        
(define (make-object L)
  (let ([obj (Object)])
    (for-each (lambda (pair)
                (let ([k (car pair)]
                      [v (cdr pair)])
                  { @^(obj)[Moosky.Values.Symbol.munge(''+@^(k))] = @^(v) }))
              (if (or (null? L)
                      (list? (car L)))
                  L
                  (pairs L)))
    obj))


(define (extend-object! obj . props)
  (let loop ([props props])
    (and (not (null? props)) (not (null? (cdr props)))
         (begin
           (object-set! obj (car props) (cadr props))
           (loop (cddr props)))))
  obj)


(define (object-property-name k)
  (cond [(string? k) k]
        [(symbol? k) (symbol->string k)]
        [#t (and (assert k.toString (format "object-property-name: cannot convert to name: %s" k))
                 (k.toString))]))

(define (object-ref obj k)
  { obj[@^(k)] })

(define (object-set! obj k v)
  { obj[@^(k)] = @^(v) })

(define (object-properties-list obj)
#{
 (function () {
   var sexp = $nil;
   for (var p in @^(obj)) {
     if (@^(obj).hasOwnProperty(p))
       sexp = cons($symbol(p), sexp);
   }
   return sexp;
 })()
}#)

(define (object->alist obj)
#{
 (function () {
   var sexp = $nil;
   for (var p in @^(obj))
     sexp = cons(cons($symbol(p), @^(obj)[p]), sexp);

   return sexp;
  })()
}#)

(define (object-copy obj)
  (make-object (object->alist obj)))

(define (delete-property! obj prop)
  (object-set! obj prop #u))

(define (string-find s t)
  (let ([index (s.indexOf t)])
    (and (not (= -1 t))
         t)))

(define (simple-symbol? sym)
  (string-find (symbol->string sym) "."))


;;--------------------------------------------------------------------------
;;
;; (rectify x)
;;
;; x is any value.
;;
;; rectify returns a proper list and the final cdr of its argument.
;;
;; If x not a list, simply a value, then rectify returns (values '() x).
;;
;; If x is a proper list, then rectify returns (values x '()).
;;
;; If x is an improper list, then rectify returns a the proper list formed
;; by the cars of x, and the final cdr of x.  E.g
;;
;;   (rectify (cons 'foo 'bar)) --> (values '(foo) 'bar)
;;
;; This is a utility used in processing dotted argument lists, e.g
;;
;;   (let-values ([(formals rest) (rectify parameters)])
;;     ...)
;;

(define (rectify x)
  (let loop ([x x]
             [result '()])
    (cond [(null? x)
           (values (reverse result) '())]

          [(list? x)
           (loop (cdr x) (cons (car x) result))]

          [#t
           (values (reverse result) x)])))

(define (proper-list? x)
  (and (list? x)
       (or (null? x)
           (proper-list? (cdr x)))))


(define (assoc-ref obj lst)
  (let ([r (assoc obj lst)])
    (and r (cdr r))))

(define (take n L)
  (if (zero? n)
      '()
      (cons (car L) (take (- n 1) (cdr L)))))

(define (drop n L)
  (if (zero? n)
      L
      (drop (- n 1) (cdr L))))

(define (take-right n L)
  (reverse (take n (reverse L))))

(define (drop-right n L)
  (reverse (drop n (reverse L))))

(define (last L)
  (car (take-right 1 L)))