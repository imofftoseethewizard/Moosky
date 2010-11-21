(module digraph

  (import * from hash)
  (export *)

  (define (DirectedGraph hash-fn)
    (object hash-fn: hash-fn
            elems: (hash hash-fn)
            heads: (hash hash-fn)
            tails: (hash hash-fn)
            succs: (hash hash-fn)
            preds: (hash hash-fn)))


  (define (digraph-add-edge G A B)
    (hash-set! G.elems A A)
    (hash-set! G.elems B B)
    
    (hash-set! G.succs A (cons B (hash-ref G.succs A '())))
    (hash-set! G.preds B (cons A (hash-ref G.preds B '())))

    (hash-remove! G.tails A)
    (hash-remove! G.heads B)

    (when (null? (hash-ref G.preds A '()))
      (hash-set! G.heads A A))

    (when (null? (hash-ref G.succs B '()))
      (hash-set! G.tails B B)))


  (define (digraph-topological-sort G)
    (let ([succ-count (hash G.hash-fn)])
      (for-each (lambda (e)
                  (hash-set! succ-count e (length (hash-ref G.succs e '()))))
                (hash-values G.elems))
      
      (let loop ([tails (hash-values G.tails)]
                 [result '()])
        (if (null? tails)
            (if (not (for-all zero? (hash-values succ-count)))
                (assert #f "cycle detected in digraph during topological sort.")
                result)
            (loop (append (cdr tails)
                          (filter identity
                                  (map (lambda (e)
                                         (let ([count (hash-ref succ-count e)])
                                           (hash-set! succ-count e (- count 1))
                                           (and (= 1 count) e)))
                                       (hash-ref G.preds (car tails) '()))))
                  (cons (car tails) result))))))

  
  (module test

    (define-macro (trial stx)
      `(assert ,@(cdr stx) (format "%s failed" ',@(cdr stx))))

    (define-macro (fail stx)
      `(assert (eq? 'exception (except (lambda (e) 'exception)
                                 ,@(cdr stx)))
               (format "%s failed" ',@(cdr stx))))


    (define G (DirectedGraph (lambda (x) x)))

    (trial (equal? '() (digraph-topological-sort G)))

    (digraph-add-edge G 0 1)

    (trial (equal? '(0 1) (digraph-topological-sort G)))

    (digraph-add-edge G 0 2)
    
    (let ([result (digraph-topological-sort G)])
      (trial (member 1 (member 0 result)))
      (trial (member 2 (member 0 result))))

    (digraph-add-edge G 1 3)
    
    (let ([result (digraph-topological-sort G)])
      (trial (member 3 (member 1 (member 0 result))))
      (trial (member 2 (member 0 result))))

    (digraph-add-edge G 2 3)
    
    (let ([result (digraph-topological-sort G)])
      (trial (member 3 (member 1 (member 0 result))))
      (trial (member 3 (member 2 (member 0 result)))))

    (digraph-add-edge G 3 1)
    (fail (digraph-topological-sort G))
    
    "end module test")

  
  "end module digraph")