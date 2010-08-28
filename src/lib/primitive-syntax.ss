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
  ;;;  locate the lambda in V*((S ...)) which contains (S ...) in the transitive
  ;;;  closure of its subforms.
  ;;;
  ;;;  if one cannot be found, then it is not explict recurrence.
  ;;;
  ;;; recursion
  ;;;   when:
  ;;;     application of symbol
  ;;;     symbol is currently being defined
  ;;;     there is a path from the set! form to the application form
  ;;;       such that there is a lambda in value position.
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
           [env (let ([shell (make-module 'shell (current-module))])
                  (module-import shell `(special-forms . ,special-forms) #f '*)
                  shell)]
           [body (parse stx ctx env)]
           [decls (map (lambda (binding)
                         `(IDENTIFIER ,binding.alias))
                       (get-subordinated-lets ctx))]
           [quotes (map (lambda (binding)
                          `((IDENTIFIER ,binding.alias) ,binding.value))
                        (get-quotes ctx))]
           [all-bindings (append decls quotes)]
           [binding-stmts (if (= 0 (length all-bindings))
                              '()
                              `((STATEMENT (VAR ,all-bindings))))])
      `(CALL
        ,(precedence-bracket 'CALL
                             `(FUNCTION #f () ,(append binding-stmts `((STATEMENT (RETURN ,body))))))
        () )))


  (define (macro? x)
    (and (defined? x)
         (function? x)
         (default (object-ref x "$macro") #f)))


  (define (make-macro x)
    (when (and (defined? x)
               (function? x))
      (object-set! x "$macro" #t)))

  
  ;;--------------------------------------------------------------------------
  ;;
  ;; (parse-kernel stx ctx env)
  ;;
  ;; stx is syntax to be parsed by the primitive parser.
  ;;
  ;; ctx is the context in which the syntax occurs.
  ;;

  (define (get-macro-transformer name env)
    ;;    (printf "get-macro-transformer: %s %s\n" name (module-name env))
    (let ([v (default (object-ref env name) #f)])
      (and (macro? v) v)))

  
  (define (parse-kernel stx ctx env)
    (when (trace)
      (printf "parse-kernel: %s %s\n" stx (module-name env)))

    (if (not (pair? stx))
        (parse-value stx ctx env)

        (let ([key (car stx)])
          (if (not (symbol? key))

              (if (and (list? key)
                       (eq? (car key) 'lambda))
                  (parse-let-form stx ctx env)
                  (map (lambda (stx)
                         (parse stx ctx env))
                       stx))

              (cond [(get-macro-transformer key env)

                     => (lambda (macro-transformer)
                          (parse (macro-transformer stx) ctx env))]
                    

                    [(default (object-ref special-forms key) #f)

                     => (lambda (special-form)
                          (special-form stx ctx env))]

                    [#t
                     (parse-application stx ctx env)])))))
  

  ;;   (define (parse-kernel stx ctx)
  ;;     (let ([parser (if (pair? stx)
  ;;                       (if (symbol? (car stx))
  ;;                           (or (assoc-ref (car stx) special-forms.parsers)
  ;;                               parse-application)
  ;;                           (if (and (list? (car stx))
  ;;                                    (eq? (caar stx) 'lambda))
  ;;                               parse-let-form
  ;;                               parse-application))
  ;;                       parse-value)])
  ;;       (when (not (defined? parser))
  ;;         (printf "parse-kernel: stx: \n%s\n" stx))
  ;;       (assert (defined? parser) "parse-kernel: parser not defined")
  ;;       (parser stx ctx)))

  
  ;;--------------------------------------------------------------------------
  ;;
  ;; (parse-application stx ctx env)
  ;;
  ;; stx is syntax to be parsed by the primitive parser.  stx must be a list,
  ;; and not a primitive form, nor a let construct -- ((lambda ...) ...).
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
  ;; There is additional special handling for this in primitives.lambda.
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
  ;;   (set! foo (lambda (x)
  ;;               ((lambda (bar)
  ;;                  (set! bar (lambda (y)
  ;;                              (if y
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
  
  (define (parse-application stx ctx env)
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
                                (when (trace)
                                  (printf "recursive?: tag: %s\n" (context-tag c))
                                  (printf "recursive?: (eq? c recurrer-ctx): %s\n" (eq? c recurrer-ctx))
                                  (printf "recursive?: tail?: %s\n" (tail-context? c))
                                  (printf "recursive?: lambda?: %s\n" (lambda-context? c)))
                                (or (eq? c recurrer-ctx)
                                    (and (tail-context? c)
                                         (not (lambda-context? c))
                                         (loop (cdr cs)))))))]
           [non-tail-ctx (make-non-tail-context stx ctx)]
           [params (map (lambda (stx)
                          (parse stx non-tail-ctx env))
                        (cdr stx))])
      
      (if (not recursive?)
          `(CALL ,(precedence-bracket 'CALL
                                      (parse applicand non-tail-ctx env))
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


  (define (parse-let-form stx ctx env)
    (let* ([applicand (car stx)]
           [let-ctx (make-let-context stx ctx)]
           [locals (cadr applicand)]
           [body (map (lambda (stx)
                        (parse stx let-ctx env))
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
                                                          (parse actual ctx env))))
                          locals
                          (cdr stx))
                   ,@body))))

  
  (define (parse-tailed-sequence stx ctx env)
    (let ([non-tail-ctx (make-non-tail-context stx ctx)])
      (mapcdr (lambda (stx-cdr)
                (let ([stx (car stx-cdr)])
                  (parse stx (if (null? (cdr stx-cdr))
                                 ctx
                                 non-tail-ctx)
                         env)))
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
  
  
  (define (parse-value stx ctx env)
    (cond [(symbol? stx)
           (parse-symbol stx ctx env)]

          [(vector? stx)
           (parse-vector stx ctx env)]

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

  (define (parse-symbol sym ctx env)
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
                 
                 (if (and (identifier? base)
                          (or (not (set-context? ctx))
                              (not (eq? base (symbol->string (context-ref ctx target:))))))
                     `(IDENTIFIER ,base)
                     (let ([binding (get-binding ctx base)])
                       (if binding
                           `(IDENTIFIER ,(object-ref binding alias:)) ;make-identifier base))
                           `(MEMBER-EXP (IDENTIFIER "$") (LITERAL ,(symbol->string base))))))
                 (cdr components))))


  (define (parse-vector stx ctx env)
    (let ([ctx (make-non-tail-context stx ctx)])
      (list->vector (map (lambda (stx)
                           (parse stx ctx env))
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
    (make-binding formal (make-identifier formal) 'formal))

  (define (make-let-binding sym)
    (make-binding sym (gensym (make-identifier sym)) 'let))

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
      (unless (or (root-context? def-ctx)
                  (assoc target (context-local-bindings def-ctx)))
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
  ;;   where x is a lambda, quasiquote, or quote form; or
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
  ;;   where x_1 is either and or or.
  ;;
  ;; V(x) = { x_N }
  ;;   where x_1 is begin.
  ;;
  ;; V(x) = { }
  ;;   where x_1 is either define or set!.
  ;;
  ;; In the case where x_1 is a form, let v_j be the forms of V*(x_1)
  ;; such that each v_j is a form (v_j_1 ... v_j_N(j)) such that
  ;; v_j_1 = lambda, for j from 1 up to some M.  Then for such x,
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
          (cond [(member applicand '(lambda quasiquote quote))
                 (list x)]

                [(member applicand '(and or))
                 (apply append (map (lambda (sub-x)
                                      (value-set sub-x))
                                    (cdr x)))]

                [(eq? applicand 'begin)
                 (list (last x))]

                [(eq? applicand 'if)
                 (apply append (map value-set (cddr x)))]

                [(member applicand '(define set!))
                 '()]

                [(list? applicand)
                 (apply append (map (lambda (lm)
                                      (value-set (last lm)))
                                    (filter (lambda (vx)
                                              (and (pair? vx)
                                                   (eq? (car vx) 'lambda)))
                                            (value-set applicand))))]
                
                [#t
                 (list x)]))))


  (define (set-context-recurring! ctx)
    (assert (lambda-context? ctx) "set-context-recurring!: ctx not lambda context")
    (unless (recursive-lambda-context? ctx)
      (context-extend! ctx
        recursive:       #t
        result-symbol:   (gensym "R")
        continue-symbol: (gensym "C")
        temporaries:     (map (lambda (formal)
                                (cons formal (gensym (make-identifier formal))))
                              (context-ref ctx formals:)))))

  (module special-forms

    (export (AND        as and)
            (BEGIN      as begin)
            (DEFINE     as define)
            (IF         as if)
            (LAMBDA     as lambda)
            (OR         as or)
            (QUASIQUOTE as quasiquote)
            (QUOTE      as quote)
            (SET!       as set!))

    (define (AND stx ctx env)
      (when (trace)
        (printf "%s %s\n" stx (map context-tag (context-stack ctx))))
      (assert (proper-list? stx) (format "syntax error: and form must be a proper list: %s" stx))
      (if (null? (cdr stx))
          '(LITERAL #t)
          (let ([non-tail-ctx (make-non-tail-context stx ctx)]
                [stx-params-r (reverse (cdr stx))])
            (let loop ([params (map (lambda (stx)
                                      (precedence-bracket 'STRICTLY-EQUAL
                                                          (parse stx non-tail-ctx env)))
                                    (cdr stx-params-r))]
                       [result (parse (car stx-params-r) ctx env)])
              (if (null? params)
                  result
                  (loop (cdr params)
                        `(CONDITIONAL (STRICTLY-EQUAL ,(car params)
                                                      (LITERAL #f))
                                      (LITERAL #f)
                                      ,result)))))))



    (define (BEGIN stx ctx env)
      (when (trace)
        (printf "%s %s\n" stx (map context-tag (context-stack ctx))))
      (assert (proper-list? stx) (format "syntax error: begin form must be a proper list: %s" stx))
      (cond [(null? (cdr stx))
             '(LITERAL #u)]

            [(null? (cddr stx))
             (parse (cadr stx) ctx env)]

            [#t
             `(SEQUENCE ,@(parse-tailed-sequence (cdr stx) ctx env))]))


;;     (define (DEFINE stx)
;;       (when (trace)
;;         (printf "define: %s\n" stx))
;;       (let ([target (cadr stx)]
;;             [value (cddr stx)])
;;         (if (null? value)
;;             `(define ,target)
;;             (if (symbol? target)
;;                 `(begin
;;                    (define ,target)
;;                    (set! ,target ,@value))
;;                 (let ([target (car target)]
;;                       [formals (cdr target)])
;;                   `(begin
;;                      (define ,target)
;;                      (set! ,target (lambda ,formals ,@value))))))))

;;     (make-macro DEFINE)

;;     (define (DEFINE stx ctx env)
;;       (when (trace)
;;         (printf "%s %s\n" stx (map context-tag (context-stack ctx))))
;;       (assert (proper-list? stx) (format "syntax error: define form must be a proper list: %s" stx))
;;       (assert (and (= 2 (length stx))
;;                    (symbol? (cadr stx)))
;;               (format "syntax error: define form requires a single symbol (not %s): %s"
;;                       (- (length stx) 1) stx))

;;       (add-definition! ctx (cadr stx))
;;       '(LITERAL #u))
    

    (define (DEFINE stx ctx env)
      (when (trace)
        (printf "%s %s\n" stx (map context-tag (context-stack ctx))))
      (assert (proper-list? stx) (format "syntax error: define form must be a proper list: %s" stx))
;;       (assert (and (= 2 (length stx))
;;                    (symbol? (cadr stx)))
;;               (format "syntax error: define form requires a single symbol (not %s): %s"
;;                       (- (length stx) 1) stx))

      (let ([target (cadr stx)]
            [value (cddr stx)])
        (add-definition! ctx target)
        (cond [(null? value)
               (add-definition! ctx target)
               '(LITERAL #u)]

              [(symbol? target)
               (add-definition! ctx target)
               (SET! `(set! ,target ,@value) ctx env)]

              [#t
               (let ([target (car target)]
                     [formals (cdr target)])
                 (add-definition! ctx target)
                 (SET! `(set! ,target (lambda ,formals ,@value)) ctx env))])))
    

    (define (IF stx ctx env)
      (when (trace)
        (printf "%s %s\n" stx (map context-tag (context-stack ctx))))
      (assert (proper-list? stx) (format "syntax error: if form must be a proper list: %s" stx))
      (assert (= 4 (length stx)) (format "syntax error: if form requires three subforms (not %s): %s"
                                         (- (length stx) 1) stx))

      `(CONDITIONAL ,(precedence-bracket 'CONDITIONAL
                                         (parse (cadr stx) (make-non-tail-context stx ctx) env))
                    ,@(map (lambda (stx)
                             (precedence-bracket 'CONDITIONAL
                                                 (parse stx ctx env)))
                           (cddr stx))))

    (define (JS stx ctx env)
      stx)

    (define (LAMBDA stx ctx env)
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
               [value-exprs (let ([body (parse-tailed-sequence (cddr stx) ctx env)])
                              ;; explicitly recursive lambdas rename their parameters
                              ;; so that they can be expressed as while loops, this may
                              ;; require reparsing of expressions involving those parameters
                              ;; that occur lexically prior to the first recursive call,
                              ;; as the symbols referencing function arguments in the emitted code
                              ;; will be different.
                              (if (recursive-lambda-context? ctx)
                                  (parse-tailed-sequence (cddr stx) ctx env)
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
                                    (CALL (IDENTIFIER "$argumentsList")
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
                                (parse-symbol formal ctx env))
                              formals)
                     ,(append bindings body)))))


    (define (OR stx ctx env)
      (when (trace)
        (printf "%s %s\n" stx (map context-tag (context-stack ctx))))
      (assert (proper-list? stx) (format "syntax error: or form must be a proper list: %s" stx))
      (if (null? (cdr stx))
          '(LITERAL #f)
          (let ([stx-params-r (reverse (cdr stx))])
            (let loop ([params (let ([ctx (make-non-tail-context stx ctx)])
                                 (map (lambda (stx)
                                        (precedence-bracket 'ASSIGN
                                                            (parse stx ctx env)))
                                      (cdr stx-params-r)))]
                       [result (parse (car stx-params-r) ctx env)])
              (if (null? params)
                  result
                  (loop (cdr params)
                        `(CONDITIONAL (NOT-STRICTLY-EQUAL (PAREN (ASSIGN (IDENTIFIER "$temp") ,(car params)))
                                                          (LITERAL #f))
                                      (IDENTIFIER "$temp")
                                      ,result)))))))


    (define (QUASIQUOTE stx ctx env)
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
                                    (set! lambdas (cons (parse `(lambda () ,@(cdr stx)) ctx env)
                                                        lambdas))
                                    (list A)]

                                   [(eq? A 'quasiquote)
                                    stx]

                                   [#t
                                    (cons (loop A) (loop (cdr stx)))]))))]
             [quote-exp (parse `(quote ,quoted) ctx env)])
        (if (null? lambdas)
            quote-exp
            `(CALL (IDENTIFIER "$quasiUnquote")
                   (,quote-exp ,(reverse lambdas))))))


    (define (QUOTE stx ctx env)
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


    (define (SET! stx ctx env)
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
          `(ASSIGN ,(parse-symbol target ctx env)
                   ,(precedence-bracket 'ASSIGN (parse value-form
                                                       (make-non-tail-context value-form ctx)
                                                       env))))))


    "End Module special-forms")

  (module preamble
    
    (export (DEFINE-MACRO     as define-macro)
            (EXCEPT           as except)
            (GUARD            as guard)
            (LET              as let)
            (LET*             as let*)
            (LETREC           as letrec)
            (LETREC           as letrec)
            (LET-VALUES       as let-values)
            (LET*-VALUES      as let*-values)
            (UNLESS           as unless)
            (WHEN             as when))


    (define (undefined? x)
      (eq? x #u))

    (define (defined? x)
      (not (eq? x #u)))

    (define (raise . args)
      (if (= 1 length args)
          #{ (function () { throw @(car args) })() }#
          #{ (function ()
                       { var e = new Error(@(cadr args));
                             e.name = @(car args);
                             throw e;
                             })() }#))

    (define (call-with-guard try-thunk final-thunk)
      #{
        (function () {
                      var result = undefined;
                          try {
                               result = @(try-thunk);
                                      } finally {
                                                 @(final-thunk);
                                                 }
                                        return result;
                                        })()
                                          }#)

    (define (call-with-exception-handler try-thunk handler)
      #{
        (function () {
                      var result = undefined;
                          try {
                               result = @(try-thunk);
                                      } catch(e) {
                                                  result = @^(handler)(e);
                                                         }
                                        return result;
                                        })()
                                          }#)

    (define (assert b msg)
      (or b (raise (string-append "assert-failed: " { "" + @^(msg) }))))

    (define (default v d)
      (if (undefined? v) d v))

    (define (format fmt . args)
      (let* ([re { new RegExp("((([^%]|%%)*)(%[^%])?)", "g") }]
             [unescape-re { new RegExp("%%", "g") }]

             [interpolate
              (lambda (specifier arg)
                (case (string-ref specifier 1) ; FIX: check for unrecognized fmt letters
                  [(#\s) { "" + @^(arg) }]))]

             [unescape-pct-symbols
              (lambda (str)
                { @^(str).replace(@^(unescape-re), "%") })])

        (let loop ([segments '()]
                   [args args])
          (let ([match (re.exec fmt)])
            (if (string=? "" (vector-ref match 0))
                (apply string-append (reverse segments)) ; FIX: check for ill-formed fmt strings
                (let ([specifier (vector-ref match 4)])
                  (if (eq? specifier #u)
                      (loop (cons (unescape-pct-symbols (vector-ref match 2))
                                  segments)
                            args)
                      (loop (cons (interpolate (vector-ref match 4)
                                               (car args))
                                  (cons (unescape-pct-symbols (vector-ref match 2)) segments))
                            (cdr args)))))))))



    (define (DEFINE-MACRO stx m)
      (module-eval m (expand `(begin
                                (define ,@(cdr stx))
                                (make-macro ,(car (cadr stx))))
                             m))
      #u)
    
    (make-macro DEFINE-MACRO)
    
    (define (LET stx)
      (if (symbol? (cadr stx))
          ((lambda (name bindings body)
             ((lambda (formals initials)
                `(let ([,name #u])
                   (set! ,name (lambda ,formals ,@body))
                   (,name ,@initials)))
              (map car bindings) (map cadr bindings)))
           (cadr stx) (caddr stx) (cdddr stx))
          ((lambda (bindings body)
             ((lambda (formals values)
                `((lambda ,formals ,@body) ,@values))
              (map car bindings) (map cadr bindings)))
           (cadr stx) (cddr stx))))

    (make-macro LET)

    
    (define (LET* stx)
      (let ([bindings (cadr stx)]
            [body (cddr stx)])
        (if (or (null? bindings)
                (null? (cdr bindings)))
            `(let ,bindings ,@body)
            `(let (,(car bindings))
               (let* ,(cdr bindings) ,@body)))))

    (make-macro LET*)

    
    (define (LETREC stx)
      (let ([bindings (reverse (cadr stx))]
            [body (cddr stx)])
        (if (null? bindings)
            `(let () ,@body)
            (let ([dummy-bindings
                   (map (lambda (binding)
                          (list (car binding) #u))
                        bindings)]
                  [assignments
                   (map (lambda (binding)
                          (cons 'set! binding))
                        bindings)])
              `(let ,dummy-bindings ,@assignments ,@body)))))

    (make-macro LETREC)

    
    (define (LETREC* stx)
      `(letrec ,@(cdr stx)))

    (make-macro LETREC*)

    
    (define (LET-VALUES stx)
      (let ([result
             (let ([bindings (cadr stx)]
                   [body (cddr stx)])
               (let bind-loop ([bindings bindings]
                               [value-bindings '()]
                               [temp-bindings '()])
                 (if (null? bindings)
                     (let result-loop ([value-bindings value-bindings]
                                       [result `(let ,(apply append temp-bindings) ,@body)])
                       (if (null? value-bindings)
                           result
                           (let* ([value-binding (car value-bindings)]
                                  [values (car value-binding)]
                                  [temp-symbols (cadr value-binding)])
                             (result-loop (cdr value-bindings)
                                          `(call-with-values ,values
                                             (lambda ,temp-symbols ,result))))))
                     (let* ([binding (car bindings)]
                            [symbols (car binding)]
                            [values (cadr binding)]
                            [temps (map (lambda (sym)
                                          (list sym (gensym 'let-values)))
                                        symbols)]
                            [value-binding (list values (map cadr temps))])
                       (bind-loop (cdr bindings)
                                  (cons value-binding value-bindings)
                                  (cons temps temp-bindings))))))])
        (printf "LET-VALUES: result: %s\n" result)
        result))

    (make-macro LET-VALUES)

    
    (define (LET*-VALUES stx)
      (let ([bindings (cadr stx)]
            [body (cddr stx)])
        (if (null? bindings)
            `(let () ,@body)
            `(let-values (,(car bindings))
               (let*-values ,(cdr bindings) ,@body)))))

    (make-macro LET*-VALUES)

    
    (define (CASE stx)
      (let ([key (cadr stx)]
            [clauses (cddr stx)]
            [temp (gensym 'case)])
        (let clause-loop ([clauses (reverse clauses)]
                          [conditionals #u])
          (if (null? clauses)
              `(let ([,temp ,key]) ,conditionals)
              (let* ([clause (car clauses)]
                     [data (car clause)]
                     [result (cadr clause)]
                     [test (if (eq? data 'else)
                               #t
                               (let data-loop ([data (reverse data)]
                                               [condition '()])
                                 (if (null? data)
                                     (cons 'or condition)
                                     (data-loop (cdr data)
                                                (cons `(eqv? ,temp ',(car data)) condition)))))])
                (clause-loop (cdr clauses)
                             `(if ,test ,result ,conditionals)))))))

    (make-macro CASE)

    
    (define (COND stx)
      (let loop ([clauses (reverse (cdr stx))]
                 [conditionals #u])
        (if (null? clauses)
            conditionals
            (let* ([clause (car clauses)]
                   [condition (car clause)]
                   [anaphoric (eq? '=> (cadr clause))])
              (loop (cdr clauses)
                    (if anaphoric
                        (let ([temp (gensym 'cond)]
                              [resultant (cons 'begin (cddr clause))])
                          `(let ([,temp ,condition])
                             (if ,temp (,resultant ,temp) ,conditionals)))
                        (let ([resultant (cons 'begin (cdr clause))])
                          `(if ,condition ,resultant ,conditionals))))))))

    (make-macro COND)

    
    (define (WHEN stx)
      `(and ,(cadr stx)
            (begin ,@(cddr stx))))

    (make-macro WHEN)

    
    (define (UNLESS stx)
      `(or ,(cadr stx)
           (begin ,@(cddr stx))))

    (make-macro UNLESS)

    
    (define (GUARD stx)
      (assert (<= 3 (length stx)) (format "syntax error: (guard <final-thunk> forms...): %s" stx))
      (let ([final-thunk (cadr stx)]
            [forms (cddr stx)])
        `(call-with-guard (lambda () ,@forms) ,final-thunk)))

    (make-macro GUARD)

    
    (define (EXCEPT stx)
      (assert (<= 3 (length stx)) (format "syntax error: (except <handler> forms...): %s" stx))
      (let ([handler (cadr stx)]
            [forms (cddr stx)])
        `(call-with-exception-handler (lambda () ,@forms) ,handler)))

    (make-macro EXCEPT)


    "End Module preamble")



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
           [let-form `((lambda (t) ,recurring-form) 1)]
           [lambda-form `(lambda (bar . baz) ,let-form)]
           [value-form lambda-form]
           [set-form `(set! foo ,value-form)]
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

      (trial (= 0 (length (get-definitions root-context))))
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
    
    (let ([value-forms (value-set '(and a b c))])
      (trial (= 3 (length value-forms)))
      (trial (memq 'a value-forms))
      (trial (memq 'b value-forms))
      (trial (memq 'c value-forms)))

    (let ([value-forms (value-set '(begin a b c))])
      (trial (= 1 (length value-forms)))
      (trial (memq 'c value-forms)))

    (let ([value-forms (value-set '(define a))])
      (trial (= 0 (length value-forms))))

    (let ([value-forms (value-set '(if a b c))])
      (trial (= 2 (length value-forms)))
      (trial (memq 'b value-forms))
      (trial (memq 'c value-forms)))

    (let ([value-forms (value-set '(lambda a b c))])
      (trial (= 1 (length value-forms)))
      (trial (equal? value-forms '((lambda a b c)))))

    (let ([value-forms (value-set '(or a b c))])
      (trial (= 3 (length value-forms)))
      (trial (memq 'a value-forms))
      (trial (memq 'b value-forms))
      (trial (memq 'c value-forms)))

    (let ([value-forms (value-set '(quasiquote foo))])
      (trial (= 1 (length value-forms)))
      (trial (equal? value-forms '((quasiquote foo)))))

    (let ([value-forms (value-set '(quote foo))])
      (trial (= 1 (length value-forms)))
      (trial (equal? value-forms '((quote foo)))))

    (let ([value-forms (value-set '(set! a))])
      (trial (= 0 (length value-forms))))
    

    (let ([value-forms (value-set '(and (begin a b c)
                                        (define d)
                                        (if e f g)))])
      (trial (= 3 (length value-forms)))
      (trial (memq 'c value-forms))
      (trial (memq 'f value-forms))
      (trial (memq 'g value-forms)))

    (let ([value-forms (value-set '(begin (lambda a b c)
                                          (or d e f)
                                          (quasiquote g)))])
      (trial (= 1 (length value-forms)))
      (trial (equal? value-forms '((quasiquote g)))))

    (let ([value-forms (value-set '(if (quote a b c)
                                       (set! d e f)
                                       (and g h i)))])
      (trial (= 3 (length value-forms)))
      (trial (memq 'g value-forms))
      (trial (memq 'h value-forms))
      (trial (memq 'i value-forms)))

    (let ([value-forms (value-set '(or (define a)
                                       (if b c d)
                                       (lambda e f g)))])
      (trial (= 3 (length value-forms)))
      (trial (memq 'c value-forms))
      (trial (memq 'd value-forms))
      (trial (member '(lambda e f g) value-forms)))


    (let ([value-forms (value-set '((lambda (foo) bar) 7))])
      (trial (= 1 (length value-forms)))
      (trial (memq 'bar value-forms)))

    (let ([value-forms (value-set '((and (begin a b c)
                                         (lambda (foo)
                                           (begin (lambda a b c)
                                                  (or d e f)
                                                  (quasiquote g)))
                                         (if e f g)) 7))])
      (trial (= 1 (length value-forms)))
      (trial (equal? value-forms '((quasiquote g)))))


    (let ([value-forms (value-set '((if (quote a b c)
                                        (lambda (foo)
                                          (or (define a)
                                              (if b c d)
                                              (lambda e f g)))
                                        (lambda (foo) bar)) "six by nine"))])
      (trial (= 4 (length value-forms)))
      (trial (memq 'c value-forms))
      (trial (memq 'd value-forms))
      (trial (member '(lambda e f g) value-forms))
      (trial (memq 'bar value-forms)))


    (let ([value-forms (value-set '((if (quote a b c)
                                        (lambda (foo)
                                          (or (define a)
                                              (if b c d)
                                              ((lambda e f g) h)))
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

    (define M (current-module))
    
    (let* ([stx '(and)]
           [ctx (make-root-context stx)]
           [result (special-forms.and stx ctx M)])
      (trial (equal? result '(LITERAL #t))))
    
    (let* ([stx '(and foo)]
           [ctx (make-root-context stx)]
           [result (special-forms.and stx ctx M)])
      (trial (equal? result '(IDENTIFIER foo))))
    
    (let* ([stx '(and foo bar)]
           [ctx (make-root-context stx)]
           [result (special-forms.and stx ctx M)])
      (trial (equal? result '(CONDITIONAL (STRICTLY-EQUAL (IDENTIFIER foo)
                                                          (LITERAL #f))
                                          (LITERAL #f)
                                          (IDENTIFIER bar)))))

    (let* ([stx '(begin)]
           [ctx (make-root-context stx)]
           [result (special-forms.begin stx ctx M)])
      (trial (equal? result '(LITERAL #u))))

    (let* ([stx '(begin foo)]
           [ctx (make-root-context stx)]
           [result (special-forms.begin stx ctx M)])
      (trial (equal? result '(IDENTIFIER foo))))

    (let* ([stx '(begin foo bar)]
           [ctx (make-root-context stx)]
           [result (special-forms.begin stx ctx M)])
      (trial (equal? result '(SEQUENCE (IDENTIFIER foo) (IDENTIFIER bar)))))

    (let* ([stx '(begin #t (and foo bar))]
           [ctx (make-root-context stx)]
           [result (special-forms.begin stx ctx M)])
      (trial (equal? result '(SEQUENCE (LITERAL #t)
                                       (CONDITIONAL (STRICTLY-EQUAL (IDENTIFIER foo)
                                                                    (LITERAL #f))
                                                    (LITERAL #f)
                                                    (IDENTIFIER bar))))))

    (let ([ctx (make-root-context '())])
      (fail (special.forms.define '(define) ctx M))
      (fail (special.forms.define '(define foo bar) ctx M))
      (fail (special.forms.define '(define "symbol-required") ctx M))
      (fail (special.forms.define '(define (symbol required)) ctx M)))
    

    (let ([define-form '(define foo)])
      (let* ([stx `(lambda (bar) ,define-form)]
             [root-ctx (make-root-context stx)]
             [ctx (make-lambda-context stx root-ctx)]
             [result (special-forms.define define-form ctx M)])
        
        (trial (= 0 (length (get-definitions root-ctx))))
        
        (trial (equal? result '(LITERAL #u)))
        (trial (= 1 (length (get-definitions ctx))))
        (trial (definition-binding? (get-binding ctx 'foo))))

      (let* ([stx `((lambda (bar) ,define-form) 'baz)]
             [root-ctx (make-root-context stx)]
             [ctx (make-let-context stx root-ctx)]
             [result (special-forms.define define-form ctx M)])
        
        (trial (= 0 (length (get-definitions root-ctx))))
        
        (trial (equal? result '(LITERAL #u)))
        (trial (= 1 (length (get-definitions ctx))))
        (trial (get-binding ctx 'foo))
        (trial (definition-binding? (get-binding ctx 'foo))))

      (let* ([stx `(set! bar ,define-form)]
             [root-ctx (make-root-context stx)]
             [ctx (make-set-context stx root-ctx)]
             [result (special-forms.define define-form ctx M)])
        
        (trial (= 0 (length (get-definitions ctx))))
        
        (trial (equal? result '(LITERAL #u)))
        (trial (= 0 (length (get-definitions root-ctx)))))
                                        ;        (fail (get-binding root-ctx 'foo)))
      

      (let* ([stx `(and ,define-form 'bar)]
             [root-ctx (make-root-context stx)]
             [ctx (make-non-tail-context stx root-ctx)]
             [result (special-forms.define define-form ctx M)])
        
        (trial (= 0 (length (get-definitions ctx))))
        
        (trial (equal? result '(LITERAL #u)))
        (trial (= 0 (length (get-definitions root-ctx))))))
                                        ;        (fail (get-binding root-ctx 'foo))))

    (let* ([stx '(if)]
           [ctx (make-root-context stx)])
      (fail ((object-ref special-forms "if") stx ctx M)))

    (let* ([stx '(if a)]
           [ctx (make-root-context stx)])
      (fail ((object-ref special-forms "if") stx ctx M)))

    (let* ([stx '(if a b)]
           [ctx (make-root-context stx)])
      (fail ((object-ref special-forms "if") stx ctx M)))

    (let* ([stx '(if a b c d)]
           [ctx (make-root-context stx)])
      (fail ((object-ref special-forms "if") stx ctx M)))

    (let* ([stx '(if a b c)]
           [ctx (make-root-context stx)]
           [result ((object-ref special-forms "if") stx ctx M)])
      (trial (equal? result '(CONDITIONAL (IDENTIFIER a) (IDENTIFIER b) (IDENTIFIER c)))))


    (let* ([stx '(lambda (x) #t)]
           [ctx (make-root-context stx)])
      (fail (special-forms.lambda '(lambda 3 #t) ctx M))
      (fail (special-forms.lambda '(lambda x) ctx M))
      (fail (special-forms.lambda '(lambda (3) x) ctx M))
      (fail (special-forms.lambda '(lambda (a 3) x) ctx M))
      (fail (special-forms.lambda '(lambda (a . "hello") x) ctx M))
      (fail (special-forms.lambda '(lambda ((list a)) x) ctx M)))
    

    (let* ([stx '(lambda (x) #t)]
           [ctx (make-root-context stx)]
           [result (special-forms.lambda stx ctx M)])
      ;;(printf "%s\n" result)
      (trial (equal? result '(FUNCTION #f ((IDENTIFIER x)) ((STATEMENT (RETURN (LITERAL #t)))))
                     )))

    (let* ([stx '(lambda (x y) foo)]
           [ctx (make-root-context stx)]
           [result (special-forms.lambda stx ctx M)])
      ;;(printf "%s\n" result)
      (trial (equal? result '(FUNCTION #f ((IDENTIFIER x) (IDENTIFIER y))
                                       ((STATEMENT (RETURN (IDENTIFIER foo))))))))

    (let* ([stx '(lambda x foo)]
           [ctx (make-root-context stx)]
           [result (special-forms.lambda stx ctx M)])
      ;;(printf "%s\n" result)
      (trial (equal? result '(FUNCTION #f ()
                                       ((STATEMENT (VAR (((IDENTIFIER x) (CALL (IDENTIFIER "$argumentsList")
                                                                               ((IDENTIFIER arguments)
                                                                                (LITERAL 0)))))))
                                        (STATEMENT (RETURN (IDENTIFIER foo))))))))

    (let* ([stx '(lambda (x . y) foo)]
           [ctx (make-root-context stx)]
           [result (special-forms.lambda stx ctx M)])
      (trial (equal? result '(FUNCTION #f ((IDENTIFIER x))
                                       ((STATEMENT (VAR (((IDENTIFIER y) (CALL (IDENTIFIER "$argumentsList")
                                                                               ((IDENTIFIER arguments)
                                                                                (LITERAL 1)))))))
                                        (STATEMENT (RETURN (IDENTIFIER foo))))))))

    (let* ([stx '(or)]
           [ctx (make-root-context stx)]
           [result (special-forms.or stx ctx M)])
      (trial (equal? result '(LITERAL #f))))
    
    (let* ([stx '(or foo)]
           [ctx (make-root-context stx)]
           [result (special-forms.or stx ctx M)])
      (trial (equal? result '(IDENTIFIER foo))))
    
    (let* ([stx '(or foo bar)]
           [ctx (make-root-context stx)]
           [result (special-forms.or stx ctx M)])
      (trial (equal? result '(CONDITIONAL (NOT-STRICTLY-EQUAL (PAREN (ASSIGN (IDENTIFIER "$temp")
                                                                             (IDENTIFIER foo)))
                                                              (LITERAL #f))
                                          (IDENTIFIER "$temp")
                                          (IDENTIFIER bar)))))

    (let* ([stx '(quote (x) #t)]
           [ctx (make-root-context stx)])
      (fail (special-forms.quote '(quote) ctx M))
      (fail (special-forms.quote '(quote foo bar) ctx M)))
    
    (let* ([stx '(quote foo)]
           [ctx (make-root-context stx)]
           [result (special-forms.quote stx ctx M)])
      (trial (equal? result '(LITERAL foo))))

    (let* ([stx '(quote "ten")]
           [ctx (make-root-context stx)]
           [result (special-forms.quote stx ctx M)])
      (trial (equal? result '(LITERAL "ten"))))

    (let* ([stx '(quote 2)]
           [ctx (make-root-context stx)]
           [result (special-forms.quote stx ctx M)])
      (trial (equal? result '(LITERAL 2))))

    (let* ([stx '(quote ())]
           [ctx (make-root-context stx)]
           [result (special-forms.quote stx ctx M)])
      (trial (equal? result '(IDENTIFIER "$nil"))))

    (let* ([stx '(quote (apples))]
           [ctx (make-root-context stx)]
           [result (special-forms.quote stx ctx M)])
      (trial (eq? (car result) 'IDENTIFIER))
      (let ([binding (get-binding ctx (cadr result))])
        (trial (equal? binding.value '(CALL (IDENTIFIER "cons")
                                            ((LITERAL apples)
                                             (IDENTIFIER "$nil")))))))

    (let* ([stx '(quasiquote (x) #t)]
           [ctx (make-root-context stx)])
      (fail (special-forms.quasiquote '(quasiquote) ctx M))
      (fail (special-forms.quasiquote '(quasiquote foo bar) ctx M)))
    
    (let* ([stx '(quasiquote foo)]
           [ctx (make-root-context stx)]
           [result (special-forms.quasiquote stx ctx M)])
      (trial (equal? result '(LITERAL foo))))


    (let* ([stx '(quasiquote (apples))]
           [ctx (make-root-context stx)]
           [result (special-forms.quasiquote stx ctx M)])
      (trial (eq? (car result) 'IDENTIFIER))
      (let ([binding (get-binding ctx (cadr result))])
        (trial (equal? binding.value '(CALL (IDENTIFIER "cons")
                                            ((LITERAL apples)
                                             (IDENTIFIER "$nil")))))))

    (let* ([stx '(quasiquote (apples ,oranges))]
           [ctx (make-root-context stx)]
           [result (special-forms.quasiquote stx ctx M)])
      ;;       (CALL (IDENTIFIER "$quasiUnquote")
      ;;             ((IDENTIFIER $quote_804)
      ;;              ((FUNCTION #f () ((STATEMENT (RETURN (IDENTIFIER oranges))))))))
      (trial (list? result))
      (trial (= 3 (length result)))
      (trial (equal? (take 2 result)
                     '(CALL (IDENTIFIER "$quasiUnquote"))))
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


    (let* ([stx '(quasiquote (`(no ,change) ,@(foo bar)))]
           [ctx (make-root-context stx)]
           [result (special-forms.quasiquote stx ctx M)])
      ;;(CALL (IDENTIFIER "$quasiUnquote")
      ;;      ((IDENTIFIER $quote_804)
      ;;       ((FUNCTION #f () ((STATEMENT 
      ;;                          (RETURN (CALL (IDENTIFIER foo)
      ;;                                        ((IDENTIFIER bar))))))))))
      (trial (list? result))
      (trial (= 3 (length result)))
      (trial (equal? (take 2 result)
                     '(CALL (IDENTIFIER "$quasiUnquote"))))
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

    (let* ([stx '(set! (x) #t)]
           [ctx (make-root-context stx)])
      (fail (special-forms.set! '(set!) ctx M))
      (fail (special-forms.set! '(set! foo) ctx M))
      (fail (special-forms.set! '(set! foo bar baz) ctx M))
      (fail (special-forms.set! '(set! 2 bar) ctx M))
      (fail (special-forms.set! '(set! "hello" bar) ctx M))
      (fail (special-forms.set! '(set! (car args) bar) ctx M)))


    (let* ([stx '(set! foo #t)]
           [ctx (make-root-context stx)]
           [result (special-forms.set! stx ctx M)])
      (trial (equal? result
                     '(ASSIGN (MEMBER-EXP (IDENTIFIER "$")
                                          (LITERAL "foo"))
                              (LITERAL #t)))))
    

    (let* ([stx '(set! foo.bar* #t)]
           [ctx (make-root-context stx)]
           [result (special-forms.set! stx ctx M)])
      (trial (equal? result
                     '(ASSIGN (MEMBER-EXP (IDENTIFIER foo)
                                          (LITERAL "bar*"))
                              (LITERAL #t)))))
    

    (let* ([stx '(set! foo.bar* (and a b))]
           [ctx (make-root-context stx)]
           [result (special-forms.set! stx ctx M)])
      (trial (equal? result
                     '(ASSIGN (MEMBER-EXP (IDENTIFIER foo)
                                          (LITERAL "bar*"))
                              (CONDITIONAL (STRICTLY-EQUAL (IDENTIFIER a)
                                                           (LITERAL #f))
                                           (LITERAL #f)
                                           (IDENTIFIER b))))))
    
    (let* ([stx '(foo)]
           [ctx (make-root-context stx)]
           [result (parse-application stx ctx M)])
      (trial (equal? result
                     '(CALL (IDENTIFIER foo) ()))))

    (let* ([stx '(foo 12 bar)]
           [ctx (make-root-context stx)]
           [result (parse-application stx ctx M)])
      (trial (equal? result
                     '(CALL (IDENTIFIER foo)
                            ((LITERAL 12)
                             (IDENTIFIER bar))))))

    (let* ([stx '((and foo bar) (quote baz))]
           [ctx (make-root-context stx)]
           [result (parse-application stx ctx M)])
      (trial (equal? result
                     '(CALL
                       (PAREN (CONDITIONAL (STRICTLY-EQUAL (IDENTIFIER foo)
                                                           (LITERAL #f))
                                           (LITERAL #f)
                                           (IDENTIFIER bar)))
                       ((LITERAL baz))))))

    (let* ([stx '((lambda (foo) (bar foo)) "Foo")]
           [ctx (make-root-context stx)]
           [result (parse-let-form stx ctx M)])
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
           [lambda-form `(lambda (x) ,recurring-form)]
           [stx `(set! foo ,lambda-form)]
           [root-ctx (make-root-context stx)]
           [set-ctx (make-set-context stx root-ctx)]
           [non-tail-ctx (make-non-tail-context lambda-form set-ctx)]
           [lambda-ctx (make-lambda-context lambda-form non-tail-ctx)]
           [result (parse-application recurring-form lambda-ctx M)])
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
           [lambda-form `(lambda (x) ,recurring-form)]
           [stx `(set! foo ,lambda-form)]
           [root-ctx (make-root-context stx)]
           [set-ctx (make-set-context stx root-ctx)]
           [non-tail-ctx (make-non-tail-context lambda-form set-ctx)]
           [result (special-forms.lambda lambda-form non-tail-ctx M)])
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
           [lambda-form `(lambda x ,recurring-form)]
           [stx `(set! foo ,lambda-form)]
           [root-ctx (make-root-context stx)]
           [set-ctx (make-set-context stx root-ctx)]
           [non-tail-ctx (make-non-tail-context lambda-form set-ctx)]
           [lambda-ctx (make-lambda-context lambda-form non-tail-ctx)]
           [result (parse-application recurring-form lambda-ctx M)])
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
             [lambda-form `(lambda (a . x) ,parent-form)]
             [stx `(set! foo ,lambda-form)]
             [root-ctx (make-root-context stx)]
             [set-ctx (make-set-context stx root-ctx)]
             [non-tail-ctx (make-non-tail-context lambda-form set-ctx)]
             [lambda-ctx (make-lambda-context lambda-form non-tail-ctx)]
             [result (parse parent-form lambda-ctx M)])
        (trial (recursive-lambda-context? lambda-ctx))))

    (test-tco-form '(and #t ,x))
    (fail (test-tco-form '(and ,x #t)))

    (test-tco-form '(begin #t ,x))
    (fail (test-tco-form '(begin ,x #t)))

    (fail (test-tco-form '(if ,x a b)))
    (test-tco-form '(if t ,x  b))
    (test-tco-form '(if t a ,x))

    (fail (test-tco-form '(lambda (y) ,x)))
    (test-tco-form '((lambda (y) ,x) 7))
    
    (test-tco-form '(or #f ,x))
    (fail (test-tco-form '(or ,x #f)))

    (fail (test-tco-form '(quote ,x)))

    (fail (test-tco-form '(set! bar ,x)))

    (fail (text-tco-form '(,x a)))
    (fail (text-tco-form '(a ,x)))

    (define (test-root-definition form)
      (let* ([ctx (make-root-context form)]
             [definitions (and (parse form ctx M)
                               (get-definitions ctx))])
        (trial (= 0 (length definitions)))))

    (test-root-definition '(define X))
    
    (test-root-definition '(and (define X) A))
    (test-root-definition '(and A (define X)))
    (test-root-definition '(begin (define X) A))
    (test-root-definition '(begin A (define X)))
    (test-root-definition '(if (define X) A B))
    (test-root-definition '(if T (define X) B))
    (test-root-definition '(if T A (define X)))
    (test-root-definition '(lambda () (define X)))
    (test-root-definition '(or (define X) A))
    (test-root-definition '(or A (define X)))
    (test-root-definition '(set! A (define X)))

    (define (test-lambda-definition form)
      (let* ([ctx (make-root-context form)]
             [lambda-ctx (make-lambda-context form ctx)]
             [definitions (and (parse (caddr form) lambda-ctx M)
                               (get-definitions lambda-ctx))])
        (trial (null? (get-definitions ctx)))
        
        (trial (= 1 (length definitions)))
        (trial (eq? 'X (object-ref (car definitions) symbol:)))
        (trial (get-binding lambda-ctx 'X))))

    (test-lambda-definition '(lambda () (and (define X) A)))
    (test-lambda-definition '(lambda () (and A (define X))))
    (test-lambda-definition '(lambda () (begin (define X) A)))
    (test-lambda-definition '(lambda () (begin A (define X))))
    (test-lambda-definition '(lambda () (if (define X) A B)))
    (test-lambda-definition '(lambda () (if T (define X) B)))
    (test-lambda-definition '(lambda () (if T A (define X))))
    (fail (test-lambda-definition '(lambda () (lambda () (define X)))))
    (test-lambda-definition '(lambda () (or (define X) A)))
    (test-lambda-definition '(lambda () (or A (define X))))
    (test-lambda-definition '(lambda () (set! A (define X))))


    (define (test-let-definition form)
      (let* ([ctx (make-root-context form)]
             [definitions (and (parse form ctx M)
                               (get-definitions ctx))])
        
        (trial (= 1 (length definitions)))
        (trial (eq? 'X (object-ref (car definitions) symbol:)))
        (trial (not (get-binding ctx 'X)))))

    (test-let-definition '((lambda () (and (define X) A))))
    (test-let-definition '((lambda () (and A (define X)))))
    (test-let-definition '((lambda () (begin (define X) A))))
    (test-let-definition '((lambda () (begin A (define X)))))
    (test-let-definition '((lambda () (if (define X) A B))))
    (test-let-definition '((lambda () (if T (define X) B))))
    (test-let-definition '((lambda () (if T A (define X)))))
    (fail (test-let-definition '((lambda () (lambda () (define X))))))
    (test-let-definition '((lambda () (or (define X) A))))
    (test-let-definition '((lambda () (or A (define X)))))
    (test-let-definition '((lambda () (set! A (define X)))))


    (let* ([stx '(lambda () (define X) (set! X 0))]
           [ctx (make-root-context stx)]
           [result (parse stx ctx M)])
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
    (let* ([stx '(lambda (X) ((lambda (Y) (define X) (set! X 0)) X))]
           [ctx (make-root-context stx)]
           [result (parse stx ctx M)])
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
    (let* ([stx '(lambda (X)
                   (define X)
                   (set! X 0)
                   (define X)
                   (set! X 0))]
           [ctx (make-root-context stx)]
           [result (parse stx ctx M)])
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
    
    (let* ([stx '(lambda (Y)
                   (define X)
                   (set! X 0)
                   (define X)
                   (set! X 0))]
           [ctx (make-root-context stx)]
           [result (parse stx ctx M)])
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


    (let ([result (internal->target '(foo (quote bar)))])
      (trial (equal? result
                     '(CALL (PAREN
                             (FUNCTION #f ()
                                       ((STATEMENT
                                         (RETURN
                                          (CALL (IDENTIFIER foo)
                                                ((LITERAL bar))))))))
                            () ))))
    
    (let* ([result (internal->target '(foo (quote (bar soap))))]
           [function (and
                      ;;(printf "result: %s\n" result)
                      (trial (and (list? result) (= 3 (length result))))
                      (trial (eq? 'CALL (car result)))
                      (trial (and (list? (cadr result)) (= 2 (length (cadr result)))))
                      (trial (eq? 'PAREN (caadr result)))
                      (cadadr result))]
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


    (let ([M (let ([shell (make-module 'shell (current-module))])
               (module-import shell `(preamble . ,preamble) #f '*)
               (module-export shell '*)
               shell)])
      (trial (macro? M.define-macro))
      (trial (macro? M.except))
      (trial (macro? M.guard))
      (trial (macro? M.let))
      (trial (macro? M.let*))
      (trial (macro? M.letrec))
      (trial (macro? M.letrec))
      (trial (macro? M.let-values))
      (trial (macro? M.let*-values))
      (trial (macro? M.unless))
      (trial (macro? M.when)))

;;                 (let (let ([a b]) c) ((lambda (a) c) b))
;;                 (let (let loop ([a b]) c) (let ([loop #u])
;;                                             (set! loop (lambda (a) c))
;;                                             (loop b)))

;;                 (let* (let* ([a b] [c a])
;;                         (bar a c))
;;                       (let ([a b])
;;                         (let* ([c a])
;;                           (bar a c))))

;;                 (letrec (letrec ([foo (lambda (a) (if a (+ 1 a) (foo 1)))])
;;                           (foo #f))
;;                         (let ([foo #u])
;;                           (set! foo (lambda (a)
;;                                       (if a
;;                                           (+ 1 a)
;;                                           (foo 1))))
;;                           (foo #f)))


    ;; vectors
    ;; values
    
    "End Module test");)
  
  "END Module primitives")

