(module digraph

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
      (hash-set! G.heads A #t))

    (when (null? (hash-ref G.succs B '()))
      (hash-set! G.tails B #t)))


  (define (digraph-topological-sort G)
    (let ([succ-count (hash G.hash-fn)])
      (for-each (lambda (e)
                  (hash-set! succ-count e (length (hash-ref G.succs e '()))))
                (hash-values G.elems))
      
      (let loop ([tails (hash-values G.tails)]
                 [result '()])
        (if (null? tails)
            (if (not (for-all zero? (hash-values succ-count)))
                (assert #f) ; cycle in graph
                result)
            (loop (append (cdr tails)
                          (filter true?
                                  (map (lambda (e)
                                         (let ([count (hash-ref succ-count e)])
                                           (hash-set! succ-count e (- count 1))
                                           (and (= 1 count) e)))
                                       (hash-ref G.preds (car tails) '()))))
                  (cons (car tails) result))))))
  
  "end module digraph")