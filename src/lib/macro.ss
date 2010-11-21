(module macro

  (export *)

  ;; module-eval

  (define (compile2 stx . options)
    (let* ([fmt (get-keyword-option options format: 'null)]
           [formatter (if (eq? fmt 'null)
                          simple-markup.null-markup
                          simple-markup.pretty-print)])
      (formatter (javascript.ast->markup
                  (primitive-syntax.internal->target stx)))))
  
  
  (define-macro (module-eval2 stx)
    `(JS (CALL
          (FUNCTION (IDENTIFIER moduleEval) ()
                    (STATEMENT
                     (WITH ,(object-ref (cadr stx) "$namespace")
                           (RETURN (CALL (LITERAL eval)
                                         ((compile2 ,(caddr stx) format: pretty-print)))))))
          () )))

  (define (module-eval m stx)
    #{ (function () {
                     with (@^(m)) {
                                   return eval(@(compile2 (caddr stx) format: pretty-print));
                                          } })() }#)
  



  "End Module macro")