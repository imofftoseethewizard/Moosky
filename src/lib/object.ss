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
                        
(define (make-object L)
;  (console.log (format "make-object-- %s" L) L)
  (let ([obj (Object)])
    (for-each (lambda (pair)
;                (console.log (format "-- pair: %s" pair) pair)
                (let ([k (car pair)]
                      [v (cdr pair)])
;                  (console.log k v)
                  { @^(obj)[Moosky.Values.Symbol.munge(''+@^(k))] = @^(v) }))
              (if (or (null? L)
                      (list? (car L)))
                  L
                  (pairs L)))
    obj))

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
   for (var p in @^(obj))
     sexp = cons(stringToSymbol(p), sexp);

   return sexp;
 })()
}#)

(define (object->alist obj)
#{
 (function () {
   var sexp = $nil;
   for (var p in @^(obj))
     sexp = cons(cons(stringToSymbol(p), @^(obj)[p]), sexp);

   return sexp;
 })()
}#)

