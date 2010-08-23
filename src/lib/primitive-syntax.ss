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
  
  (export *)

  (import * from generic-parser)
  (import * from javascript)

  (define trace
    (let ([tracing #f])
      (lambda (new)
        (when (defined? new)
          (set! tracing new))
        tracing)))

  
  (define (internal->target stx)
    (let* ([ctx (make-root-context stx)]
           ;;[dummy (print "*")]
           [body (parse stx ctx)]
           [dummy (printf "internal->target: body: %s\n" body)]
           [decls (map (lambda (binding)
                         `(IDENTIFIER ,binding.alias))
                       (append (get-definitions ctx)
                               (get-subordinated-lets ctx)))]
           [quotes (map (lambda (binding)
                          `((IDENTIFIER ,binding.alias) ,binding.value))
                        (get-quotes ctx))]
           [all-bindings (append decls quotes)]
           ;;[dummy (print "*")]
           [binding-stmts (if (= 0 (length all-bindings))
                              '()
                              `((STATEMENT (VAR ,all-bindings))))])
      ;;(print "+")
      `(CALL
        (PAREN
         (FUNCTION #f () ,(append binding-stmts `((STATEMENT (RETURN ,body))))))
        () )))
  
  
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
                                   (eq? (caar stx) 'LAMBDA))
                              parse-let-form
                              parse-application))
                      parse-value)])
      (assert (defined? parser) "parse-kernel: parser not defined")
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
           [recurrer-ctx (let ([set-ctx (and (symbol? applicand)
                                             (tail-context? ctx)
                                             (find-set-context ctx applicand))])
                           (and set-ctx
                                (find-recurring-lambda-context (context-ref set-ctx stx:)
                                                               stx ctx)))]
           [recursive? (let loop ([cs (context-stack ctx)])
                         (and (not (null? cs))
                              (let ([c (car cs)])
                                (or (eq? c recurrer-ctx)
                                    (and (tail-context? c)
                                         (not (lambda-context? c))
                                         (loop (cdr cs)))))))]
           [params (map (lambda (stx)
                          (parse stx ctx))
                        (cdr stx))])
      
      (if (not recursive?)
          `(CALL ,(precedence-bracket 'CALL
                                      (parse applicand ctx))
                 ,params)
          
          (let* ([formals      (context-ref recurrer-ctx formals:)]
                 [rest         (context-ref recurrer-ctx rest:)]
                 [formal-count (length formals)])
            
            (set-context-recurring! recurrer-ctx)
            (let ([temporaries (context-ref recurrer-ctx temporaries:)])
              `(SEQUENCE ,@(map (lambda (temp actual)
                                  `(ASSIGN (IDENTIFIER ,(cdr temp))
                                           ,(precedence-bracket 'ASSIGN actual)))
                                temporaries
                                (take formal-count params))
                         ,@(if (not (null? rest))
                               `((ASSIGN (IDENTIFIER ,rest)
                                         (CALL (IDENTIFIER list)
                                               ,(drop formal-count params))))
                               '())
                         ,@(map (lambda (formal temp)
                                  `(ASSIGN (IDENTIFIER ,formal) (IDENTIFIER ,(cdr temp))))
                                formals
                                temporaries)
                         (IDENTIFIER ,(context-ref recurrer-ctx continue-symbol:))))))))


  (define (parse-let-form stx ctx)
    (let* ([applicand (car stx)]
           [let-ctx (make-let-context stx ctx)]
           [locals (cadr applicand)]
           [body (map (lambda (stx)
                        (parse stx let-ctx))
                      (cddr applicand))])
      
      ;; parsing the body may modify the current context.  Let forms
      ;; collect binding information for definitions.  However, let
      ;; forms do not host the declarations, but pass them off to the
      ;; innermost containing lambda, or root, if one does not exist.
      ;; Let forms collect the binding information to restrict the
      ;; scope of the defines to the lexical interior of the let.
      ;; cf binding.alias, context.bindings where tag is 'definition'
      
      (let ([host-ctx (find (lambda (ctx)
                              (or (lambda-context? ctx)
                                  (root-context? ctx)))
                            (context-stack ctx))])
        (for-each (lambda (b)
                    (when (trace)
                      (printf "parse-let-form: binding to %s host: %s (%s)\n"
                              (context-tag host-ctx)
                              b.symbol
                              b.tag))
                    (add-binding! host-ctx (list b.symbol) b))
                  (map cdr (context-local-bindings let-ctx)))
        
        `(SEQUENCE ,@(map (lambda (local actual)
                            `(ASSIGN (IDENTIFIER ,(context-alias let-ctx local))
                                     ,(precedence-bracket 'ASSIGN
                                                          (parse actual ctx))))
                          locals
                          (cdr stx))
                   ,@body))))

  
  (define (parse-tailed-sequence stx ctx)
    (let ([non-tail-ctx (make-non-tail-context stx ctx)])
      (mapcdr (lambda (stx-cdr)
                (let ([stx (car stx-cdr)])
                  (parse stx (if (null? (cdr stx-cdr))
                                 ctx
                                 non-tail-ctx))))
              stx)))
  ;;       (let* ([stx-r (reverse stx)]
  ;;              [tail (parse (car stx-r) ctx)]
  ;;              [ctx (make-non-tail-context stx ctx)])
  ;;         (let loop ([stx (cdr stx-r)]
  ;;                    [result (list tail)])
  ;;           (if (null? stx)
  ;;               result
  ;;               (loop (cdr stx)
  ;;                     (cons (parse (car stx) ctx)
  ;;                           result))))))
  
  
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
    (let* ([components (string-split (symbol->string sym) ".")]
           [base (context-alias ctx (string->symbol (car components)))])
      (when (eq? sym 'X)
        (when (trace)
          (printf "parse-symbol: context-alias: %s\n" (context-alias ctx sym))
          (for-each (lambda (ctx)
                      (printf "parse-symbol: ctx.tag: %s:\n" (context-tag ctx))
                      (for-each (lambda (binding)
                                  (printf "  %s %s\n" (car binding) (object-ref (cdr binding) alias:)))
                                (context-local-bindings ctx)))
                    (context-stack ctx))))
      (fold-left (lambda (result component)
                   (if (identifier? component)
                       `(MEMBER-LIT ,result (IDENTIFIER ,component))
                       `(MEMBER-EXP ,result (LITERAL ,component))))
                 
                 (if (identifier? base)
                     `(IDENTIFIER ,base)
                     (if (get-binding ctx base)
                         `(IDENTIFIER ,(make-identifier base))
                         `(MEMBER-EXP (IDENTIFIER "$") (LITERAL ,(symbol->string base)))))
                 (cdr components))))


  (define (parse-vector stx ctx)
    (let ([ctx (make-non-tail-context stx ctx)])
      (list->vector (map (lambda (stx)
                           (parse stx ctx))
                         (vector->list stx)))))

  
  (define (make-binding symbol alias tag)
    (object symbol: symbol
            alias: alias
            tag: tag))

  (define (make-definition-binding name)
    (make-binding name name 'definition))

  (define (make-local-definition-binding name)
    (make-binding name (gensym (make-identifier name)) 'definition))

  (define (make-formal-binding formal)
    (make-binding formal formal 'formal))

  (define (make-let-binding sym)
    (make-binding sym (gensym sym) 'let))

  (define (make-quote-binding sym value)
    (extend-object! (make-binding sym sym 'quote)
      value: value))

  (define (make-rest-binding rest)
    (make-binding rest rest 'rest))

  
  (define (hide-binding! binding)
    (object-set! binding symbol: #f)
    binding)


  (define (binding? binding)
    (and (object? binding)
         (defined? binding.symbol)
         (defined? binding.alias)
         (defined? binding.tag)))

  
  (define (definition-binding? binding)
    (and (binding? binding)
         (eq? binding.tag 'definition)))

  (define (formal-binding? binding)
    (and (binding? binding)
         (eq? binding.tag 'formal)))

  (define (let-binding? binding)
    (and (binding? binding)
         (eq? binding.tag 'let)))

  (define (quote-binding? binding)
    (and (binding? binding)
         (eq? binding.tag 'quote)))

  (define (rest-binding? binding)
    (and (binding? binding)
         (eq? binding.tag 'rest)))


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
          (add-binding! ctx rest (make-rest-binding rest)))
        
        (context-extend! ctx
          tail: #t
          formals: formals
          rest: rest
          temporaries: '()
          recursive: #f))))


  (define (make-let-context stx ctx)
    (let ([let-ctx (make-parse-context stx ctx 'let)])
      (for-all (lambda (sym)
                 (add-binding! let-ctx sym (make-let-binding sym)))
               (cadar stx))
      (context-extend! let-ctx
        tail: (tail-context? ctx))))

  
  (define (make-non-tail-context stx ctx)
    (let ([ctx (make-parse-context stx ctx 'non-tail)])
      (context-extend! ctx
        tail: #f)))


  (define (definition-context? ctx)
    (or (lambda-context? ctx)
        (let-context? ctx)
        (root-context? ctx)))

  (define (lambda-context? ctx)
    (eq? (context-tag ctx) 'lambda))

  (define (let-context? ctx)
    (eq? (context-tag ctx) 'let))

  (define (quote-context? ctx)
    (root-context? ctx))

  (define (set-context? ctx)
    (eq? (context-tag ctx) 'set))

  (define (recursive-lambda-context? ctx)
    (and (lambda-context? ctx)
         (context-ref ctx recursive:)))

  (define (root-context? ctx)
    (eq? (context-tag ctx) 'root))

  (define (tail-context? ctx)
    (context-ref ctx tail:))

  
  (define (add-definition! ctx target)
    (let ([def-ctx (find definition-context? (context-stack ctx))])
      (unless (assoc target (context-local-bindings def-ctx))
        (when (trace)
          (printf "add-definition!: adding %s to a %s\n" target (context-ref def-ctx tag:)))
        (add-binding! def-ctx target (if (root-context? def-ctx)
                                         (make-definition-binding target)
                                         (make-local-definition-binding target))))))

  (define (add-quote! ctx symbol value)
    (add-binding! (find quote-context? (context-stack ctx))
                  symbol
                  (make-quote-binding symbol value)))


  (define (get-definitions ctx)
    (filter definition-binding?
            (map cdr (context-local-bindings ctx))))

  (define (get-quotes ctx)
    (filter quote-binding?
            (map cdr (context-local-bindings ctx))))
  
  (define (get-subordinated-lets ctx)
    (filter let-binding?
            (map cdr (context-local-bindings ctx))))

  
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
      (find (lambda (ctx)
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

                [(eq? applicand 'IF)
                 (apply append (map value-set (cddr x)))]

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
                 (list x)]))))


  (define (set-context-recurring! ctx)
    (assert (lambda-context? ctx) "set-context-recurring!: ctx not lambda context")
    (unless (recursive-lambda-context? ctx)
      (context-extend! ctx
        recursive:       #t
        result-symbol:   (gensym "$R")
        continue-symbol: (gensym "$C")
        temporaries:     (map (lambda (formal)
                                (cons formal (gensym formal)))
                              (context-ref ctx formals:)))))

  (module special-forms

    (export *)

    (define (AND stx ctx)
      (when (trace)
        (printf "%s %s\n" stx (map context-tag (context-stack ctx))))
      (assert (proper-list? stx) (format "syntax error: and form must be a proper list: %s" stx))
      (if (null? (cdr stx))
          '(LITERAL #t)
          (let ([non-tail-ctx (make-non-tail-context stx ctx)]
                [stx-params-r (reverse (cdr stx))])
            (let loop ([params (map (lambda (stx)
                                      (precedence-bracket 'STRICTLY-EQUAL
                                                          (parse stx non-tail-ctx)))
                                    (cdr stx-params-r))]
                       [result (parse (car stx-params-r) ctx)])
              (if (null? params)
                  result
                  (loop (cdr params)
                        `(CONDITIONAL (STRICTLY-EQUAL ,(car params)
                                                      (LITERAL #f))
                                      (LITERAL #f)
                                      ,result)))))))



    (define (BEGIN stx ctx)
      (when (trace)
        (printf "%s %s\n" stx (map context-tag (context-stack ctx))))
      (assert (proper-list? stx) (format "syntax error: begin form must be a proper list: %s" stx))
      (cond [(null? (cdr stx))
             '(LITERAL #u)]

            [(null? (cddr stx))
             (parse (cadr stx) ctx)]

            [#t
             `(SEQUENCE ,@(parse-tailed-sequence (cdr stx) ctx))]))


    (define (DEFINE stx ctx)
      (when (trace)
        (printf "%s %s\n" stx (map context-tag (context-stack ctx))))
      (assert (proper-list? stx) (format "syntax error: define form must be a proper list: %s" stx))
      (assert (and (= 2 (length stx))
                   (symbol? (cadr stx)))
              (format "syntax error: define form requires a single symbol (not %s): %s"
                      (- (length stx) 1) stx))

      (add-definition! ctx (cadr stx))
      '(LITERAL #u))
    

    (define (IF stx ctx)
      (when (trace)
        (printf "%s %s\n" stx (map context-tag (context-stack ctx))))
      (assert (proper-list? stx) (format "syntax error: if form must be a proper list: %s" stx))
      (assert (= 4 (length stx)) (format "syntax error: if form requires three subforms (not %s): %s"
                                         (- (length stx) 1) stx))

      `(CONDITIONAL ,(precedence-bracket 'CONDITIONAL
                                         (parse (cadr stx) (make-non-tail-context stx ctx)))
                    ,@(map (lambda (stx)
                             (precedence-bracket 'CONDITIONAL
                                                 (parse stx ctx)))
                           (cddr stx))))


    (define (LAMBDA stx ctx)
      (when (trace)
        (printf "%s %s\n" stx (map context-tag (context-stack ctx))))
      (assert (proper-list? stx) (format "syntax error: lambda form must be a proper list: %s" stx))
      (assert (<= 3 (length stx)) (format "syntax error: lambda form requires at least two subforms (not %s): %s"
                                          (- (length stx) 1) stx))
      (let-values ([(formals rest) (rectify (cadr stx))])
        (assert (and (for-all simple-symbol? formals)
                     (or (null? rest)
                         (simple-symbol? rest)))
                (format "syntax error: the formal parameters of a lambda form are expected to be a symbol, a list of symbols, or a dotted list of symbols: %s"
                        stx))

        (let* ([ctx (make-lambda-context stx ctx)]
               ;;[dummy (print "+")]
               [value-exprs (let ([body (parse-tailed-sequence (cddr stx) ctx)])
                              ;; explicitly recursive lambdas rename their parameters
                              ;; so that they can be expressed as while loops, this may
                              ;; require reparsing of expressions involving those parameters
                              ;; that occur lexically prior to the first recursive call,
                              ;; as the symbols referencing function arguments in the emitted code
                              ;; will be different.
                              (if (recursive-lambda-context? ctx)
                                  (parse-tailed-sequence (cddr stx) ctx)
                                  body))]
               ;;[dummy (print "*")]
               [value (case (length value-exprs)
                        [(0) '()]
                        [(1) (car value-exprs)]
                        [else
                         `(SEQUENCE ,@value-exprs)])]
               [recursive? (recursive-lambda-context? ctx)]
               [body (if recursive?
                         (let ([result-symbol (context-ref ctx result-symbol:)])
                           `((STATEMENT (WHILE (STRICTLY-EQUAL
                                                (PAREN
                                                 (ASSIGN (IDENTIFIER ,result-symbol)
                                                         ,(precedence-bracket 'ASSIGN value)))
                                                (IDENTIFIER ,(context-ref ctx continue-symbol:)))
                                               () ))
                             (STATEMENT (RETURN (IDENTIFIER ,result-symbol)))))
                         `((STATEMENT (RETURN ,value))))]
               ;;[dummy (print "*")]
               [rest-binding (if (null? rest)
                                 '()
                                 `(((IDENTIFIER ,rest) 
                                    (CALL (IDENTIFIER "$arglist")
                                          ((IDENTIFIER "arguments")
                                           (LITERAL ,(length formals)))))))]
               ;;[dummy (print "*")]
               [recursive-bindings (if (not (recursive-lambda-context? ctx))
                                       '()
                                       (append (map (lambda (temp)
                                                      `(IDENTIFIER ,(cdr temp)))
                                                    (context-ref ctx temporaries:))
                                               `((IDENTIFIER ,(context-ref ctx result-symbol:))
                                                 ((IDENTIFIER ,(context-ref ctx continue-symbol:))
                                                  (CALL (IDENTIFIER Object)
                                                        ())))))]
               ;;[dummy (print "*")]
               [definition-bindings (map (lambda (binding)
                                           `(IDENTIFIER ,binding.alias))
                                         (get-definitions ctx))]
               ;;[dummy (print "*")]
               [let-bindings (map (lambda (binding)
                                    `(IDENTIFIER ,binding.alias))
                                  (get-subordinated-lets ctx))]
               
               ;;[dummy (print "*")]
               [all-bindings (append rest-binding recursive-bindings
                                     definition-bindings let-bindings)]
               ;;[dummy (print "*")]
               [bindings (if (= 0 (length all-bindings))
                             '()
                             `((STATEMENT (VAR ,all-bindings))))])
          ;;(print "+")
          `(FUNCTION #f ,(map (lambda (formal)
                                `(IDENTIFIER ,formal))
                              formals)
                     ,(append bindings body)))))


    (define (OR stx ctx)
      (when (trace)
        (printf "%s %s\n" stx (map context-tag (context-stack ctx))))
      (assert (proper-list? stx) (format "syntax error: or form must be a proper list: %s" stx))
      (if (null? (cdr stx))
          '(LITERAL #f)
          (let ([stx-params-r (reverse (cdr stx))])
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
      (when (trace)
        (printf "%s %s\n" stx (map context-tag (context-stack ctx))))
      (assert (proper-list? stx) (format "syntax error: quasiquote form must be a proper list: %s" stx))
      (assert (= 2 (length stx)) (format "syntax error: quasiquote form requires one value (not %s): %s"
                                         (- (length stx) 1) stx))
      
      (let* ([ctx (make-non-tail-context stx ctx)]
             [lambdas '()]
             [quoted (let loop ([stx (cadr stx)])
                       (if (not (pair? stx))
                           stx
                           (let ([A (car stx)])
                             (cond [(or (eq? A 'unquote-splicing)
                                        (eq? A 'unquote))
                                    (set! lambdas (cons (parse `(LAMBDA () ,@(cdr stx)) ctx)
                                                        lambdas))
                                    (list A)]

                                   [(eq? A 'quasiquote)
                                    stx]

                                   [#t
                                    (cons (loop A) (loop (cdr stx)))]))))]
             [quote-exp (parse `(QUOTE ,quoted) ctx)])
        (if (null? lambdas)
            quote-exp
            `(CALL (IDENTIFIER "$QU")
                   (,quote-exp ,(reverse lambdas))))))


    (define (QUOTE stx ctx)
      (when (trace)
        (printf "%s %s\n" stx (map context-tag (context-stack ctx))))
      (assert (proper-list? stx) (format "syntax error: quote form must be a proper list: %s" stx))
      (assert (= 2 (length stx)) (format "syntax error: quote form requires one value (not %s): %s"
                                         (- (length stx) 1) stx))
      (let ([quoted (let loop ([stx (cadr stx)])
                      (cond [(null? stx)
                             `(IDENTIFIER "$nil")]

                            [(list? stx)
                             `(CALL (IDENTIFIER "cons")
                                    (,(loop (car stx))
                                     ,(loop (cdr stx))))]

                            [#t
                             `(LITERAL ,stx)]))])
        (if (pair? (cadr stx))
            (let ([sym (gensym 'quote)])
              (add-quote! ctx sym quoted)
              `(IDENTIFIER ,sym))
            quoted)))


    (define (SET! stx ctx)
      (when (trace)
        (printf "%s %s\n" stx (map context-tag (context-stack ctx))))
      (assert (proper-list? stx) (format "syntax error: set form must be a proper list: %s" stx))
      (assert (= 3 (length stx)) (format "syntax error: set form requires two parts (not %s): %s"
                                         (- (length stx) 1) stx))
      (assert (symbol? (cadr stx)) (format "syntax error: set form requires that its first component is a symbol: %s"
                                           stx))

      (let ([target (cadr stx)])
        (let ([ctx (make-set-context stx ctx)]
              [value-form (caddr stx)])
          `(ASSIGN ,(parse-symbol target ctx)
                   ,(precedence-bracket 'ASSIGN (parse value-form
                                                       (make-non-tail-context value-form ctx)))))))

    (define parsers
      `((AND        . ,AND)
        (BEGIN      . ,BEGIN)
        (DEFINE     . ,DEFINE)
        (IF         . ,IF)
        (LAMBDA     . ,LAMBDA)
        (OR         . ,OR)
        (QUASIQUOTE . ,QUASIQUOTE)
        (QUOTE      . ,QUOTE)
        (SET!       . ,SET!)))


    "End Module special-forms")

  (define-macro (off stx)
    #u)
  
;;  (off
   (module test
     (define-macro (trial stx)
       `(begin
          (assert ,@(cdr stx) (format "%s failed" ',@(cdr stx)))
          #t))

     (define-macro (fail stx)
       `(assert (eq? 'exception (except (lambda (e) 'exception)
                                  ,@(cdr stx)))
                (format "%s failed" ',@(cdr stx))))

     (let ([binding (make-binding 'foo 'bar 'test)])
       (trial (eq? (object-ref binding symbol:) 'foo))
       (trial (eq? (object-ref binding alias:) 'bar))
       (trial (eq? (object-ref binding tag:) 'test))
       (trial (binding? binding)))
     
     (let ([binding (make-definition-binding 'foo)])
       (trial (eq? (object-ref binding symbol:) 'foo))
       (trial (eq? (object-ref binding alias:) 'foo))
       (trial (eq? (object-ref binding tag:) 'definition))
       (trial (definition-binding? binding))
       (trial (not (formal-binding? binding)))
       (trial (not (let-binding? binding)))
       (trial (not (quote-binding? binding)))
       (trial (not (rest-binding? binding))))

     (let ([binding (make-local-definition-binding 'foo)])
       (trial (eq? (object-ref binding symbol:) 'foo))
       (trial (not (eq? (object-ref binding alias:) 'foo)))
       (trial (eq? (object-ref binding tag:) 'definition))
       (trial (definition-binding? binding))
       (trial (not (formal-binding? binding)))
       (trial (not (let-binding? binding)))
       (trial (not (quote-binding? binding)))
       (trial (not (rest-binding? binding))))

     (let ([binding (make-formal-binding 'foo)])
       (trial (eq? (object-ref binding symbol:) 'foo))
       (trial (eq? (object-ref binding alias:) 'foo))
       (trial (eq? (object-ref binding tag:) 'formal))
       (trial (not (definition-binding? binding)))
       (trial (formal-binding? binding))
       (trial (not (let-binding? binding)))
       (trial (not (quote-binding? binding)))
       (trial (not (rest-binding? binding))))

     (let ([binding (make-let-binding 'foo)])
       (trial (eq? (object-ref binding symbol:) 'foo))
       (trial (not (eq? (object-ref binding alias:) 'foo)))
       (trial (eq? (object-ref binding tag:) 'let))
       (trial (not (definition-binding? binding)))
       (trial (not (formal-binding? binding)))
       (trial (let-binding? binding))
       (trial (not (quote-binding? binding)))
       (trial (not (rest-binding? binding))))

     (let ([binding (make-quote-binding 'foo 2)])
       (trial (eq? (object-ref binding symbol:) 'foo))
       (trial (eq? (object-ref binding alias:) 'foo))
       (trial (eq? (object-ref binding tag:) 'quote))
       (trial (eq? (object-ref binding value:) 2))
       (trial (not (definition-binding? binding)))
       (trial (not (formal-binding? binding)))
       (trial (not (let-binding? binding)))
       (trial (quote-binding? binding))
       (trial (not (rest-binding? binding))))

     (let ([binding (make-rest-binding 'foo)])
       (trial (eq? (object-ref binding symbol:) 'foo))
       (trial (eq? (object-ref binding alias:) 'foo))
       (trial (eq? (object-ref binding tag:) 'rest))
       (trial (not (definition-binding? binding)))
       (trial (not (formal-binding? binding)))
       (trial (not (let-binding? binding)))
       (trial (rest-binding? binding)))

     (let* ([recurring-form '(foo t bar)]
            [let-form `((LAMBDA (t) ,recurring-form) 1)]
            [lambda-form `(LAMBDA (bar . baz) ,let-form)]
            [value-form lambda-form]
            [set-form `(SET! foo ,value-form)]
            [stx set-form]
            [root-context     (make-root-context     stx)]
            [set-context      (make-set-context      set-form    root-context)]
            [non-tail-context (make-non-tail-context value-form  set-context)]
            [lambda-context   (make-lambda-context   lambda-form non-tail-context)]
            [let-context      (make-let-context      let-form    lambda-context)])

       (trial (defined? definition-context?))
       (trial (defined? lambda-context?))
       (trial (defined? quote-context?))
       (trial (defined? set-context?))
       (trial (defined? recursive-lambda-context?))
       (trial (defined? root-context?))
       (trial (defined? tail-context?))
       (trial (defined? context-tag))

       (trial (defined? root-context))
       (trial (defined? set-context))
       (trial (defined? non-tail-context))
       (trial (defined? lambda-context))
       (trial (defined? let-context))
       
       (trial (definition-context? root-context))
       (trial (not (lambda-context? root-context)))
       (trial (quote-context? root-context))
       (trial (not (set-context? root-context)))
       (trial (not (let-context? root-context)))
       (trial (not (recursive-lambda-context? root-context)))
       (trial (root-context? root-context))
       (trial (not (tail-context? root-context)))

       (trial (not (definition-context? set-context)))
       (trial (not (lambda-context? set-context)))
       (trial (not (quote-context? set-context)))
       (trial (set-context? set-context))
       (trial (not (let-context? set-context)))
       (trial (not (recursive-lambda-context? set-context)))
       (trial (not (root-context? set-context)))
       (trial (not (tail-context? set-context)))

       (trial (not (definition-context? non-tail-context)))
       (trial (not (lambda-context? non-tail-context)))
       (trial (not (quote-context? non-tail-context)))
       (trial (not (set-context? non-tail-context)))
       (trial (not (let-context? non-tail-context)))
       (trial (not (recursive-lambda-context? non-tail-context)))
       (trial (not (root-context? non-tail-context)))
       (trial (not (tail-context? non-tail-context)))

       (trial (definition-context? lambda-context))
       (trial (lambda-context? lambda-context))
       (trial (not (quote-context? lambda-context)))
       (trial (not (set-context? lambda-context)))
       (trial (not (let-context? lambda-context)))
       (trial (not (recursive-lambda-context? lambda-context)))
       (trial (not (root-context? lambda-context)))
       (trial (tail-context? lambda-context))

       (trial (definition-context? let-context))
       (trial (not (lambda-context? let-context)))
       (trial (not (quote-context? let-context)))
       (trial (not (set-context? let-context)))
       (trial (let-context? let-context))
       (trial (not (recursive-lambda-context? let-context)))
       (trial (not (root-context? let-context)))
       (trial (tail-context? let-context))

       (trial (eq? (context-ref root-context kernel:) parse-kernel))
       (trial (eq? (context-ref set-context kernel:) parse-kernel))
       (trial (eq? (context-ref non-tail-context kernel:) parse-kernel))
       (trial (eq? (context-ref lambda-context kernel:) parse-kernel))
       (trial (eq? (context-ref let-context kernel:) parse-kernel))
       
       (trial (eq? (context-tag root-context) 'root))
       (trial (eq? (context-ref root-context tail:) #f))

       (trial (eq? (context-tag set-context) 'set))
       (trial (eq? (context-ref set-context tail:) #f))
       (trial (eq? (context-ref set-context target:) 'foo))
       (trial (eq? (context-ref set-context value:) value-form))
       
       (trial (eq? (context-tag lambda-context) 'lambda))
       (trial (eq? (context-ref lambda-context tail:) #t))
       (trial (equal? (context-ref lambda-context formals:) '(bar)))
       (trial (eq? (context-ref lambda-context rest:) 'baz))
       (trial (eq? (context-ref lambda-context temporaries:) '()))
       (trial (eq? (context-ref lambda-context recursive:) #f))
       
       (trial (eq? (context-tag let-context) 'let))

       (trial (= 0 (length (context-local-bindings root-context))))
       (trial (= 0 (length (context-local-bindings set-context))))
       (trial (= 0 (length (context-local-bindings non-tail-context))))
       (trial (= 2 (length (context-local-bindings lambda-context))))
       (trial (= 1 (length (context-local-bindings let-context))))

       (trial (= 0 (length (context-bindings root-context))))
       (trial (= 0 (length (context-bindings set-context))))
       (trial (= 0 (length (context-bindings non-tail-context))))
       (trial (= 2 (length (context-bindings lambda-context))))
       (trial (= 3 (length (context-bindings let-context))))

       (trial (not (get-binding root-context 'bar)))
       (trial (not (get-binding root-context 'baz)))
       (trial (not (get-binding root-context 't)))
       
       (trial (not (get-binding set-context 'bar)))
       (trial (not (get-binding set-context 'baz)))
       (trial (not (get-binding set-context 't)))
       
       (trial (not (get-binding non-tail-context 'bar)))
       (trial (not (get-binding non-tail-context 'baz)))
       (trial (not (get-binding non-tail-context 't)))
       
       (trial (get-binding lambda-context 'bar))
       (trial (get-binding lambda-context 'baz))
       (trial (not (get-binding lambda-context 't)))
       
       (trial (get-binding let-context 'bar))
       (trial (get-binding let-context 'baz))
       (trial (get-binding let-context 't))

       (trial (eq? (context-alias let-context 'bar) 'bar))
       (trial (eq? (context-alias let-context 'baz) 'baz))
       (trial (not (eq? (context-alias let-context 't) 't)))

       (trial (formal-binding? (get-binding let-context 'bar)))
       (trial (rest-binding? (get-binding let-context 'baz)))
       (trial (let-binding? (get-binding let-context 't)))

       (trial (eq? (find-set-context let-context 'foo) set-context))

       (trial (= 0 (length (get-definitions root-context))))
       (trial (= 0 (length (get-definitions set-context))))
       (trial (= 0 (length (get-definitions non-tail-context))))
       (trial (= 0 (length (get-definitions lambda-context))))
       (trial (= 0 (length (get-definitions let-context))))

       (add-definition! root-context     'root-def)
       (add-definition! set-context      'set-def)
       (add-definition! non-tail-context 'non-tail-def)
       (add-definition! lambda-context   'lambda-def)
       (add-definition! let-context      'let-def)

       (trial (= 3 (length (get-definitions root-context))))
       (trial (= 0 (length (get-definitions set-context))))
       (trial (= 0 (length (get-definitions non-tail-context))))
       (trial (= 1 (length (get-definitions lambda-context))))
       (trial (= 1 (length (get-definitions let-context))))

       (trial (= 0 (length (get-quotes root-context))))
       (trial (= 0 (length (get-quotes set-context))))
       (trial (= 0 (length (get-quotes non-tail-context))))
       (trial (= 0 (length (get-quotes lambda-context))))
       (trial (= 0 (length (get-quotes let-context))))

       (add-quote! root-context     'root-quote)
       (add-quote! set-context      'set-quote)
       (add-quote! non-tail-context 'non-tail-quote)
       (add-quote! lambda-context   'lambda-quote)
       (add-quote! let-context      'let-quote)

       (trial (= 5 (length (get-quotes root-context))))
       (trial (= 0 (length (get-quotes set-context))))
       (trial (= 0 (length (get-quotes non-tail-context))))
       (trial (= 0 (length (get-quotes lambda-context))))
       (trial (= 0 (length (get-quotes let-context))))

       (trial (= 0 (length (value-set stx))))
       (trial (= 0 (length (value-set set-form))))
       (trial (= 1 (length (value-set value-form))))
       (trial (= 1 (length (value-set lambda-form))))
       (trial (= 1 (length (value-set let-form))))

       (trial (eq? (find-recurring-lambda-context set-form recurring-form let-context)
                   lambda-context))

       (set-context-recurring! lambda-context)

       (trial (eq? (context-ref lambda-context recursive:) #t))
       (trial (symbol? (context-ref lambda-context result-symbol:)))
       (trial (symbol? (context-ref lambda-context continue-symbol:)))
       (trial (= (length (context-ref lambda-context temporaries:))
                 (length (context-ref lambda-context formals:)))))

     (let ([value-forms (value-set 'foo)])
       (trial (equal? value-forms '(foo))))

     (let ([value-forms (value-set '(foo bar 1 2))])
       (trial (equal? value-forms '((foo bar 1 2)))))
     
     (let ([value-forms (value-set '(AND a b c))])
       (trial (= 3 (length value-forms)))
       (trial (memq 'a value-forms))
       (trial (memq 'b value-forms))
       (trial (memq 'c value-forms)))

     (let ([value-forms (value-set '(BEGIN a b c))])
       (trial (= 1 (length value-forms)))
       (trial (memq 'c value-forms)))

     (let ([value-forms (value-set '(DEFINE a))])
       (trial (= 0 (length value-forms))))

     (let ([value-forms (value-set '(IF a b c))])
       (trial (= 2 (length value-forms)))
       (trial (memq 'b value-forms))
       (trial (memq 'c value-forms)))

     (let ([value-forms (value-set '(LAMBDA a b c))])
       (trial (= 1 (length value-forms)))
       (trial (equal? value-forms '((LAMBDA a b c)))))

     (let ([value-forms (value-set '(OR a b c))])
       (trial (= 3 (length value-forms)))
       (trial (memq 'a value-forms))
       (trial (memq 'b value-forms))
       (trial (memq 'c value-forms)))

     (let ([value-forms (value-set '(QUASIQUOTE foo))])
       (trial (= 1 (length value-forms)))
       (trial (equal? value-forms '((QUASIQUOTE foo)))))

     (let ([value-forms (value-set '(QUOTE foo))])
       (trial (= 1 (length value-forms)))
       (trial (equal? value-forms '((QUOTE foo)))))

     (let ([value-forms (value-set '(SET! a))])
       (trial (= 0 (length value-forms))))
     

     (let ([value-forms (value-set '(AND (BEGIN a b c)
                                         (DEFINE d)
                                         (IF e f g)))])
       (trial (= 3 (length value-forms)))
       (trial (memq 'c value-forms))
       (trial (memq 'f value-forms))
       (trial (memq 'g value-forms)))

     (let ([value-forms (value-set '(BEGIN (LAMBDA a b c)
                                           (OR d e f)
                                           (QUASIQUOTE g)))])
       (trial (= 1 (length value-forms)))
       (trial (equal? value-forms '((QUASIQUOTE g)))))

     (let ([value-forms (value-set '(IF (QUOTE a b c)
                                        (SET! d e f)
                                        (AND g h i)))])
       (trial (= 3 (length value-forms)))
       (trial (memq 'g value-forms))
       (trial (memq 'h value-forms))
       (trial (memq 'i value-forms)))

     (let ([value-forms (value-set '(OR (DEFINE a)
                                        (IF b c d)
                                        (LAMBDA e f g)))])
       (trial (= 3 (length value-forms)))
       (trial (memq 'c value-forms))
       (trial (memq 'd value-forms))
       (trial (member '(LAMBDA e f g) value-forms)))


     (let ([value-forms (value-set '((LAMBDA (foo) bar) 7))])
       (trial (= 1 (length value-forms)))
       (trial (memq 'bar value-forms)))

     (let ([value-forms (value-set '((AND (BEGIN a b c)
                                          (LAMBDA (foo)
                                                  (BEGIN (LAMBDA a b c)
                                                         (OR d e f)
                                                         (QUASIQUOTE g)))
                                          (IF e f g)) 7))])
       (trial (= 1 (length value-forms)))
       (trial (equal? value-forms '((QUASIQUOTE g)))))


     (let ([value-forms (value-set '((IF (QUOTE a b c)
                                         (LAMBDA (foo)
                                                 (OR (DEFINE a)
                                                     (IF b c d)
                                                     (LAMBDA e f g)))
                                         (LAMBDA (foo) bar)) "six by nine"))])
       (trial (= 4 (length value-forms)))
       (trial (memq 'c value-forms))
       (trial (memq 'd value-forms))
       (trial (member '(LAMBDA e f g) value-forms))
       (trial (memq 'bar value-forms)))


     (let ([value-forms (value-set '((IF (QUOTE a b c)
                                         (LAMBDA (foo)
                                                 (OR (DEFINE a)
                                                     (IF b c d)
                                                     ((LAMBDA e f g) h)))
                                         foo-bar) "six by nine"))])
       (trial (= 3 (length value-forms)))
       (trial (memq 'c value-forms))
       (trial (memq 'd value-forms))
       (trial (memq 'g value-forms)))

     (let* ([ctx (make-root-context '())]
            [lambda-ctx1 (make-lambda-context '(lambda (foo) foo.bar) ctx)]
            [lambda-ctx2 (make-lambda-context '(lambda (f-o-o) f-o-o.bar) ctx)])
       
       (trial (equal? (parse-symbol 'foo ctx)
                      '(IDENTIFIER foo)))
       (trial (equal? (parse-symbol 'foo.bar ctx)
                      '(MEMBER-LIT (IDENTIFIER foo) (IDENTIFIER "bar"))))
       (trial (equal? (parse-symbol 'foo.bar* ctx)
                      '(MEMBER-EXP (IDENTIFIER foo) (LITERAL "bar*"))))
       (trial (equal? (parse-symbol 'foo.bar*.baz ctx)
                      '(MEMBER-LIT (MEMBER-EXP (IDENTIFIER foo) (LITERAL "bar*")) (IDENTIFIER "baz"))))

       (trial (equal? (parse-symbol 'f-o-o ctx)
                      '(MEMBER-EXP (IDENTIFIER "$") (LITERAL "f-o-o"))))
       (trial (equal? (parse-symbol 'f-o-o.bar ctx)
                      '(MEMBER-LIT (MEMBER-EXP (IDENTIFIER "$") (LITERAL "f-o-o")) (IDENTIFIER "bar"))))
       (trial (equal? (parse-symbol 'f-o-o.bar* ctx)
                      '(MEMBER-EXP (MEMBER-EXP (IDENTIFIER "$") (LITERAL "f-o-o")) (LITERAL "bar*"))))
       (trial (equal? (parse-symbol 'f-o-o.bar*.baz ctx)
                      '(MEMBER-LIT
                        (MEMBER-EXP
                         (MEMBER-EXP (IDENTIFIER "$") (LITERAL "f-o-o"))
                         (LITERAL "bar*"))
                        (IDENTIFIER "baz"))))

       (trial (equal? (parse-symbol 'foo lambda-ctx1)
                      '(IDENTIFIER foo)))
       (trial (equal? (parse-symbol 'foo.bar lambda-ctx1)
                      '(MEMBER-LIT (IDENTIFIER foo) (IDENTIFIER "bar"))))
       (trial (equal? (parse-symbol 'foo.bar* lambda-ctx1)
                      '(MEMBER-EXP (IDENTIFIER foo) (LITERAL "bar*"))))
       (trial (equal? (parse-symbol 'foo.bar*.baz lambda-ctx1)
                      '(MEMBER-LIT (MEMBER-EXP (IDENTIFIER foo) (LITERAL "bar*")) (IDENTIFIER "baz"))))


       (trial (equal? (parse-symbol 'f-o-o lambda-ctx2)
                      '(IDENTIFIER "f$45o$45o")))
       (trial (equal? (parse-symbol 'f-o-o.bar lambda-ctx2)
                      '(MEMBER-LIT (IDENTIFIER "f$45o$45o") (IDENTIFIER "bar"))))
       (trial (equal? (parse-symbol 'f-o-o.bar* lambda-ctx2)
                      '(MEMBER-EXP (IDENTIFIER "f$45o$45o") (LITERAL "bar*"))))
       (trial (equal? (parse-symbol 'f-o-o.bar*.baz lambda-ctx2)
                      '(MEMBER-LIT (MEMBER-EXP (IDENTIFIER "f$45o$45o") (LITERAL "bar*")) (IDENTIFIER "baz")))))

     (trial (eq? (assoc-ref 'AND        special-forms.parsers) special-forms.AND))
     (trial (eq? (assoc-ref 'BEGIN      special-forms.parsers) special-forms.BEGIN))
     (trial (eq? (assoc-ref 'DEFINE     special-forms.parsers) special-forms.DEFINE))
     (trial (eq? (assoc-ref 'IF         special-forms.parsers) special-forms.IF))
     (trial (eq? (assoc-ref 'LAMBDA     special-forms.parsers) special-forms.LAMBDA))
     (trial (eq? (assoc-ref 'OR         special-forms.parsers) special-forms.OR))
     (trial (eq? (assoc-ref 'QUASIQUOTE special-forms.parsers) special-forms.QUASIQUOTE))
     (trial (eq? (assoc-ref 'QUOTE      special-forms.parsers) special-forms.QUOTE))
     (trial (eq? (assoc-ref 'SET!       special-forms.parsers) special-forms.SET!))

     (let* ([stx '(AND)]
            [ctx (make-root-context stx)]
            [result (special-forms.AND stx ctx)])
       (trial (equal? result '(LITERAL #t))))
     
     (let* ([stx '(AND foo)]
            [ctx (make-root-context stx)]
            [result (special-forms.AND stx ctx)])
       (trial (equal? result '(IDENTIFIER foo))))
     
     (let* ([stx '(AND foo bar)]
            [ctx (make-root-context stx)]
            [result (special-forms.AND stx ctx)])
       (trial (equal? result '(CONDITIONAL (STRICTLY-EQUAL (IDENTIFIER foo)
                                                           (LITERAL #f))
                                           (LITERAL #f)
                                           (IDENTIFIER bar)))))

     (let* ([stx '(BEGIN)]
            [ctx (make-root-context stx)]
            [result (special-forms.BEGIN stx ctx)])
       (trial (equal? result '(LITERAL #u))))

     (let* ([stx '(BEGIN foo)]
            [ctx (make-root-context stx)]
            [result (special-forms.BEGIN stx ctx)])
       (trial (equal? result '(IDENTIFIER foo))))

     (let* ([stx '(BEGIN foo bar)]
            [ctx (make-root-context stx)]
            [result (special-forms.BEGIN stx ctx)])
       (trial (equal? result '(SEQUENCE (IDENTIFIER foo) (IDENTIFIER bar)))))

     (let* ([stx '(BEGIN #t (AND foo bar))]
            [ctx (make-root-context stx)]
            [result (special-forms.BEGIN stx ctx)])
       (trial (equal? result '(SEQUENCE (LITERAL #t)
                                        (CONDITIONAL (STRICTLY-EQUAL (IDENTIFIER foo)
                                                                     (LITERAL #f))
                                                     (LITERAL #f)
                                                     (IDENTIFIER bar))))))

     (let ([ctx (make-root-context '())])
       (fail (special.forms.DEFINE '(DEFINE) ctx))
       (fail (special.forms.DEFINE '(DEFINE foo bar) ctx))
       (fail (special.forms.DEFINE '(DEFINE "symbol-required") ctx))
       (fail (special.forms.DEFINE '(DEFINE (symbol required)) ctx)))
     

     (let ([define-form '(DEFINE foo)])
       (let* ([stx `(LAMBDA (bar) ,define-form)]
              [root-ctx (make-root-context stx)]
              [ctx (make-lambda-context stx root-ctx)]
              [result (special-forms.DEFINE define-form ctx)])
         
         (trial (= 0 (length (get-definitions root-ctx))))
         
         (trial (equal? result '(LITERAL #u)))
         (trial (= 1 (length (get-definitions ctx))))
         (trial (get-binding ctx 'foo))
         (trial (definition-binding? (get-binding ctx 'foo))))

       (let* ([stx `((LAMBDA (bar) ,define-form) 'baz)]
              [root-ctx (make-root-context stx)]
              [ctx (make-let-context stx root-ctx)]
              [result (special-forms.DEFINE define-form ctx)])
         
         (trial (= 0 (length (get-definitions root-ctx))))
         
         (trial (equal? result '(LITERAL #u)))
         (trial (= 1 (length (get-definitions ctx))))
         (trial (get-binding ctx 'foo))
         (trial (definition-binding? (get-binding ctx 'foo))))

       (let* ([stx `(SET! bar ,define-form)]
              [root-ctx (make-root-context stx)]
              [ctx (make-set-context stx root-ctx)]
              [result (special-forms.DEFINE define-form ctx)])
         
         (trial (= 0 (length (get-definitions ctx))))
         
         (trial (equal? result '(LITERAL #u)))
         (trial (= 1 (length (get-definitions root-ctx))))
         (trial (get-binding root-ctx 'foo))
         (trial (definition-binding? (get-binding root-ctx 'foo))))
       

       (let* ([stx `(AND ,define-form 'bar)]
              [root-ctx (make-root-context stx)]
              [ctx (make-non-tail-context stx root-ctx)]
              [result (special-forms.DEFINE define-form ctx)])
         
         (trial (= 0 (length (get-definitions ctx))))
         
         (trial (equal? result '(LITERAL #u)))
         (trial (= 1 (length (get-definitions root-ctx))))
         (trial (get-binding root-ctx 'foo))
         (trial (definition-binding? (get-binding root-ctx 'foo)))))

     (let* ([stx '(IF)]
            [ctx (make-root-context stx)])
       (fail (special-forms.IF stx ctx)))

     (let* ([stx '(IF a)]
            [ctx (make-root-context stx)])
       (fail (special-forms.IF stx ctx)))

     (let* ([stx '(IF a b)]
            [ctx (make-root-context stx)])
       (fail (special-forms.IF stx ctx)))

     (let* ([stx '(IF a b c d)]
            [ctx (make-root-context stx)])
       (fail (special-forms.IF stx ctx)))

     (let* ([stx '(IF a b c)]
            [ctx (make-root-context stx)]
            [result (special-forms.IF stx ctx)])
       (trial (equal? result '(CONDITIONAL (IDENTIFIER a) (IDENTIFIER b) (IDENTIFIER c)))))


     (let* ([stx '(LAMBDA (x) #t)]
            [ctx (make-root-context stx)])
       (fail (special-forms.LAMBDA '(LAMBDA 3 #t) ctx))
       (fail (special-forms.LAMBDA '(LAMBDA x) ctx))
       (fail (special-forms.LAMBDA '(LAMBDA (3) x) ctx))
       (fail (special-forms.LAMBDA '(LAMBDA (a 3) x) ctx))
       (fail (special-forms.LAMBDA '(LAMBDA (a . "hello") x) ctx))
       (fail (special-forms.LAMBDA '(LAMBDA ((list a)) x) ctx)))
     

     (let* ([stx '(LAMBDA (x) #t)]
            [ctx (make-root-context stx)]
            [result (special-forms.LAMBDA stx ctx)])
       ;;(printf "%s\n" result)
       (trial (equal? result '(FUNCTION #f ((IDENTIFIER x)) ((STATEMENT (RETURN (LITERAL #t)))))
                      )))

     (let* ([stx '(LAMBDA (x y) foo)]
            [ctx (make-root-context stx)]
            [result (special-forms.LAMBDA stx ctx)])
       ;;(printf "%s\n" result)
       (trial (equal? result '(FUNCTION #f ((IDENTIFIER x) (IDENTIFIER y))
                                        ((STATEMENT (RETURN (IDENTIFIER foo))))))))

     (let* ([stx '(LAMBDA x foo)]
            [ctx (make-root-context stx)]
            [result (special-forms.LAMBDA stx ctx)])
       ;;(printf "%s\n" result)
       (trial (equal? result '(FUNCTION #f ()
                                        ((STATEMENT (VAR (((IDENTIFIER x) (CALL (IDENTIFIER "$arglist")
                                                                                ((IDENTIFIER arguments)
                                                                                 (LITERAL 0)))))))
                                         (STATEMENT (RETURN (IDENTIFIER foo))))))))

     (let* ([stx '(LAMBDA (x . y) foo)]
            [ctx (make-root-context stx)]
            [result (special-forms.LAMBDA stx ctx)])
       (trial (equal? result '(FUNCTION #f ((IDENTIFIER x))
                                        ((STATEMENT (VAR (((IDENTIFIER y) (CALL (IDENTIFIER "$arglist")
                                                                                ((IDENTIFIER arguments)
                                                                                 (LITERAL 1)))))))
                                         (STATEMENT (RETURN (IDENTIFIER foo))))))))

     (let* ([stx '(OR)]
            [ctx (make-root-context stx)]
            [result (special-forms.OR stx ctx)])
       (trial (equal? result '(LITERAL #f))))
     
     (let* ([stx '(OR foo)]
            [ctx (make-root-context stx)]
            [result (special-forms.OR stx ctx)])
       (trial (equal? result '(IDENTIFIER foo))))
     
     (let* ([stx '(OR foo bar)]
            [ctx (make-root-context stx)]
            [result (special-forms.OR stx ctx)])
       (trial (equal? result '(CONDITIONAL (NOT-STRICTLY-EQUAL (PAREN (ASSIGN (IDENTIFIER "$temp")
                                                                              (IDENTIFIER foo)))
                                                               (LITERAL #f))
                                           (IDENTIFIER "$temp")
                                           (IDENTIFIER bar)))))

     (let* ([stx '(QUOTE (x) #t)]
            [ctx (make-root-context stx)])
       (fail (special-forms.QUOTE '(QUOTE) ctx))
       (fail (special-forms.QUOTE '(QUOTE foo bar) ctx)))
     
     (let* ([stx '(QUOTE foo)]
            [ctx (make-root-context stx)]
            [result (special-forms.QUOTE stx ctx)])
       (trial (equal? result '(LITERAL foo))))

     (let* ([stx '(QUOTE "ten")]
            [ctx (make-root-context stx)]
            [result (special-forms.QUOTE stx ctx)])
       (trial (equal? result '(LITERAL "ten"))))

     (let* ([stx '(QUOTE 2)]
            [ctx (make-root-context stx)]
            [result (special-forms.QUOTE stx ctx)])
       (trial (equal? result '(LITERAL 2))))

     (let* ([stx '(QUOTE ())]
            [ctx (make-root-context stx)]
            [result (special-forms.QUOTE stx ctx)])
       (trial (equal? result '(IDENTIFIER "$nil"))))

     (let* ([stx '(QUOTE (apples))]
            [ctx (make-root-context stx)]
            [result (special-forms.QUOTE stx ctx)])
       (trial (eq? (car result) 'IDENTIFIER))
       (let ([binding (get-binding ctx (cadr result))])
         (trial (equal? binding.value '(CALL (IDENTIFIER "cons")
                                             ((LITERAL apples)
                                              (IDENTIFIER "$nil")))))))

     (let* ([stx '(QUASIQUOTE (x) #t)]
            [ctx (make-root-context stx)])
       (fail (special-forms.QUASIQUOTE '(QUASIQUOTE) ctx))
       (fail (special-forms.QUASIQUOTE '(QUASIQUOTE foo bar) ctx)))
     
     (let* ([stx '(QUASIQUOTE foo)]
            [ctx (make-root-context stx)]
            [result (special-forms.QUASIQUOTE stx ctx)])
       (trial (equal? result '(LITERAL foo))))


     (let* ([stx '(QUASIQUOTE (apples))]
            [ctx (make-root-context stx)]
            [result (special-forms.QUASIQUOTE stx ctx)])
       (trial (eq? (car result) 'IDENTIFIER))
       (let ([binding (get-binding ctx (cadr result))])
         (trial (equal? binding.value '(CALL (IDENTIFIER "cons")
                                             ((LITERAL apples)
                                              (IDENTIFIER "$nil")))))))

     (let* ([stx '(QUASIQUOTE (apples ,oranges))]
            [ctx (make-root-context stx)]
            [result (special-forms.QUASIQUOTE stx ctx)])
       ;;       (CALL (IDENTIFIER "$QU")
       ;;             ((IDENTIFIER $quote_804)
       ;;              ((FUNCTION #f () ((STATEMENT (RETURN (IDENTIFIER oranges))))))))
       (trial (list? result))
       (trial (= 3 (length result)))
       (trial (equal? (take 2 result)
                      '(CALL (IDENTIFIER "$QU"))))
       (let ([params (caddr result)])
         (trial (list? params))
         (trial (= 2 (length params)))
         (trial (eq? 'IDENTIFIER (caar params)))
         (trial (equal? (cadr params)
                        '((FUNCTION #f () ((STATEMENT (RETURN (IDENTIFIER oranges))))))))
         (let ([binding (get-binding ctx (cadar params))])
           (trial (equal? binding.value '(CALL (IDENTIFIER "cons")
                                               ((LITERAL apples)
                                                (CALL (IDENTIFIER "cons")
                                                      ((CALL (IDENTIFIER "cons")
                                                             ((LITERAL unquote)
                                                              (IDENTIFIER "$nil")))
                                                       (IDENTIFIER "$nil"))))))))))


     (let* ([stx '(QUASIQUOTE (`(no ,change) ,@(foo bar)))]
            [ctx (make-root-context stx)]
            [result (special-forms.QUASIQUOTE stx ctx)])
       ;;(CALL (IDENTIFIER "$QU")
       ;;      ((IDENTIFIER $quote_804)
       ;;       ((FUNCTION #f () ((STATEMENT 
       ;;                          (RETURN (CALL (IDENTIFIER foo)
       ;;                                        ((IDENTIFIER bar))))))))))
       (trial (list? result))
       (trial (= 3 (length result)))
       (trial (equal? (take 2 result)
                      '(CALL (IDENTIFIER "$QU"))))
       (let ([params (caddr result)])
         (trial (list? params))
         (trial (= 2 (length params)))
         (trial (eq? 'IDENTIFIER (caar params)))
         (trial (equal? (cadr params)
                        '((FUNCTION #f () ((STATEMENT 
                                            (RETURN (CALL (IDENTIFIER foo)
                                                          ((IDENTIFIER bar))))))))))
         (let ([binding (get-binding ctx (cadar params))])
           (trial (equal? binding.value '(CALL (IDENTIFIER "cons")
                                               ((CALL (IDENTIFIER "cons")
                                                      ((LITERAL quasiquote)
                                                       (CALL (IDENTIFIER "cons")
                                                             ((CALL (IDENTIFIER "cons")
                                                                    ((LITERAL no)
                                                                     (CALL (IDENTIFIER "cons")
                                                                           ((CALL (IDENTIFIER "cons")
                                                                                  ((LITERAL unquote)
                                                                                   (CALL (IDENTIFIER "cons")
                                                                                         ((LITERAL change)
                                                                                          (IDENTIFIER "$nil")))))
                                                                            (IDENTIFIER "$nil")))))
                                                              (IDENTIFIER "$nil")))))
                                                (CALL (IDENTIFIER "cons")
                                                      ((CALL (IDENTIFIER "cons")
                                                             ((LITERAL unquote-splicing)
                                                              (IDENTIFIER "$nil")))
                                                       (IDENTIFIER "$nil"))))))))))

     (let* ([stx '(SET! (x) #t)]
            [ctx (make-root-context stx)])
       (fail (special-forms.SET! '(SET!) ctx))
       (fail (special-forms.SET! '(SET! foo) ctx))
       (fail (special-forms.SET! '(SET! foo bar baz) ctx))
       (fail (special-forms.SET! '(SET! 2 bar) ctx))
       (fail (special-forms.SET! '(SET! "hello" bar) ctx))
       (fail (special-forms.SET! '(SET! (car args) bar) ctx)))


     (let* ([stx '(SET! foo #t)]
            [ctx (make-root-context stx)]
            [result (special-forms.SET! stx ctx)])
       (trial (equal? result
                      '(ASSIGN (IDENTIFIER foo)
                               (LITERAL #t)))))
     

     (let* ([stx '(SET! foo.bar* #t)]
            [ctx (make-root-context stx)]
            [result (special-forms.SET! stx ctx)])
       (trial (equal? result
                      '(ASSIGN (MEMBER-EXP (IDENTIFIER foo)
                                           (LITERAL "bar*"))
                               (LITERAL #t)))))
     

     (let* ([stx '(SET! foo.bar* (AND a b))]
            [ctx (make-root-context stx)]
            [result (special-forms.SET! stx ctx)])
       (trial (equal? result
                      '(ASSIGN (MEMBER-EXP (IDENTIFIER foo)
                                           (LITERAL "bar*"))
                               (PAREN
                                (CONDITIONAL (STRICTLY-EQUAL (IDENTIFIER a)
                                                             (LITERAL #f))
                                             (LITERAL #f)
                                             (IDENTIFIER b)))))))
     
     (let* ([stx '(foo)]
            [ctx (make-root-context stx)]
            [result (parse-application stx ctx)])
       (trial (equal? result
                      '(CALL (IDENTIFIER foo) ()))))

     (let* ([stx '(foo 12 bar)]
            [ctx (make-root-context stx)]
            [result (parse-application stx ctx)])
       (trial (equal? result
                      '(CALL (IDENTIFIER foo)
                             ((LITERAL 12)
                              (IDENTIFIER bar))))))

     (let* ([stx '((AND foo bar) (QUOTE baz))]
            [ctx (make-root-context stx)]
            [result (parse-application stx ctx)])
       (trial (equal? result
                      '(CALL
                        (PAREN (CONDITIONAL (STRICTLY-EQUAL (IDENTIFIER foo)
                                                            (LITERAL #f))
                                            (LITERAL #f)
                                            (IDENTIFIER bar))
                               ((LITERAL baz)))))))

     (let* ([stx '((LAMBDA (foo) (bar foo)) "Foo")]
            [ctx (make-root-context stx)]
            [result (parse-let-form stx ctx)])
       ;; (SEQUENCE (ASSIGN (IDENTIFIER $foo_860)
       ;;                   (LITERAL "Foo"))
       ;;           (CALL (IDENTIFIER bar) ((IDENTIFIER $foo_860))))
       (trial (= 3 (length result)))
       (trial (eq? 'SEQUENCE (car result)))
       (trial (eq? 'ASSIGN (caadr result)))
       (trial (eq? 'IDENTIFIER (caadr (cadr result))))
       (trial (equal? '(LITERAL "Foo") (caddr (cadr result))))
       (trial (eq? 'CALL (car (caddr result))))
       (trial (equal? '(IDENTIFIER bar) (cadr (caddr result))))
       (trial (equal? (cadr (cadr result))
                      (car (caddr (caddr result))))))

     (let* ([recurring-form '(foo 7)]
            [lambda-form `(LAMBDA (x) ,recurring-form)]
            [stx `(SET! foo ,lambda-form)]
            [root-ctx (make-root-context stx)]
            [set-ctx (make-set-context stx root-ctx)]
            [non-tail-ctx (make-non-tail-context lambda-form set-ctx)]
            [lambda-ctx (make-lambda-context lambda-form non-tail-ctx)]
            [result (parse-application recurring-form lambda-ctx)])
       (trial (eq? 'SEQUENCE (car result)))
       (let ([temp-assign (cadr result)]
             [formal-assign (caddr result)])
         (trial (eq? 'ASSIGN (car temp-assign)))
         (trial (eq? 'IDENTIFIER (caadr temp-assign)))
         (trial (equal? '(LITERAL 7) (caddr temp-assign)))
         (trial (eq? 'ASSIGN (car formal-assign)))
         (trial (equal? '(IDENTIFIER x) (cadr formal-assign)))
         (trial (eq? 'IDENTIFIER (caaddr formal-assign)))
         (trial (equal? (cadr temp-assign) (caddr formal-assign))))
       (let ([continue-token (cadddr result)])
         (trial (eq? 'IDENTIFIER (car continue-token)))
         (trial (eq? (context-ref lambda-ctx continue-symbol:)
                     (cadr continue-token))))
       (trial (recursive-lambda-context? lambda-ctx))
       (trial (= 1 (length (context-ref lambda-ctx temporaries:))))
       (trial (defined? (context-ref lambda-ctx continue-symbol:))))
     
     
     (let* ([recurring-form '(foo 7)]
            [lambda-form `(LAMBDA (x) ,recurring-form)]
            [stx `(SET! foo ,lambda-form)]
            [root-ctx (make-root-context stx)]
            [set-ctx (make-set-context stx root-ctx)]
            [non-tail-ctx (make-non-tail-context lambda-form set-ctx)]
            [result (special-forms.LAMBDA lambda-form non-tail-ctx)])
       ;;(printf "%s\n" result)
       (trial (eq? 'FUNCTION (car result)))
       (trial (equal? '((IDENTIFIER x)) (caddr result)))
       (let* ([body (and
                     (trial (and (list? result) (= 4 (length result))))
                     (trial (eq? 'FUNCTION (car result)))
                     (trial (eq? #f (cadr result)))
                     (trial (equal? '((IDENTIFIER x)) (caddr result)))
                     (cadddr result))]
              [var-stmt (and
                         ;;(printf "body: %s\n" body)
                         (trial (and (list? body) (= 3 (length body))))
                         (car body))]
              [vars (and
                     ;;(printf "var-stmt: %s\n" var-stmt)
                     (trial (and (list? var-stmt) (= 2 (length var-stmt))))
                     (trial (eq? 'STATEMENT (car var-stmt)))
                     (trial (and (list? (cadr var-stmt)) (= 2 (length (cadr var-stmt)))))
                     (trial (eq? 'VAR (caadr var-stmt)))
                     (cadadr var-stmt))]
              [continue-token (let ([result (find (lambda (binding)
                                                    (equal? (cadr binding)
                                                            '(CALL (IDENTIFIER Object) () )))
                                                  vars)])
                                ;;(printf "vars: %s\n" vars)
                                (trial result)
                                (car result))]
              [while-stmt (cadr body)]
              [while-condition (and
                                ;;(printf "while-stmt: %s\n" while-stmt)
                                (trial (and (list? while-stmt) (= 2 (length while-stmt))))
                                (trial (eq? 'STATEMENT (car while-stmt)))
                                (trial (and (list? (cadr while-stmt)) (= 3 (length (cadr while-stmt)))))
                                (trial (eq? 'WHILE (caadr while-stmt)))
                                (trial (null? (caddr (cadr while-stmt)))) ;; while body is empty
                                (cadadr while-stmt))]
              ;;`((STATEMENT (WHILE (STRICTLY-EQUAL
              ;;                     (PAREN
              ;;                      (ASSIGN (IDENTIFIER ,result-symbol)
              ;;                              ,(precedence-bracket 'ASSIGN value)))
              ;;                     (IDENTIFIER ,(context-ref ctx continue-symbol:)))
              ;;                    () ))
              ;;  (STATEMENT (RETURN (IDENTIFIER ,result-symbol))))
              [continue-symbol (and
                                ;;(printf "while-condition: %s\n" while-condition)
                                (trial (and (list? while-condition) (= 3 (length while-condition))))
                                (trial (eq? 'STRICTLY-EQUAL (car while-condition)))
                                (trial (and (list? (caddr while-condition)) (= 2 (length (caddr while-condition)))))
                                (trial (eq? 'IDENTIFIER (caaddr while-condition)))
                                (cadr (caddr while-condition)))]
              [result-assign (and
                              ;;(printf "continue-symbol: %s\n" continue-symbol)
                              (trial (and (list? (cadr while-condition)) (= 2 (length (cadr while-condition)))))
                              (trial (eq? 'PAREN (caadr while-condition)))
                              (cadadr while-condition))]
              [result-symbol (and
                              ;;(printf "result-assign: %s\n" result-assign)
                              (trial (and (list? result-assign) (= 3 (length result-assign))))
                              (trial (eq? 'ASSIGN (car result-assign)))
                              (trial (and (list? (cadr result-assign)) (= 2 (length (cadr result-assign)))))
                              (trial (eq? 'IDENTIFIER (caadr result-assign)))
                              (cadadr result-assign))]
              [return-stmt (caddr body)]
              [return-value (and
                             ;;(printf "return-stmt: %s\n" return-stmt)
                             (trial (and (list? return-stmt) (= 2 (length return-stmt))))
                             (trial (eq? 'STATEMENT (car return-stmt)))
                             (trial (and (list? (cadr return-stmt)) (= 2 (length (cadr return-stmt)))))
                             (trial (eq? 'RETURN (caadr return-stmt)))
                             (cadadr return-stmt))]
              [return-symbol (and
                              ;;(printf "return-value: %s\n" return-value)
                              (trial (and (list? return-value) (= 2 (length return-value))))
                              (trial (eq? 'IDENTIFIER (car return-value)))
                              (cadr return-value))])
         
         ;;(printf "return-value: %s\n" return-value)
         (trial (find (lambda (var-spec)
                        ;;(printf "--%s\n" var-spec)
                        (and (list? var-spec)
                             (= 2 (length var-spec))
                             (list? (car var-spec))
                             (eq? 'IDENTIFIER (caar var-spec))
                             (eq? continue-symbol (cadar var-spec))))
                      vars))
         (trial (eq? result-symbol return-symbol))
         (trial (member `(IDENTIFIER ,return-symbol) vars))))

     
     (let* ([recurring-form '(foo 1 2 3)]
            [lambda-form `(LAMBDA x ,recurring-form)]
            [stx `(SET! foo ,lambda-form)]
            [root-ctx (make-root-context stx)]
            [set-ctx (make-set-context stx root-ctx)]
            [non-tail-ctx (make-non-tail-context lambda-form set-ctx)]
            [lambda-ctx (make-lambda-context lambda-form non-tail-ctx)]
            [result (parse-application recurring-form lambda-ctx)])
       (trial (eq? 'SEQUENCE (car result)))
       (let ([rest-assign (cadr result)])
         (trial (equal? rest-assign
                        '(ASSIGN (IDENTIFIER x)
                                 (CALL (IDENTIFIER list)
                                       ((LITERAL 1) (LITERAL 2) (LITERAL 3)))))))
       (let ([continue-token (caddr result)])
         (trial (eq? 'IDENTIFIER (car continue-token)))
         (trial (eq? (context-ref lambda-ctx continue-symbol:)
                     (cadr continue-token)))))

     (define (test-tco-form quasi-form)
       (let* ([recurring-form '(foo 1 2 3)]
              [parent-form (quasi-unquote quasi-form recurring-form)]
              [lambda-form `(LAMBDA (a . x) ,parent-form)]
              [stx `(SET! foo ,lambda-form)]
              [root-ctx (make-root-context stx)]
              [set-ctx (make-set-context stx root-ctx)]
              [non-tail-ctx (make-non-tail-context lambda-form set-ctx)]
              [lambda-ctx (make-lambda-context lambda-form non-tail-ctx)]
              [result (parse parent-form lambda-ctx)])
         (trial (recursive-lambda-context? lambda-ctx))))

     (test-tco-form '(AND #t ,x))
     (fail (test-tco-form '(AND ,x #t)))

     (test-tco-form '(BEGIN #t ,x))
     (fail (test-tco-form '(BEGIN ,x #t)))

     (fail (test-tco-form '(IF ,x a b)))
     (test-tco-form '(IF t ,x  b))
     (test-tco-form '(IF t a ,x))

     (fail (test-tco-form '(LAMBDA (y) ,x)))
     (test-tco-form '((LAMBDA (y) ,x) 7))
     
     (test-tco-form '(OR #f ,x))
     (fail (test-tco-form '(OR ,x #f)))

     (fail (test-tco-form '(QUOTE ,x)))

     (fail (test-tco-form '(SET! bar ,x)))

     (fail (text-tco-form '(,x a)))
     (fail (text-tco-form '(a ,x)))

     (define (test-root-definition form)
       (let* ([ctx (make-root-context form)]
              [definitions (and (parse form ctx)
                                (get-definitions ctx))])
         (trial (= 1 (length definitions)))
         (trial (eq? 'X (object-ref (car definitions) symbol:)))
         (trial (get-binding ctx 'X))))

     (test-root-definition '(DEFINE X))
     
     (test-root-definition '(AND (DEFINE X) A))
     (test-root-definition '(AND A (DEFINE X)))
     (test-root-definition '(BEGIN (DEFINE X) A))
     (test-root-definition '(BEGIN A (DEFINE X)))
     (test-root-definition '(IF (DEFINE X) A B))
     (test-root-definition '(IF T (DEFINE X) B))
     (test-root-definition '(IF T A (DEFINE X)))
     (fail (test-root-definition '(LAMBDA () (DEFINE X))))
     (test-root-definition '(OR (DEFINE X) A))
     (test-root-definition '(OR A (DEFINE X)))
     (test-root-definition '(SET! A (DEFINE X)))

     (define (test-lambda-definition form)
       (let* ([ctx (make-root-context form)]
              [lambda-ctx (make-lambda-context form ctx)]
              [definitions (and (parse (caddr form) lambda-ctx)
                                (get-definitions lambda-ctx))])
         (trial (null? (get-definitions ctx)))
         
         (trial (= 1 (length definitions)))
         (trial (eq? 'X (object-ref (car definitions) symbol:)))
         (trial (get-binding lambda-ctx 'X))))

     (test-lambda-definition '(LAMBDA () (AND (DEFINE X) A)))
     (test-lambda-definition '(LAMBDA () (AND A (DEFINE X))))
     (test-lambda-definition '(LAMBDA () (BEGIN (DEFINE X) A)))
     (test-lambda-definition '(LAMBDA () (BEGIN A (DEFINE X))))
     (test-lambda-definition '(LAMBDA () (IF (DEFINE X) A B)))
     (test-lambda-definition '(LAMBDA () (IF T (DEFINE X) B)))
     (test-lambda-definition '(LAMBDA () (IF T A (DEFINE X))))
     (fail (test-lambda-definition '(LAMBDA () (LAMBDA () (DEFINE X)))))
     (test-lambda-definition '(LAMBDA () (OR (DEFINE X) A)))
     (test-lambda-definition '(LAMBDA () (OR A (DEFINE X))))
     (test-lambda-definition '(LAMBDA () (SET! A (DEFINE X))))


     (define (test-let-definition form)
       (let* ([ctx (make-root-context form)]
              [definitions (and (parse form ctx)
                                (get-definitions ctx))])
         
         (trial (= 1 (length definitions)))
         (trial (eq? 'X (object-ref (car definitions) symbol:)))
         (trial (not (get-binding ctx 'X)))))

     (test-let-definition '((LAMBDA () (AND (DEFINE X) A))))
     (test-let-definition '((LAMBDA () (AND A (DEFINE X)))))
     (test-let-definition '((LAMBDA () (BEGIN (DEFINE X) A))))
     (test-let-definition '((LAMBDA () (BEGIN A (DEFINE X)))))
     (test-let-definition '((LAMBDA () (IF (DEFINE X) A B))))
     (test-let-definition '((LAMBDA () (IF T (DEFINE X) B))))
     (test-let-definition '((LAMBDA () (IF T A (DEFINE X)))))
     (fail (test-let-definition '((LAMBDA () (LAMBDA () (DEFINE X))))))
     (test-let-definition '((LAMBDA () (OR (DEFINE X) A))))
     (test-let-definition '((LAMBDA () (OR A (DEFINE X)))))
     (test-let-definition '((LAMBDA () (SET! A (DEFINE X)))))


     (let* ([stx '(LAMBDA () (DEFINE X) (SET! X 0))]
            [ctx (make-root-context stx)]
            [result (parse stx ctx)])
       ;;(printf "%s\n" result)
       (let* ([body (and
                     (trial (and (list? result) (= 4 (length result))))
                     (trial (eq? 'FUNCTION (car result)))
                     (trial (eq? #f (cadr result)))
                     (trial (null? (caddr result)))
                     (cadddr result))]
              [var-stmt (and
                         ;;(printf "body: %s\n" body)
                         (trial (and (list? body) (= 2 (length body))))
                         (car body))]
              [vars (and
                     ;;(printf "var-stmt: %s\n" var-stmt)
                     (trial (and (list? var-stmt) (= 2 (length var-stmt))))
                     (trial (eq? 'STATEMENT (car var-stmt)))
                     (trial (and (list? (cadr var-stmt)) (= 2 (length (cadr var-stmt)))))
                     (trial (eq? 'VAR (caadr var-stmt)))
                     (cadadr var-stmt))]
              [defined-symbol (and
                               ;;(printf "vars: %s\n" vars)
                               (trial (and (list? vars) (= 1 (length vars))))
                               (eq? 'IDENTIFIER (caar vars))
                               (cadar vars))]
              [return-stmt (cadr body)]
              [return-value (and
                             ;;(printf "return-stmt: %s\n" return-stmt)
                             (trial (and (list? return-stmt) (= 2 (length return-stmt))))
                             (trial (eq? 'STATEMENT (car return-stmt)))
                             (trial (and (list? (cadr return-stmt)) (= 2 (length (cadr return-stmt)))))
                             (trial (eq? 'RETURN (caadr return-stmt)))
                             (cadadr return-stmt))]
              [assign-expr (and
                            ;;(printf "return-value: %s\n" return-value)
                            (trial (and (list? return-value) (= 3 (length return-value))))
                            (trial (eq? 'SEQUENCE (car return-value)))
                            (caddr return-value))]
              [define-target (and
                              ;;(printf "assign-expr: %s\n" assign-expr)
                              (trial (and (list? assign-expr) (= 3 (length assign-expr))))
                              (trial (eq? 'ASSIGN (car assign-expr)))
                              (trial (and (list? (cadr assign-expr)) (= 2 (length (cadr assign-expr)))))
                              (trial (eq? 'IDENTIFIER (caadr assign-expr)))
                              (cadadr assign-expr))])
         ;;(printf "defined-symbol: %s\n" defined-symbol)
         ;;(printf "define-target: %s\n" define-target)
         (trial (eq? defined-symbol define-target))))

     ;;(trace #t)
     (let* ([stx '(LAMBDA (X) ((LAMBDA (Y) (DEFINE X) (SET! X 0)) X))]
            [ctx (make-root-context stx)]
            [result (parse stx ctx)])
       ;;(printf "%s\n" result)
       (let* ([body (and
                     (trial (and (list? result) (= 4 (length result))))
                     (trial (eq? 'FUNCTION (car result)))
                     (trial (eq? #f (cadr result)))
                     (trial (equal? '((IDENTIFIER X)) (caddr result)))
                     (cadddr result))]
              [var-stmt (and
                         ;;(printf "body: %s\n" body)
                         (trial (and (list? body) (= 2 (length body))))
                         (car body))]
              [vars (and
                     ;;(printf "var-stmt: %s\n" var-stmt)
                     (trial (and (list? var-stmt) (= 2 (length var-stmt))))
                     (trial (eq? 'STATEMENT (car var-stmt)))
                     (trial (and (list? (cadr var-stmt)) (= 2 (length (cadr var-stmt)))))
                     (trial (eq? 'VAR (caadr var-stmt)))
                     (cadadr var-stmt))]
              [defined-symbol (and
                               ;;(printf "vars: %s\n" vars)
                               (trial (and (list? vars) (= 2 (length vars))))
                               (eq? 'IDENTIFIER (caar vars))
                               (cadar vars))]
              [return-stmt (cadr body)]
              [return-value (and
                             ;;(printf "return-stmt: %s\n" return-stmt)
                             (trial (and (list? return-stmt) (= 2 (length return-stmt))))
                             (trial (eq? 'STATEMENT (car return-stmt)))
                             (trial (and (list? (cadr return-stmt)) (= 2 (length (cadr return-stmt)))))
                             (trial (eq? 'RETURN (caadr return-stmt)))
                             (cadadr return-stmt))]
              [local-assign-expr (and
                                  ;;(printf "return-value: %s\n" return-value)
                                  (trial (and (list? return-value) (= 4 (length return-value))))
                                  (trial (eq? 'SEQUENCE (car return-value)))
                                  (cadr return-value))]
              [local-target (and
                             ;;(printf "local-assign-expr: %s\n" local-assign-expr)
                             (trial (and (list? local-assign-expr) (= 3 (length local-assign-expr))))
                             (trial (eq? 'ASSIGN (car local-assign-expr)))
                             (trial (and (list? (cadr local-assign-expr)) (= 2 (length (cadr local-assign-expr)))))
                             (trial (eq? 'IDENTIFIER (caadr local-assign-expr)))
                             (cadadr local-assign-expr))]
              [define-assign-expr (cadddr return-value)]
              [define-target (and
                              ;;(printf "define-assign-expr: %s\n" define-assign-expr)
                              (trial (and (list? define-assign-expr) (= 3 (length define-assign-expr))))
                              (trial (eq? 'ASSIGN (car define-assign-expr)))
                              (trial (and (list? (cadr define-assign-expr)) (= 2 (length (cadr define-assign-expr)))))
                              (trial (eq? 'IDENTIFIER (caadr define-assign-expr)))
                              (cadadr define-assign-expr))])
         ;;(printf "define-target: %s\n" define-target)
         ;;(printf "local-target: %s\n" local-target)
         (trial (member `(IDENTIFIER ,define-target) vars))
         (trial (member `(IDENTIFIER ,local-target) vars))))
     
     
     ;;(trace #t)
     (let* ([stx '(LAMBDA (X)
                          (DEFINE X)
                          (SET! X 0)
                          (DEFINE X)
                          (SET! X 0))]
            [ctx (make-root-context stx)]
            [result (parse stx ctx)])
       ;;(printf "%s\n" result)
       (trial (equal? result
                      '(FUNCTION #f ((IDENTIFIER X))
                                 ((STATEMENT
                                   (RETURN
                                    (SEQUENCE
                                     (LITERAL #u)
                                     (ASSIGN
                                      (IDENTIFIER X)
                                      (LITERAL 0))
                                     (LITERAL #u)
                                     (ASSIGN
                                      (IDENTIFIER X)
                                      (LITERAL 0))))))))))
     
     (let* ([stx '(LAMBDA (Y)
                          (DEFINE X)
                          (SET! X 0)
                          (DEFINE X)
                          (SET! X 0))]
            [ctx (make-root-context stx)]
            [result (parse stx ctx)])
       ;;(printf "%s\n" result)
       (let* ([body (and
                     (trial (and (list? result) (= 4 (length result))))
                     (trial (eq? 'FUNCTION (car result)))
                     (trial (eq? #f (cadr result)))
                     (trial (equal? '((IDENTIFIER Y)) (caddr result)))
                     (cadddr result))]
              [var-stmt (and
                         ;;(printf "body: %s\n" body)
                         (trial (and (list? body) (= 2 (length body))))
                         (car body))]
              [vars (and
                     ;;(printf "var-stmt: %s\n" var-stmt)
                     (trial (and (list? var-stmt) (= 2 (length var-stmt))))
                     (trial (eq? 'STATEMENT (car var-stmt)))
                     (trial (and (list? (cadr var-stmt)) (= 2 (length (cadr var-stmt)))))
                     (trial (eq? 'VAR (caadr var-stmt)))
                     (cadadr var-stmt))]
              [defined-symbol (and
                               ;;(printf "vars: %s\n" vars)
                               (trial (and (list? vars) (= 1 (length vars))))
                               (eq? 'IDENTIFIER (caar vars))
                               (cadar vars))]
              [return-stmt (and
                            ;;(printf "defined-symbol: %s\n" defined-symbol)
                            (trial (and (list? body) (= 2 (length body))))
                            (cadr body))]
              [return-value (and
                             ;;(printf "return-stmt: %s\n" return-stmt)
                             (trial (and (list? return-stmt) (= 2 (length return-stmt))))
                             (trial (eq? 'STATEMENT (car return-stmt)))
                             (trial (and (list? (cadr return-stmt)) (= 2 (length (cadr return-stmt)))))
                             (trial (eq? 'RETURN (caadr return-stmt)))
                             (cadadr return-stmt))]
              [sequence-expr (and
                              ;;(printf "return-value: %s\n" return-value)
                              (trial (and (list? return-value) (= 5 (length return-value))))
                              (trial (eq? 'SEQUENCE (car return-value)))
                              (cdr return-value))]
              [def-assign1 (and
                            ;;(printf "sequence-expr: %s\n" sequence-expr)
                            (trial (and (list? (cadr sequence-expr)) (= 3 (length (cadr sequence-expr)))))
                            (trial (eq? 'ASSIGN (caadr sequence-expr)))
                            (cadr sequence-expr))]
              [def-assign2 (and
                            ;;(printf "def-assign1: %s\n" def-assign1)
                            (trial (and (list? (cadddr sequence-expr)) (= 3 (length (cadddr sequence-expr)))))
                            (trial (eq? 'ASSIGN (car (cadddr sequence-expr))))
                            (cadddr sequence-expr))])
         (trial (equal? def-assign1 def-assign2))
         (trial (eq? defined-symbol (cadr (cadr def-assign1))))))

     
     (let ([result (internal->target '(foo (QUOTE bar)))])
       (trial (equal? result
                      '(CALL (FUNCTION #f ()
                                       ((STATEMENT
                                         (RETURN
                                          (CALL (IDENTIFIER foo)
                                                ((LITERAL bar)))))))
                             () ))))
     
     (let* ([result (internal->target '(foo (QUOTE (bar soap))))]
            [function (and
                       ;;(printf "result: %s\n" result)
                       (trial (and (list? result) (= 3 (length result))))
                       (trial (eq? 'CALL (car result)))
                       (cadr result))]
            [body (and
                   ;;(printf "function: %s\n" function)
                   (trial (and (list? function) (= 4 (length function))))
                   (trial (eq? 'FUNCTION (car function)))
                   (trial (eq? #f (cadr function)))
                   (trial (null? (caddr function)))
                   (cadddr function))]
            [var-stmt (and
                       ;;(printf "body: %s\n" body)
                       (trial (and (list? body) (= 2 (length body))))
                       (car body))]
            [vars (and
                   ;;(printf "var-stmt: %s\n" var-stmt)
                   (trial (and (list? var-stmt) (= 2 (length var-stmt))))
                   (trial (eq? 'STATEMENT (car var-stmt)))
                   (trial (and (list? (cadr var-stmt)) (= 2 (length (cadr var-stmt)))))
                   (trial (eq? 'VAR (caadr var-stmt)))
                   (cadadr var-stmt))]
            [quote-decl (and
                         ;;(printf "vars: %s\n" vars)
                         (trial (and (list? vars) (= 1 (length vars))))
                         (car vars))]
            [quote-symbol (and
                           ;;(printf "quote-decl: %s\n" quote-decl)
                           (trial (and (list? quote-decl) (= 2 (length quote-decl))))
                           (eq? 'IDENTIFIER (caar quote-decl))
                           (cadar quote-decl))]
            [quote-value (and
                          ;;(printf "quote-symbol: %s\n" quote-symbol)
                          (cadr quote-decl))]
            [return-stmt (and
                          ;;(printf "quote-value: %s\n" quote-value)
                          (cadr body))]
            [return-value (and
                           ;;(printf "return-stmt: %s\n" return-stmt)
                           (trial (and (list? return-stmt) (= 2 (length return-stmt))))
                           (trial (eq? 'STATEMENT (car return-stmt)))
                           (trial (and (list? (cadr return-stmt)) (= 2 (length (cadr return-stmt)))))
                           (trial (eq? 'RETURN (caadr return-stmt)))
                           (cadadr return-stmt))]
            [call-arguments (and
                             ;;(printf "return-value: %s\n" return-value)
                             (trial (and (list return-value) (= 3 (length return-value))))
                             (trial (eq? 'CALL (car return-value)))
                             (trial (equal? (cadr return-value) '(IDENTIFIER foo)))
                             (trial (and (list? (caddr return-value)) (= 1 (length (caddr return-value)))))
                             (caddr return-value))]
            [referenced-symbol (and
                                ;;(printf "call-arguments: %s\n" call-arguments)
                                (trial (and (list? call-arguments) (= 1 (length call-arguments))))
                                (trial (and (list? (car call-arguments)) (= 2 (length (car call-arguments)))))
                                (trial (eq? 'IDENTIFIER (caar call-arguments)))
                                (cadar call-arguments))])
       (trial (equal? quote-value
                      '(CALL (IDENTIFIER "cons")
                             ((LITERAL bar)
                              (CALL (IDENTIFIER "cons")
                                    ((LITERAL soap)
                                     (IDENTIFIER "$nil")))))))
       (trial (eq? quote-symbol referenced-symbol)))
     

     ;; vectors
     ;; values
     
     "End Module test");)
  
  "END Module primitives")

