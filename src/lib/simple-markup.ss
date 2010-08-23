(module simple-markup

  (export null-markup pretty-print)

  (define (null-markup cs)
    (apply string-append
           (map (lambda (s)
                  (if (equal? s '(newline))
                      "\n"
                      (if (list? s)
                          ""
                          s)))
                cs)))

  (define indent-size 2)

  (define (pretty-print cs)
    (apply string-append
           (let loop ([result '()]
                      [cs cs]
                      [line 0]
                      [column 0]
                      [indent 0]
                      [bases '((0))])
             (if (null? cs)
                 (reverse result)
                 (let ([e (car cs)])
                   (if (not (list? e))
                       (loop (cons e result) (cdr cs)
                             line (+ column (string-length e))
                             indent bases)
                       (case (car e)
                         [(indent)
                          (loop result (cdr cs)
                                line column
                                (+ indent indent-size) bases)]

                         [(newline)
                          (loop (cons (make-string (+ indent (caar bases)) " ")
                                      (cons "\n" result))
                                (cdr cs)
                                (+ 1 line) (+ indent (caar bases))
                                indent bases)]

                         [(outdent)
                          (loop result (cdr cs)
                                line column
                                (- indent indent-size) bases)]

                         [(pop-base)
                          (loop result (cdr cs)
                                line column
                                (cdar bases) (cdr bases))]

                         [(push-base)
                          (loop result (cdr cs)
                                line column
                                0 (cons (cons column indent) bases))]

                         [else
                          (assert #f (format "pretty-print-code-stream: unrecognized directive: %s" e))])))))))

  (module test
    (define-macro (trial stx)
      `(assert ,@(cdr stx) (format "%s failed" ',@(cdr stx))))

    (trial (string=? "simple"                  (pretty-print '("simple"))))
    (trial (string=? "\n"                      (pretty-print '((newline)))))
    (trial (string=? "simple\n"                (pretty-print '("simple" (newline)))))
    (trial (string=? "\nsimple"                (pretty-print '((newline) "simple"))))
    (trial (string=? "\n    "                  (pretty-print '((indent) (newline)))))
    (trial (string=? "\n"                      (pretty-print '((newline) (indent)))))
    (trial (string=? "\n    simple"            (pretty-print '((indent) (newline) "simple"))))
    (trial (string=? "\nsimple"                (pretty-print '((newline) (indent) "simple"))))
    (trial (string=? "\n    simple\n    stuff" (pretty-print '((indent) (newline) "simple"
                                                               (newline) "stuff"))))
    (trial (string=? "a(b,\n  c)\nfoo(bar)"    (pretty-print '("a(" (push-base) "b,"
                                                               (newline) "c)"
                                                               (pop-base)
                                                               (newline) "foo(bar)"))))

    (trial (string=? "{\n    one;\n    two;\n}"
                                               (pretty-print '("{" (indent) (newline)
                                                               "one;" (newline)
                                                               "two;" (outdent) (newline)
                                                               "}"))))

    (trial (string=? "{\n    foo(a,\n        b)\n    bar();\n}"
                                               (pretty-print '("{" (indent) (newline)
                                                               "foo(" (push-base) "a," (newline)
                                                               "b)" (pop-base) (newline)
                                                               "bar();" (outdent) (newline)
                                                               "}"))))
                                                               
    "End Module test")
                     
  "END Module code-stream")