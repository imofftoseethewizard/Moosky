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

(module primitive-syntax

  ;;;
  ;;;
  ;;; primitives
  ;;;   this is the first internal representation of Moosky code.
  ;;;   the user and preamble layers of macros are fully expanded
  ;;;   to produce a pure primitive representation of the source.
  ;;;   this allows reasoning about lexically explicit recursion
  ;;;   even in cases of indirectly explicit recursion, e.g., 
  ;;;   (set! foo (let ([bar 0]) (lambda (baz) (foo 6))))
  ;;;
  ;;;
  ;;;
  ;;; implies binding forms (lambdas) must cache binding information
  ;;; set! forms must update binding information, either to provide initial value,
  ;;; or to note that the symbol is mutable.
  ;;;
  ;;; Recursion detection:
  ;;;  an application A = (S ...) of a symbol S which is currently being defined.
  ;;;  locate the LAMBDA in V*((S ...)) which contains (S ...) in the transitive
  ;;;  closure of its subforms.
  ;;;
  ;;;  if one cannot be found, then it is not explict recurrence.
  ;;;
  ;;; recursion
  ;;;   when:
  ;;;     application of symbol
  ;;;     symbol is currently being defined
  ;;;     there is a path from the set! form to the application form
  ;;;       such that there is a LAMBDA in value position.
  ;;;
  ;;;   then:
  ;;;     mark given lambda as recursive
  ;;;     add recomputation of parameters to call site
  ;;;     return the continue marker from the call site
  ;;;     at the lambda, add bindings for temporary values for
  ;;;      function parameters
  ;;;     add result binding
  ;;;     add binding for continue marker
  ;;;
  ;;;   requires:
  ;;;     set! creates context holding target symbol
  ;;;     lambda checks recursive after processing of body
  ;;;     application checks for recursion (applied name in enclosing set)
  ;;;     utility that traces form inclusion, returns a list
  ;;;     determining appropriate lambda:
  ;;;       must be in inclusion list
  ;;;       must be in value position relative to the set
  ;;;
  
  (export parse-kernel special-forms)

  (import * from parser)


  ;;--------------------------------------------------------------------------
  ;;
  ;; (parse-kernel stx ctx)
  ;;
  ;; stx is syntax to be parsed by the primitive parser.
  ;;
  ;; ctx is the context in which the syntax occurs.
  ;;
  
  (define (parse-kernel stx ctx)
    (let ([parser (if (list? stx)
                      (if (symbol? (car stx))
                          (or (assoc-ref (car stx) special-forms.parsers)
                              parse-application)
                          (if (and (list? (car stx))
                                   (eq? (caar stx) 'lambda))
                              parse-let-form
                              parse-application))
                      parse-value)])
      (parser stx ctx)))


  
  ;;--------------------------------------------------------------------------
  ;;
  ;; (parse-application stx ctx)
  ;;
  ;; stx is syntax to be parsed by the primitive parser.  stx must be a list,
  ;; and not a primitive form, nor a let construct -- ((LAMBDA ...) ...).
  ;;
  ;; ctx is the context in which the syntax occurs.
  ;;
  ;; When symbol of the function to be called is currently being set, this
  ;; application represents a case of lexically explicit recursion.  If not,
  ;; then it's an ordinary function application and the handling is straight-
  ;; forward.
  ;;
  ;; In the case of a recursive call, we ensure that the context corresponding
  ;; to the form that defines the recurring lambda has been marked recursive.
  ;; There is additional special handling for this in primitives.LAMBDA.
  ;;
  ;; Produced code preserves lexical integrity while updating the call
  ;; parameters by assigning each new value to a temporary until all new values
  ;; are computed, and then copying each to the appropriate local variable.
  ;; The result returned is a unique continuation object which will cause
  ;; the while loop of the 'called' function to repeat its computation again. 
  ;; 
  ;; Example:
  ;;
  ;; Scheme code:
  ;;
  ;;   (define (foo x)
  ;;     (letrec ([bar (lambda (y)
  ;;                     (if y
  ;;                         (foo y)
  ;;                         (bar x)))])
  ;;        (bar 1)))
  ;;
  ;;
  ;; Reduced to primitive code:
  ;;
  ;;   (SET! foo (LAMBDA (x)
  ;;               ((LAMBDA (bar)
  ;;                  (SET! bar (LAMBDA (y)
  ;;                              (IF y
  ;;                                  (foo y)
  ;;                                  (bar x))))
  ;;                  (bar 1))
  ;;                #u)))
  ;;          
  ;;
  ;; Translated to Javascript:
  ;;
  ;;   $['foo'] = function(x) {
  ;;     var $R_foo, $C_foo = {}, $foo_x;
  ;;   
  ;;     var bar = function(y) {
  ;;       var $R_bar, $C_bar = {}, $bar_y;
  ;;   
  ;;       while (($R_bar = (y ? ($foo_x = y, $C_foo) : ($bar_y = x, $C_bar))),
  ;;   	   $R_bar === $C_bar);
  ;;   
  ;;       return $R_bar;
  ;;     }
  ;;   
  ;;     while (($R_foo = bar(1)), result === $C_foo);
  ;;   
  ;;     return $R_foo;
  ;;   }
  ;;   
  
  (define (parse-application stx ctx)
    (let* ([applicand (car stx)]
           [set-ctx (and (symbol? applicand)
                         (tail-context? ctx)
                         (find-set-context ctx applicand))])

      (if set-ctx
          (parse-recursive-application stx ctx set-ctx)
          `(CALL ,(parse applicand stx)
                 ,(map (lambda (stx)
                         (parse stx ctx))
                       (cdr stx)))

  
  (define (parse-recursive-application stx ctx set-ctx)
    ;; recursive application
    (let* ([set-form (object-ref set-ctx stx:)]
           [recurrer-ctx (find-recurring-lambda-context set-form stx ctx)]
           [params (map (lambda (stx)
                          (parse stx ctx))
                        (cdr stx))]
           
           [formals     (context-ref recurrer-ctx formals:)]
           [rest        (context-ref recurrer-ctx rest:)]
           [temporaries (context-ref recurrer-ctx temporaries:)]
           [formal-count (length formals)])
      
      (set-context-recurring! recurrer-ctx)
      `(SEQUENCE ,@(map (lambda (formal actual)
                          `(ASSIGN (IDENTIFIER ,temp)
                                   ,(precedence-bracket 'ASSIGN actual)))
                        temporaries
                        (take formal-count params))
                 ,@(if rest
                       (list `(ASSIGN (IDENTIFIER ,rest)
                                      (CALL (IDENTIFIER "list")
                                            ,(drop formal-count params))))
                       '())
                 ,@(map (lambda (formal actual)
                          `(ASSIGN (IDENTIFIER ,formal) ,temp))
                        formals
                        temporaries)
                 (IDENTIFIER ,(context-ref recurrer-ctx continue-symbol:)))))


  (define (parse-let-form ctx)
    (let* ([applicand (car stx)]
           [ctx (make-let-context stx ctx)]
           [locals (cadr applicand)])
      `(SEQUENCE ,@(map (lambda (local actual)
                          `(ASSIGN (IDENTIFIER ,(context-alias ctx local))
                                   ,(precedence-bracket 'ASSIGN
                                                        (parse actual ctx))))
                        locals
                        (cdr stx))
                 ,@(map (lambda (stx)
                          (parse stx ctx))
                        (cddr applicand)))))


  
  (define (parse-tailed-sequence stx ctx)
    (let* ([stx-r (reverse stx)]
           [tail (parse (car stx-r) ctx)]
           [ctx (make-non-tail-context stx ctx)])
      (let loop ([stx (cdr stx-r)]
                 [result (list tail)])
        (if (null? stx)
            result
            (loop (cdr stx)
                  (cons (parse (car stx) ctx)
                        result))))))
  
  
  (define (parse-value stx ctx)
    (cond [(symbol? stx)
           (parse-symbol stx ctx)]

          [(vector? stx)
           (parse-vector stx ctx)]

          [#t
           `(LITERAL ,stx)]))

  
  ;;--------------------------------------------------------------------------
  ;;
  ;; (parse-symbol sym)
  ;;
  ;; sym is a symbol.
  ;;
  ;; parse-symbol handles the translation of scheme-namespace symbols to
  ;; javascript identifiers.  Since the notion of an identifier in javascript
  ;; is much restricted compared to scheme, either the symbols must be used
  ;; as strings (in the case of member reference and defined values), or as
  ;; a deterministically computed identifier (in the case of function formal
  ;; parameters).
  ;;
  ;; In particular, members and definitions in a module namespace (eg, $['foo'])
  ;; are used directly if they are javascript identifiers (composed of the
  ;; characters A-Za-z0-9_$ and not starting with a number); if they are not
  ;; javascript identifiers, then the member is accessed using bracket notation.
  ;;
  ;;   foo.bar becomes foo.bar,
  ;;   foo-bar.baz becomes $['foo-bar'].baz, and
  ;;   foo.bar-baz becomes foo['bar-baz']
  ;;
  ;; Alternatively, this could be handled separately, by introducing, e.g.
  ;; $['#foo-bar_66'], into the module namespace and adding a preamble assignment
  ;; to handle formal parameter 'foo-bar', e.g. '$['#foo-bar_66'] = foo_bar.
  ;; This would probably be slightly less efficient than using local variables,
  ;; or perhaps not, depending on the JS engine implementation.
  ;;

  (define (parse-symbol sym ctx)
    (let* ([components (map string->symbol (string-split (symbol->string sym) "."))]
           [base (context-alias ctx (car components))])

      (fold-left (lambda (component)
                   (if (identifier? component)
                       `(MEMBER-LIT ,result (IDENTIFIER ,component))
                       `(MEMBER-EXP ,result (LITERAL ,component))))
                 
                 (if (identifier? base)
                     `(IDENTIFIER ,base)
                     (if (bound-symbol? base ctx)
                         `(IDENTIFIER (make-identifier base))
                         `(MEMBER-EXP (IDENTIFIER "$") (LITERAL raw))))
                 
                 (cdr components))))


  (define (parse-vector stx ctx)
    (let ([ctx (make-non-tail-context stx ctx)])
      (list->vector (map (lambda (stx)
                           (parse stx ctx))
                         (vector->list stx)))))

  
  ;;--------------------------------------------------------------------------
  ;;
  ;; The context is a list of objects which store syntax information
  ;; associated with nodes in the syntax tree.  It is a transient structure
  ;; that is built dynamically during syntax analysis.  There are currently
  ;; three distinct type of objects in the list: root contexts, set contexts,
  ;; and lambda contexts.  The last item in any context is a root context
  ;; object.  There is only ever one root context object in a context.  Set
  ;; contexts are created when a set! form is encountered.  It is used to
  ;; detect lexically explicit recursion.  Lambda contexts are created during
  ;; the analysis of lambda forms.  Because they are translated into function
  ;; blocks, they are a convenient place to manage and store complex constants
  ;; (quotes) and variable declarations (bindings).
  ;;
  ;; When a new context object is created for a subcontext of the existing one,
  ;; the context object is consed onto the head of the existing context.
  ;;

  
  (define (make-root-context stx)
    (let ([ctx (make-parse-context stx '() 'root
                                   '() parse-kernel)])
      (context-extend! ctx
        tail: #f)))

  
  (define (make-set-context stx ctx)
    (let ([ctx (make-parse-context stx ctx 'set)]
          [target (cadr stx)]
          [value (caddr stx)])
      (add-binding! ctx target (make-set-binding target value))

      (context-extend! ctx
        tail: #f
        target: target
        value: value)))
  

  (define (make-lambda-context stx ctx)
    (let ([ctx (make-parse-context stx ctx 'lambda)])
      (let-values ([(formals rest) (rectify (cadr stx))])
        (for-each (lambda (formal)
                    (add-binding! ctx formal (make-formal-binding formal)))
                  formals)
        
        (unless (null? rest)
          (add-binding! ctx (make-rest-binding rest)))
        
        (context-extend! ctx
          tail: #t
          formals: formals
          rest: rest
          temporaries: '()
          recursive: #f))))


  (define (make-let-context stx ctx)
    (let ([let-ctx (make-parse-context stx ctx 'let)])
      (for-all (lambda (sym)
                 (add-binding! ctx (make-let-binding sym)))
               (cadar stx))
      let-ctx))


  (define (make-non-tail-context stx ctx)
    (let ([ctx (make-parse-context stx ctx 'non-tail)])
      (context-extend! ctx
        tail: #t)))



  (define (make-binding symbol alias tag)
    (object symbol: symbol
            alias: alias
            tag: tag))

  (define (make-set-binding target value)
    (extend-object! (make-binding 'set target target)
      value: value))

  (define (make-formal-binding formal)
    (make-binding 'formal formal formal))

  (define (make-let-binding sym)
    (make-binding sym (gensym sym) 'let))

  (define (make-rest-binding rest)
    (make-binding 'rest rest rest))

  (define (make-definition-binding name)
    (make-binding 'definition name name))


  (define (definition-binding? binding)
    (eq? binding.tag 'definition))

  (define (let-binding? binding)
    (eq? binding.tag 'let))


  (define (lambda-context? ctx)
    (eq? (context-tag ctx) 'lambda))

  (define (set-context? ctx)
    (eq? (context-tag ctx) 'set))

  (define (root-context? ctx)
    (eq? (context-tag ctx) 'root))


  (define (definition-context? ctx)
    (or (lambda-context? ctx)
        (root-context? ctx)))

  (define quote-context? root-context?)

  (define (recursive-lambda-context? ctx)
    (and (lambda-context? ctx)
         (context-ref ctx recursive:)))

  (define (tail-context? ctx)
    (context-ref ctx tail:))


  (define (add-definition! ctx target)
    (add-binding! (find definition-context? (context-stack ctx))
                  (make-definition-binding target)))

  (define (add-quote! ctx symbol value)
    (add-binding! (find quote-context? (context-stack ctx))
                  (make-quote-binding symbol value)))


  (define (get-definitions ctx)
    (filter definition-binding? (context-local-bindings ctx)))

  
  (define (find-set-context ctx sym)
    (find (lambda (ctx)
            (and (set-context? ctx)
                 (eq? sym (context-ref ctx target:))))
          (context-stack ctx)))

  
  ;;--------------------------------------------------------------------------
  ;;
  ;; (find-recurring-lambda-context root application ctx)
  ;;
  ;; root is the set! form which contains application.
  ;;
  ;; application is an application form from a syntax tree.  The applicand is
  ;; a symbol whose set! context contains this form, i.e. it's an explicitly
  ;; recursive call.  ctx is the parse context in which the call occurs.
  ;;
  ;; Compute the value-set of the value part of the root set! form.  At least
  ;; one of these should be a lambda form, and it should appear in the context
  ;; chain between ctx and the set! context of root.  That lambda represents the
  ;; function that will recur on the evaluation of the application.
  ;;
  
  (define (find-recurring-lambda-context root application ctx)
    (let ([value-forms (value-set (caddr root))])
      (memp (lambda (ctx)
              (memq (context-stx ctx) value-forms))
            (filter lambda-context? (reverse (context-stack ctx))))))


  ;;--------------------------------------------------------------------------
  ;;
  ;; (value-set x)
  ;;
  ;; x can be any value, but its interpretation is as a form in the primitive
  ;; language.
  ;;
  ;; Computes a list of the potential explicit values of this form.  These
  ;; constitute the lexically-observable literal values, symbol references,
  ;; and applications that collectively provide the values returned by the
  ;; given form.
  ;;
  ;; It is the transitive closure V* of the following function:
  ;;
  ;; V(x) = {x}
  ;;   where x is not a list; or
  ;;   where x is a LAMBDA, QUASIQUOTE, or QUOTE form; or
  ;;   where x is an application whose applicand is a symbol, or
  ;;              evaluates to a symbol reference.
  ;;
  ;; V*(x) = V(x), trivially.
  ;;
  ;; Suppose x is a tree with K cons pairs, and let the subforms of
  ;; x be the forms {x_1, ..., x_N}.  Further suppose that for all k < K,
  ;; V(x) and V*(x) are well defined.
  ;;
  ;; V(x) = { x_i for i in [2, N] }
  ;;   where x_1 is either AND or OR.
  ;;
  ;; V(x) = { x_N }
  ;;   where x_1 is BEGIN.
  ;;
  ;; V(x) = { }
  ;;   where x_1 is either DEFINE or SET!.
  ;;
  ;; In the case where x_1 is a form, let v_j be the forms of V*(x_1)
  ;; such that each v_j is a form (v_j_1 ... v_j_N(j)) such that
  ;; v_j_1 = LAMBDA, for j from 1 up to some M.  Then for such x,
  ;;
  ;; V(x) = UNION V*(v_j_N(j)) for j in [1, M].
  ;;
  ;; This is well-defined since the parameters to V and V* are all subforms
  ;; of x, and thus have order k < K.  A consistent definition follows by
  ;; induction for all x.
  ;;
  
  (define (value-set x)
    (if (not (list? x))
        (list x)
        (let ([applicand (car x)])
          (cond [(member applicand '(LAMBDA QUASIQUOTE QUOTE))
                 (list x)]

                [(member applicand '(AND OR))
                 (apply append (map (lambda (sub-x)
                                      (value-set sub-x))
                                    (cdr x)))]

                [(eq? applicand 'BEGIN)
                 (list (last x))]

                [(member applicand '(DEFINE SET!))
                 '()]

                [(list? applicand)
                 (apply append (map (lambda (lm)
                                      (value-set (last lm)))
                                    (filter (lambda (vx)
                                              (and (pair? vx)
                                                   (eq? (car vx) 'LAMBDA)))
                                            (value-set applicand))))]
                
                [#t
                 (list f)]))))


  (define (set-context-recurring! ctx)
    (assert (lambda-context? ctx))
    (unless (recursive-lambda-context? ctx)
      (context-extend! ctx
        recursive:       #t
        result-symbol:   (gensym "$R")
        continue-symbol: (gensym "$C")
        temporaries:     (map (lambda (formal)
                                (cons formal (gensym formal)))
                              (context-ref ctx formals:)))))

  (module special-forms

    (import * from javascript)
    (export *)

    (define (AND stx ctx)
      (assert (proper-list? stx) (format "syntax error: and form must be a proper list: %s" stx))
      (if (null? (cdr stx))
          '(LITERAL #t)
          (let ([stx-params-r (reverse (cdr stx))])
            (let loop ([params (let ([ctx (make-non-tail-context stx ctx)])
                                 (map (lambda (stx)
                                        (precedence-bracket 'STRICTLY-EQUAL
                                                            (parse stx ctx)))
                                      (cdr stx-params-r)))]
                       [result (parse (car stx-params-r) ctx)])
              (if (null? params)
                  result
                  (loop (cdr params)
                        `(CONDITIONAL (STRICTLY-EQUAL ,(car params)
                                                      (LITERAL #f))
                                      (LITERAL #f)
                                      ,result)))))))



    (define (BEGIN stx ctx)
      (assert (proper-list? stx) (format "syntax error: begin form must be a proper list: %s" stx))
      (cond [(null? (cdr stx))
             '(LITERAL #u)]

            [(null? (cddr stx))
             (parse (cadr stx) ctx)]

            [#t
             `(SEQUENCE ,@(parse-tailed-sequence (cdr stx) ctx))]))


    (define (DEFINE stx ctx)
      (assert (proper-list? stx) (format "syntax error: define form must be a proper list: %s" stx))
      (assert (and (= 1 (length stx))
                   (symbol? (cadr stx)))
              (format "syntax error: define form requires a single symbol (not %s): %s"
                      (- (length stx) 1) stx))

      (add-definition! ctx (cadr stx)))
    

    (define (IF stx ctx)
      (assert (proper-list? stx) (format "syntax error: if form must be a proper list: %s" stx))
      (assert (= 4 (length stx)) (format "syntax error: if form requires three subforms (not %s): %s"
                                         (- (length stx) 1) stx))

      `(CONDITIONAL ,@(precedence-bracket 'CONDITIONAL
                                          (parse (cadr stx) (make-non-tail-context stx ctx)))
                    ,@(map (lambda (stx)
                             (precedence-bracket 'CONDITIONAL
                                                 (parse stx ctx)))
                           (cddr stx))))


    (define (LAMBDA stx ctx)
      (assert (proper-list? stx) (format "syntax error: lambda form must be a proper list: %s" stx))
      (assert (>= 3 (length stx)) (format "syntax error: lambda form requires at least two subforms (not %s): %s"
                                          (- (length stx) 1) stx))
      (let-values ([(formals rest) (rectify (cadr stx))])
        (assert (and (for-all simple-symbol? formals)
                     (or (null? rest)
                         (simple-symbol? rest)))
                (format "syntax error: the formal parameters of a lambda form are expected to be a symbol, a list of symbols, or a dotted list of symbols: %s"
                        stx))

        (let* ([ctx (make-lambda-context stx ctx)]
               [body (let ([body (parse-tailed-sequence (cddr stx) ctx)])
                       ;; explicitly recursive lambdas rename their parameters
                       ;; so that they can be expressed as while loops, this may
                       ;; require reparsing of expressions that occur lexically
                       ;; prior to the first recursive call, as the symbols
                       ;; referencing function arguments in the emitted code
                       ;; will be different.
                       (if (recursive-lambda-context? ctx)
                           (parse-tailed-sequence (cddr stx) ctx)
                           body))]
               [rest-binding (if (null? rest)
                                 '()
                                 `(((IDENTIFIER ,rest) .
                                    (CALL (IDENTIFIER "$arglist")
                                          ((IDENTIFIER "arguments")
                                           (LITERAL ,(length formals)))))))]
               [recursive-bindings (if (not (recursive-lambda-context? ctx))
                                       '()
                                       (append (map (lambda (temp)
                                                      `((IDENTIFIER ,temp) . (LITERAL #u)))
                                                    (context-ref ctx temporaries:))
                                               (list `(((IDENTIFIER ,(context-ref ctx result-symbol:)) . (LITERAL #u))
                                                       ((IDENTIFIER ,(context-ref ctx continue-symbol:)) .
                                                        (CALL (IDENTIFIER "Object")
                                                              ()))))))]
               [definition-bindings (map (lambda (binding)
                                           `((IDENTIFIER ,binding.symbol) . (LITERAL #u)))
                                         (get-definitions ctx))]
               [bindings `(STATEMENT
                           (VAR (,@rest-binding
                                 ,@recursive-bindings
                                 ,@definition-bindings)))])
          `(FUNCTION #f ,formals ,(append bindings body)))))


    (define (OR stx ctx)
      (assert (proper-list? stx) (format "syntax error: or form must be a proper list: %s" stx))
      (if (null? (cdr stx))
          '(LITERAL #f)
          (let ([ctx (make-non-tail-context stx ctx)]
                [stx-params-r (reverse (cdr stx))])
            (let loop ([params (let ([ctx (make-non-tail-context stx ctx)])
                                 (map (lambda (stx)
                                        (precedence-bracket 'ASSIGN
                                                            (parse stx ctx)))
                                      (cdr stx-params-r)))]
                       [result (parse (car stx-params-r) ctx)])
              (if (null? params)
                  result
                  (loop (cdr params)
                        `(CONDITIONAL (NOT-STRICTLY-EQUAL (PAREN (ASSIGN (IDENTIFIER "$temp") ,(car params)))
                                                          (LITERAL #f))
                                      (IDENTIFIER "$temp")
                                      ,result)))))))


    (define (QUASIQUOTE stx ctx)
      (assert (proper-list? stx) (format "syntax error: quasiquote form must be a proper list: %s" stx))
      (assert (= 2 (length stx)) (format "syntax error: quasiquote form requires one value (not %s): %s"
                                         (- (length stx) 1) stx))
      
      (let* ([ctx (make-non-tail-context stx ctx)]
             [lambdas '()]
             [quoted (let walk ([stx (cadr stx)])
                       (if (not (pair? stx))
                           stx
                           (let ([A (car stx)])
                             (cond [(or (eq? A 'unquote-splicing)
                                        (eq? A 'unquote))
                                    (set! lambdas (cons (parse `(LAMBDA '() ,@(cdr stx)) ctx)
                                                        lambdas))
                                    (list A)]

                                   [(eq? A 'quasiquote)
                                    stx]

                                   [#t
                                    (cons (walk A) (walk (cdr stx)))]))))])

        `(CALL (IDENTIFIER "quasi-unquote")
               (cons ,(parse `(QUOTE ,quoted) ctx)
                     ,(reverse (lambdas))))))


    (define (QUOTE stx ctx)
      (assert (proper-list? stx) (format "syntax error: quote form must be a proper list: %s" stx))
      (assert (= 2 (length stx)) (format "syntax error: quote form requires one value (not %s): %s"
                                         (- (length stx) 1) stx))
      (let ([quoted (let walk ([stx (cadr stx)])
                      (cond [(null? stx)
                             `(IDENTIFIER "$nil")]

                            [(list? stx)
                             `(CALL (IDENTIFIER "cons")
                                    (list ,(walk (car stx))
                                          ,(walk (cdr stx))))]

                            [#t
                             `(LITERAL ',stx)]))])
        (if (list? (cadr stx))
            (let ([sym (gensym 'quote)])
              (add-quote! ctx sym quoted)
              `(IDENTIFIER sym))
            quoted)))


    (define (SET! stx ctx)
      (assert (proper-list? stx) (format "syntax error: set form must be a proper list: %s" stx))
      (assert (= 3 (length stx)) (format "syntax error: set form requires two parts (not %s): %s"
                                         (- (length stx) 1) stx))
      (assert (simple-symbol? (cadr stx)) (format "syntax error: set form requires that its first component is a symbol: %s"
                                                  stx))

      (let ([target (cadr stx)])
        (let ([ctx (make-set-context stx ctx)])
          `(ASSIGN ,(parse-symbol target)
                   ,(precedence-bracket 'ASSIGN (parse (caddr stx)
                                                       (make-non-tail-context stx ctx)))))))

    (define parsers
      `((and        . ,AND)
        (begin      . ,BEGIN)
        (define     . ,DEFINE)
        (if         . ,IF)
        (lambda     . ,LAMBDA)
        (or         . ,OR)
        (quasiquote . ,QUASIQUOTE)
        (quote      . ,QUOTE)
        (set!       . ,SET!)))

    
    "End Module special-forms")

  
  (module test
    (define-macro (trial stx)
      `(assert ,@(cdr stx) (format "%s failed" ',@(cdr stx))))


    "End Module test")
  

  "END Module primitives")