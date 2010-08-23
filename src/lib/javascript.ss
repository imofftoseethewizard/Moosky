(module javascript

  (export *)


  (define (ast->markup sexp)
    (printf "ast->markup: %s\n" sexp)
    (let ([result
    (if (not (pair? sexp))
        sexp
        (let ([applicand (car sexp)])
          (cond [(symbol? applicand)
                 (let ([emitter (assoc-ref applicand emitters)])
                   (assert emitter (format "ast->markup: tag %s has no emitter"))
                   (apply emitter (map ast->markup (cdr sexp))))]

                [(list? applicand)
                 (map ast->markup sexp)]

                [#t (assert #f (format "ast->markup: unable to interpret %s" sexp))])))])
      (printf "-->%s\n" result)
      result))
              

  (define (regexp-match s regexp)
    (regexp.exec s))

  (define (identifier? s)
    (not (eq? #n (regexp-match s #/^[\w$]*$/))))

  (define (make-identifier s)
    (apply string-append
           (map (lambda (c)
                  (if (eq? #n (regexp-match c #/[\w]/))
                      (format "$%s" (c.charCodeAt 0))
                      c))
                (string->list (if (string? s)
                                  s
                                  (symbol->string s))))))
  
  (define operator-precedence
    '((MEMBER-EXP . 1)                   ; []
      (MEMBER-LIT . 1)                   ; .
      (NEW . 1)                          ; new
      (CALL . 2)                         ; ( )
      (POSTFIX-INC . 3)                  ; ++
      (POSTFIX-DEC . 3)                  ; --
      (DELETE . 4)                       ; delete
      (VOID . 4)                         ; void
      (TYPEOF . 4)                       ; typeof
      (PREFIX-INC . 4)                   ; ++
      (PREFIX-DEC . 4)                   ; --
      (UNARY-PLUS . 4)                   ; +
      (UNARY-MINUS . 4)                  ; -
      (BITWISE-NOT . 4)                  ; ~
      (LOGICAL-NOT . 4)                  ; !
      (MULT . 5)                         ; *
      (DIV . 5)                          ; /
      (REM . 5)                          ; %
      (PLUS . 6)                         ; +
      (MINUS . 6)                        ; -
      (BITWISE-LEFT-SHIFT . 7)           ; <<
      (SIGNED-RIGHT-SHIFT . 7)           ; >>
      (UNSIGNED-RIGHT-SHIFT . 7)         ; >>>
      (LT . 8)                           ; <
      (GT . 8)                           ; >
      (LTE . 8)                          ; <=
      (GTE . 8)                          ; >=
      (INSTANCEOF . 8)                   ; instanceof
      (IN . 8)                           ; in
      (EQUAL . 9)                        ; ==
      (NOT-EQUAL . 9)                    ; !=
      (STRICTLY-EQUAL . 9)               ; ===
      (NOT-STRICTLY-EQUAL . 9)           ; !==
      (BITWISE-AND . 10)                 ; &
      (BITWISE-XOR . 11)                 ; ^
      (BITWISE-OR . 12)                  ; |
      (LOGICAL-AND . 13)                 ; &&
      (LOGICAL-OR . 14)                  ; ||
      (CONDITIONAL . 15)                 ; ? :
      (ASSIGN . 16)                      ; =
      (MULT-ASSIGN . 16)                 ; *=
      (DIV-ASSIGN . 16)                  ; /=
      (REM-ASSIGN . 16)                  ; %=
      (PLUS-ASSIGN . 16)                 ; +=
      (MINUS-ASSIGN . 16)                ; -=
      (BITWISE-LEFT-SHIFT-ASSIGN . 16)   ; <<=
      (SIGNED-RIGHT-SHIFT-ASSIGN . 16)   ; >>=
      (UNSIGNED-RIGHT-SHIFT-ASSIGN . 16) ; >>>=    
      (BITWISE-AND-ASSIGN . 16)          ; &=
      (BITWISE-OR-ASSIGN . 16)           ; |=
      (BITWISE-XOR-ASSIGN . 16)          ; ^=
      (SEQUENCE . 17)))                  ; ,

  (define (precedence-bracket outer-tag inner)
    (let ([prec-outer (assoc outer-tag operator-precedence)]
          [prec-inner (assoc (car inner) operator-precedence)])
      (if (and prec-outer prec-inner
               (<= prec-outer prec-inner))
          `(PAREN ,inner)
          inner)))


  
  ;;;==========================================================================
  ;;;
  ;;; Utilities for Emitters
  ;;;

  (define (arglist args)
    `("(" ,@(sequence args) ")"))
  
  (define (sequence exps)
    `((push-base)
      ,@(apply append (join '(", " (newline)) exps))
      (pop-base)))
  
  (define (statements stmts)
    (if (default stmts #f)
        `((indent) (newline)
          ,@(splice-join '((newline)) stmts)
          (outdent) (newline))
        '()))


  
  ;;;==========================================================================
  ;;;
  ;;; Emitters for Punctuation and Literals
  ;;;

  (define (BLOCK stmts)
    `("{" (indent) (newline)
      ,@(apply append (join '((newline)) stmts)) (outdent) (newline)
      "}"))

  (define (IDENTIFIER id)
    (list (if (symbol? id)
              (symbol->string id)
              id)))
  
  (define (LITERAL exp)
    (cond [(number? exp)
           (list (format "%s" exp))]
          
          [(string? exp)
           `("\"" ,(quote-string exp) "\"")]
          
          [(symbol? exp)
           (CALL (IDENTIFIER "$S") (list (LITERAL (symbol->string exp))))]

          [(vector? exp)
           (assert #f (format "TODO: literal vector" exp))]

          [(list? exp)
           (assert #f (format "TODO: literal list" exp))]

          [(object? exp)
           (assert #f (format "TODO: literal object" exp))]

          [(function? exp)
           (assert #f (format "TODO: literal function" exp))]

          [(eq? #u exp)
           '("undefined")]

          [(eq? #n exp)
           '("null")]

          [(eq? #t exp)
           '("true")]
          
          [(eq? #f exp)
           '("false")]

          [(regexp? exp)
           (javascript-regexp exp)]

          [#t
           (assert #f (format "Unknown literal type: %s" exp))]))

  (define (PAREN exp)
    `("(" ,@exp ")"))

  (define (STATEMENT stmt)
    `(,@stmt ";"))


  
  ;;;==========================================================================
  ;;;
  ;;; Emitters for Expressions
  ;;;

  (define (ASSIGN left right)
    `(,@left " = " ,@right))
  
  (define (BITWISE-AND . exps)
    (splice-join '(" & ") exps))

  (define (BITWISE-AND-ASSIGN left right)
    `(,@left " &= " ,@right))
  
  (define (BITWISE-LEFT-SHIFT exp n)
    `(,@exp "<<" ,@n))

  (define (BITWISE-LEFT-SHIFT-ASSIGN left right)
    `(,@left " <<= " ,@right))
  
  (define (BITWISE-OR . exps)
    (splice-join '(" | ") exps))

  (define (BITWISE-OR-ASSIGN left right)
    `(,@left " |= " ,@right))
  
  (define (BITWISE-XOR . exps)
    (splice-join '(" ^ ") exps))

  (define (BITWISE-XOR-ASSIGN left right)
    `(,@left " ^= " ,@right))
  
  (define (CALL exp args)
    `(,@exp ,@(arglist args)))

  (define (CONDITIONAL cond csq alt)
    `((push-base)
      ,@cond (indent) (newline)
      " ? " ,@csq (newline)
      " : " ,@alt
      (pop-base)))

  (define (DELETE exp)
    `("delete " ,@exp))

  (define (DIV . exps)
    (splice-join '("/") exps))
  
  (define (DIV-ASSIGN left right)
    `(,@left " /= " ,@right))

  (define (EQUAL left right)
    `(,@left " == " ,@right))

  (define (GT left right)
    `(,@left " > " ,@right))

  (define (GTE left right)
    `(,@left " >= " ,@right))

  (define (STRICTLY-EQUAL left right)
    `(,@left " === " ,@right))

  (define (INSTANCEOF obj-exp cls-exp)
    `(,@obj-exp "instanceof " ,@cls-exp))

  (define (IN id obj)
    `(,@id " in " ,@obj))

  (define (LOGICAL-AND . exps)
    (splice-join '(" && ") exps))

  (define (LOGICAL-NOT exp)
    `("!" ,@exp))

  (define (LOGICAL-OR . exps)
    (splice-join '(" || ") exps))

  (define (LT left right)
    `(,@left " < " ,@right))

  (define (LTE left right)
    `(,@left " <= " ,@right))

  (define (MEMBER-LIT obj p)
    `(,@obj "." ,@p))

  (define (MEMBER-EXP obj exp)
    `(,@obj "[" ,@exp "]"))

  (define (MINUS . exps)
    (splice-join '("-") exps))

  (define (MULT . exps)
    (splice-join '("*") exps))

  (define (MULT-ASSIGN left right)
    `(,@left " *= " ,@right))
  
  (define (NEW exp args)
    `("new " ,@exp ,@(arglist args)))

  (define (NOT-EQUAL left right)
    `(,@left " != " ,@right))

  (define (NOT-STRICTLY-EQUAL left right)
    `(,@left " !== " ,@right))

  (define (PLUS . exps)
    (splice-join '("+") exps))

  (define (PLUS-ASSIGN left right)
    `(,@left " += " ,@right))
  
  (define (MINUS-ASSIGN left right)
    `(,@left " -= " ,@right))
  
  (define (POSTFIX-DEC exp)
    `(,@exp "--"))

  (define (POSTFIX-INC exp)
    `(,@exp "++"))

  (define (PREFIX-DEC exp)
    `("--" ,@exp))

  (define (PREFIX-INC exp)
    `("++" ,@exp))

  (define (REM . exps)
    (splice-join '("%") exps))

  (define (REM-ASSIGN left right)
    `(,@left " %= " ,@right))

  (define (SEQUENCE . exps)
    (sequence exps))
  
  (define (SIGNED-RIGHT-SHIFT exp n)
    `(,@exp ">>" ,@n))

  (define (SIGNED-RIGHT-SHIFT-ASSIGN left right)
    `(,@left " >>= " ,@right))
  
  (define (TYPEOF exp)
    `("typeof " ,@exp))

  (define (UNARY-MINUS exp)
    `("-" ,@exp))

  (define (UNARY-PLUS exp)
    `("+" ,@exp))

  (define (UNSIGNED-RIGHT-SHIFT exp n)
    `(,@exp ">>>" ,@n))

  (define (UNSIGNED-RIGHT-SHIFT-ASSIGN left right)
    `(,@left " >>>= " ,@right))
  
  (define (VOID)
    '("void"))


  ;;;==========================================================================
  ;;;
  ;;; Emitters for Statements
  ;;;

  (define (BREAK identifier)
    `("break " ,@(if (default identifier #f)
                     (list identifier)
                     '())))

  (define (CASE exp stmts)
    `("case " ,@exp ":" (statements stmts)))

  (define (CONTINUE identifier)
    `("continue " ,@(if (default identifier #f)
                        (list identifier)
                        '())))

  (define (DEFAULT stmts)
    `("default: " ,@(statements stmts)))

  (define (DO-WHILE stmt exp)
    `((push-base) "do " ,@stmt (newline)
      "while (" ,@exp ")"
      (pop-base)))

  (define (FOR exp-init exp-test exp-step stmt)
    `("for (" ,@exp-init "; " ,@exp-test "; " ,@exp-step ") " ,@stmt))

  (define (FOR-IN identifier obj stmt)
    `("for (" ,@identifier " in " ,@obj ") " ,@stmt))

  (define (FOR-VAR exp-init exp-test exp-step stmt)
    `("for (var " ,@exp-init "; " ,@exp-test "; " ,@exp-step ") " ,@stmt))

  (define (FOR-VAR-IN identifier obj stmt)
    `("for (var " ,@identifier " in " ,@obj ") " ,@stmt))

  (define (FUNCTION identifier formals body)
    `((push-base) "function " ,@(if (default identifier #f)
                        identifier
                        '())
      ,@(arglist formals) " "
      ,@(BLOCK body)
      (pop-base)))

  (define (IF cond csq alt)
    `((push-base) "if (" ,@cond ")" ,@csq
      ,@(if alt
            `((newline) "else " ,@alt)
            '())
      (pop-base)))

  (define (LABEL identifier stmt)
    `(,@identifier ": " ,@stmt))

  (define (RETURN exp)
    `("return " ,@(if (default exp #f)
                      exp
                      '())))

  (define (SWITCH exp case-exps)
    `((push-base) "switch (" ,@exp ") {" (indent) (newline)
      ,@(splice-join '((newline)) case-exps)
      (outdent) (newline) "}"
      (pop-base)))

  (define (THROW exp)
    `("throw " ,@exp))

  (define (TRY-CATCH try-block identifier catch-block)
    `((push-base) "try " ,@try-block
      " catch " ,(if (default identifier #f)
                     `("(" ,@identifier ")")
                     '())
      ,@catch-block))
  
  (define (TRY-CATCH-FINALLY try-block identifier catch-block final-block)
    `((push-base) "try " ,@try-block
      " catch " ,(if (default identifier #f)
                     `("(" ,@identifier ")")
                     '())
      ,@catch-block
      " finally " ,@final-block))
  
  (define (TRY-FINALLY try-block final-block)
    `((push-base) "try " ,@try-block
      " finally " ,@final-block))
  
  (define (VAR decls)
    `("var " (push-base)
      ,@(apply append (join '(", " (newline))
                            (map (lambda (decl)
                                   (if (= 1 (length decl))
                                       decl
                                       `(,@(car decl) " = " ,@(cadr decl))))
                                 decls)))
      (pop-base)))

  (define (WHILE exp stmt)
    `("while (" ,@exp ") " ,@stmt))

  (define (WITH exp stmt)
    `("with (" ,@exp ") " ,@stmt))

  (define emitters
    `((BLOCK . ,BLOCK)
      (IDENTIFIER . ,IDENTIFIER)
      (LITERAL . ,LITERAL)
      (PAREN . ,PAREN)
      (STATEMENT . ,STATEMENT)
      (ASSIGN . ,ASSIGN)
      (BITWISE-AND . ,BITWISE-AND)
      (BITWISE-AND-ASSIGN . ,BITWISE-AND-ASSIGN)
      (BITWISE-LEFT-SHIFT . ,BITWISE-LEFT-SHIFT)
      (BITWISE-LEFT-SHIFT-ASSIGN . ,BITWISE-LEFT-SHIFT-ASSIGN)
      (BITWISE-OR . ,BITWISE-OR)
      (BITWISE-OR-ASSIGN . ,BITWISE-OR-ASSIGN)
      (BITWISE-XOR . ,BITWISE-XOR)
      (BITWISE-XOR-ASSIGN . ,BITWISE-XOR-ASSIGN)
      (CALL . ,CALL)
      (CONDITIONAL . ,CONDITIONAL)
      (DELETE . ,DELETE)
      (DIV . ,DIV)
      (DIV-ASSIGN . ,DIV-ASSIGN)
      (EQUAL . ,EQUAL)
      (GT . ,GT)
      (GTE . ,GTE)
      (STRICTLY-EQUAL . ,STRICTLY-EQUAL)
      (INSTANCEOF . ,INSTANCEOF)
      (IN . ,IN)
      (LOGICAL-AND . ,LOGICAL-AND)
      (LOGICAL-NOT . ,LOGICAL-NOT)
      (LOGICAL-OR . ,LOGICAL-OR)
      (LT . ,LT)
      (LTE . ,LTE)
      (MEMBER-EXP . ,MEMBER-EXP)
      (MEMBER-LIT . ,MEMBER-LIT)
      (MINUS . ,MINUS)
      (MULT . ,MULT)
      (MULT-ASSIGN . ,MULT-ASSIGN)
      (NEW . ,NEW)
      (NOT-EQUAL . ,NOT-EQUAL)
      (NOT-STRICTLY-EQUAL . ,NOT-STRICTLY-EQUAL)
      (PLUS . ,PLUS)
      (PLUS-ASSIGN . ,PLUS-ASSIGN)
      (MINUS-ASSIGN . ,MINUS-ASSIGN)
      (POSTFIX-DEC . ,POSTFIX-DEC)
      (POSTFIX-INC . ,POSTFIX-INC)
      (PREFIX-DEC . ,PREFIX-DEC)
      (PREFIX-INC . ,PREFIX-INC)
      (REM . ,REM)
      (REM-ASSIGN . ,REM-ASSIGN)
      (SEQUENCE . ,SEQUENCE)
      (SIGNED-RIGHT-SHIFT . ,SIGNED-RIGHT-SHIFT)
      (SIGNED-RIGHT-SHIFT-ASSIGN . ,SIGNED-RIGHT-SHIFT-ASSIGN)
      (TYPEOF . ,TYPEOF)
      (UNARY-MINUS . ,UNARY-MINUS)
      (UNARY-PLUS . ,UNARY-PLUS)
      (UNSIGNED-RIGHT-SHIFT . ,UNSIGNED-RIGHT-SHIFT)
      (UNSIGNED-RIGHT-SHIFT-ASSIGN . ,UNSIGNED-RIGHT-SHIFT-ASSIGN)
      (VOID . ,VOID)
      (BREAK . ,BREAK)
      (CASE . ,CASE)
      (CONTINUE . ,CONTINUE)
      (DEFAULT . ,DEFAULT)
      (DO-WHILE . ,DO-WHILE)
      (FOR . ,FOR)
      (FOR-IN . ,FOR-IN)
      (FOR-VAR . ,FOR-VAR)
      (FOR-VAR-IN . ,FOR-VAR-IN)
      (FUNCTION . ,FUNCTION)
      (IF . ,IF)
      (LABEL . ,LABEL)
      (RETURN . ,RETURN)
      (SWITCH . ,SWITCH)
      (THROW . ,THROW)
      (TRY-CATCH . ,TRY-CATCH)
      (TRY-CATCH-FINALLY . ,TRY-CATCH-FINALLY)
      (TRY-FINALLY . ,TRY-FINALLY)
      (VAR . ,VAR)
      (WHILE . ,WHILE)
      (WITH . ,WITH)))

  (module test
    (define-macro (trial stx)
      `(assert ,@(cdr stx) (format "%s failed" ',@(cdr stx))))
    
    (define-macro (fail stx)
      `(assert (eq? 'exception (except (lambda (e) 'exception)
                                 ,@(cdr stx)))
               (format "%s failed" ',@(cdr stx))))

    (for-each (lambda (trial-spec)
                ;;(printf "trial-spec: %s\n" trial-spec)
                (let ([result (ast->markup (car trial-spec))])
                  ;;(printf "result: %s\n" result)
                  (trial (equal? result (cadr trial-spec)))))
                
              '(((IDENTIFIER foo) ("foo"))
                
                ((MEMBER-LIT (IDENTIFIER foo) (IDENTIFIER "bar"))
                 ("foo" "." "bar"))

                ((MEMBER-EXP (IDENTIFIER foo) (LITERAL "bar*"))
                 ("foo" "[" "\"" "bar*" "\"" "]"))

                ((MEMBER-LIT (MEMBER-EXP (IDENTIFIER foo) (LITERAL "bar*")) (IDENTIFIER "baz"))
                 ("foo" "[" "\"" "bar*" "\"" "]" "." "baz"))

                ((CONDITIONAL (LITERAL 2) (LITERAL "A") (LITERAL "B"))
                 ((push-base) "2" (indent) (newline) " ? " "\"" "A" "\"" (newline) " : " "\"" "B" "\"" (pop-base)))

                ((STRICTLY-EQUAL (IDENTIFIER foo) (LITERAL #f))
                 ("foo" " === " "false"))

                ((NOT-STRICTLY-EQUAL (IDENTIFIER foo) (LITERAL #f))
                 ("foo" " !== " "false"))

                ((SEQUENCE (IDENTIFIER foo) (IDENTIFIER bar))
                 ((push-base) "foo" ", " (newline) "bar" (pop-base)))

                ((RETURN (LITERAL #t))
                 ("return " "true"))

                ((STATEMENT (RETURN (LITERAL #t)))
                 ("return " "true" ";"))

                ((FUNCTION #f ((IDENTIFIER x)) ((STATEMENT (RETURN (LITERAL #t)))))
                 ((push-base) "function " "(" (push-base) "x" (pop-base) ")" " " "{" (indent) (newline)
                  "return " "true" ";" (outdent) (newline) "}" (pop-base)))

                ((CALL (IDENTIFIER "$arglist")
                       ((IDENTIFIER arguments)
                        (LITERAL 0)))
                 ("$arglist" "(" (push-base) "arguments" ", " (newline)
                  "0" (pop-base) ")"))

                ((VAR ((IDENTIFIER x)))
                 ("var " (push-base) "x" (pop-base)))
                
                ((VAR (((IDENTIFIER x) (LITERAL 7))))
                 ("var " (push-base) "x" " = " "7" (pop-base)))
                
                ((VAR (((IDENTIFIER x) (LITERAL 7)) (IDENTIFIER y)))
                 ("var " (push-base) "x" " = " "7" ", " (newline)
                  "y" (pop-base)))

                ((ASSIGN (IDENTIFIER "$temp") (IDENTIFIER foo))
                 ("$temp" " = " "foo"))

                ((PAREN (ASSIGN (IDENTIFIER "$temp") (IDENTIFIER foo)))
                 ("(" "$temp" " = " "foo" ")"))

                ;; end of trials
                ))

    "End Module test")
    
  "END Module javascript")