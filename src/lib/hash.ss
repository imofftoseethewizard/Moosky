(module hash
  
  (export *)
  
  (define (hash hash-fn)
    (object hash: hash-fn
            elements: (object)))

  (define (hash-ref H x default)
    (let ([y (object-ref H.elements (H.hash x))])
      (if (defined? y)
          y
          default)))

  (define (hash-set! H x v)
    (object-set! H.elements (H.hash x) v))

  (define (hash-remove! H x)
    (object-remove! H.elements (H.hash x)))
  
  (define (hash-values H)
    #{
      (function () {
        var sexp = $nil;
        for (var p in @^(H.elements))
          sexp = cons(@^(H.elements)[p], sexp);
       
        return sexp;
      })()
    }#)


  (define (hash-length H)
    (length (hash-values H)))
  
  (module test

    (define-macro (trial stx)
      `(assert ,@(cdr stx) (format "%s failed" ',@(cdr stx))))

    (define-macro (fail stx)
      `(assert (eq? 'exception (except (lambda (e) 'exception)
                                 ,@(cdr stx)))
               (format "%s failed" ',@(cdr stx))))

    (define H (hash (lambda (x) (car x))))
    
    (trial (zero? (hash-length H)))

    (hash-set! H '(foo) 'bar)
    (trial (= 1 (hash-length H)))
    (trial (equal? '(bar) (hash-values H)))
    (trial (equal? 'bar (hash-ref H '(foo) #f)))
    (trial (equal? 'bar (hash-ref H '(foo bar) #f)))
    (trial (equal? 'nope (hash-ref H '(bar) 'nope)))

    (hash-set! H '(foo bar) 'baz)
    (trial (= 1 (hash-length H)))
    (trial (equal? '(baz) (hash-values H)))
    (trial (equal? 'baz (hash-ref H '(foo) #f)))
    (trial (equal? 'baz (hash-ref H '(foo bar) #f)))
    (trial (equal? 'nope (hash-ref H '(bar) 'nope)))

    (hash-set! H '(bar soap) 'ivory)
    (trial (= 2 (hash-length H)))
    (trial (and (member 'baz (hash-values H))
                (member 'ivory (hash-values H))))
    (trial (equal? 'ivory (hash-ref H '(bar) #t)))

    (hash-remove! H '(foo))
    (trial (= 1 (hash-length H)))
    (trial (equal? '(ivory) (hash-values H)))

    
    "end module test")


  "end module hash")

