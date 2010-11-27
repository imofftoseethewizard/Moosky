(module mop

  (import * from digraph)
  (export *)

  (define DEBUG #t)
  
  (module util
    
    (export *)

    (define-macro (debug stx)
      (if DEBUG
          `(begin ,@(cdr stx))
          #u))
    
    
    (define (delete-duplicates L R)
      (let ([R (if (defined? R) R equal?)])
        (reverse
         (fold-left (lambda (L* y)
                      (if (memp (lambda (x) (R x y)) L*)
                          L*
                          (cons y L*)))
                    '()
                    L))))

    (define (pick sym objs)
      (map (lambda (obj)
             (object-ref obj sym))
           objs))

    (define (get-keyword-option options kw def)
      (let ([pair (assoc kw (pairs options))])
        (if pair
            (cdr pair)
            def)))


    (define-macro (bind stx)
      ;; bind enables easy use of keyword arguments
      ;; it is essentially a let form where the bound values
      ;; are fetched from a keyword-list.
      (let* ([target (cadr stx)]
             [bindings (map (lambda (b)
                              (if (list? b)
                                  `(,(car b) (get-keyword-option ,target ',(car b) ,(cadr b)))
                                  `(,b (get-keyword-option ,target ',b #u))))
                            (caddr stx))]
             [body (cdddr stx)])
        `(let ,bindings ,@body)))

    (define (compute-class-precedence-list direct-supers)
      ;;  
      ;;  "Computes the class precedence list for a given list of direct superclasses.
      ;;Note that the direct superclasses are in specification order; that is,
      ;;the most specific class is first, the most fundamental last.  The
      ;;result of this function has the reverse order, from most fundamental
      ;;to most specific.
      ;;"
      (let* ([G (DirectedGraph (lambda (c) c.id))]
             [head (object id: (gensym 'head))]
             [add-list (lambda (L)
                         (fold-left (lambda (A B)
                                      (digraph-add-edge G A B)
                                      B)
                                    head
                                    L))])
        (add-list direct-supers) 
        (letrec ([add-class (lambda (c)
                              (add-list (cons c c.direct-superclasses))
                              (for-each add-class c.direct-superclasses))])
          (for-each add-class direct-supers))
        (let ([result (digraph-topological-sort G)])
          (if (null? result)
              result
              (reverse (cdr result))))))


    (define (auto-functor kernel)
      (let* ([This #u]
             [result (lambda args
                       (apply kernel This args))])
        (set! This result)
        result))


    (define (fold-functors f-initial functors)
      (fold-left (lambda (f functor)
                   (if (and (defined? functor) functor)
                       (functor f)
                       f))
                 f-initial
                 functors))
    

    (module test

      (define-macro (trial stx)
        `(assert ,@(cdr stx) (format "%s failed" ',@(cdr stx))))

      (define-macro (fail stx)
        `(assert (eq? 'exception (except (lambda (e) 'exception)
                                   ,@(cdr stx)))
                 (format "%s failed" ',@(cdr stx))))


      (trial (equal? '(1 2 3 4) (delete-duplicates '(1 2 1 2 3 1 2 3 4 1 2 3 4))))
      (trial (equal? '() (delete-duplicates '())))

      (trial (equal? '() (pick foo: '())))
      (trial (equal? '(#u) (pick foo: (list (object)))))
      (trial (equal? '(1 2 3 4) (pick foo: (list (object foo: 1)
                                                 (object foo: 2)
                                                 (object foo: 3)
                                                 (object foo: 4)))))

      (trial (equal? #f (get-keyword-option '() trial: #f)))
      (trial (equal? #t (get-keyword-option '() trial: #t)))
      (trial (equal? 'foo (get-keyword-option '(trial: foo) trial: #f)))
      (trial (equal? 'foo (get-keyword-option '(trial: foo trial: bar) trial: #f)))
      (trial (equal? 'foo (get-keyword-option '(other: 1 trial: foo trial: bar) trial: #f)))
      (trial (equal? '(foo) (get-keyword-option '(other: 1 trial: (foo)) trial: #f)))

      (define kwargs '(foo: bar pi: 3.14 notes: "yawn"))
      
      (bind kwargs ([foo 'a]
                    [bar 'b]
                    [pi 3]
                    [notes "failed"])
        (trial (equal? 'bar foo))
        (trial (equal? 'b bar))
        (trial (equal? 3.14 pi))
        (trial (equal? "yawn" notes)))

      (define clauses '((yadda yadda yadda)
                        (foo bar)
                        (foo fighter)
                        agronomy
                        7))

      (trial (equal? '((yadda yadda yadda)) (all-clauses clauses 'yadda)))
      (trial (equal? '((foo bar) (foo fighter)) (all-clauses clauses 'foo)))
      (trial (equal? '() (all-clauses clauses 'agronomy)))

      (trial (equal? '(yadda yadda yadda) (get-clause clauses 'yadda #f)))
      (trial (equal? #f (get-clause clauses 'agronomy #f)))
      (trial (equal? 3.14 (get-clause clauses 'pi 3.14)))
      (fail (get-clause 'foo clauses '(FOO)))

      (trial (equal? '() (compute-class-precedence-list '())))

      (define supers (map (lambda (sym) (object id: sym direct-superclasses: '())) '(A B C)))

      (trial (equal? '(C B A) (pick id: (compute-class-precedence-list supers))))

      (set! supers (list (object id: 'A
                                 direct-superclasses: (list (object id: 'b direct-superclasses: '())
                                                            (object id: 'c direct-superclasses: '())))
                         (object id: 'B
                                 direct-superclasses: (list (object id: 'a direct-superclasses: '())
                                                            (object id: 'c direct-superclasses: '())))
                         (object id: 'C
                                 direct-superclasses: (list (object id: 'a direct-superclasses: '())
                                                            (object id: 'b direct-superclasses: '())))))

      (define result (compute-class-precedence-list supers))
      (define ids (map (lambda (x) x.id) result))
      
      (trial (member 'A ids))
      (trial (member 'A (member 'B ids)))
      (trial (member 'A (member 'B (member 'C ids))))
      
      (trial (member 'B ids))
      (trial (member 'B (member 'b ids)))
      (trial (member 'B (member 'a (member 'c ids))))
      
      (trial (member 'C ids))
      (trial (member 'C (member 'a ids)))
      (trial (member 'C (member 'a (member 'b ids))))

      "end module test")
    
    "end module util")

  (import * from util)
  
  (module syntax

    (export class
            define-class
            class-function
            class-method
            instance-function
            method
            define-generic)

    (define class-this-parameter-name 'This)
    (define class-next-function-name 'next-function)
    
    (define class-method-this-parameter-name 'This)
    (define class-method-next-function-name 'next-method)
    
    (define instance-this-parameter-name 'this)
    (define instance-next-function-name 'next-function)
    
    (define method-this-parameter-name 'this)
    (define method-next-function-name 'next-method)


    (define (compute-named-functor s next-symbol)
      (and s
           (if (list? (cadr s))
               (let ([name (caadr s)]
                     [formals (cdadr s)]
                     [body (cddr s)])
                 `(cons ',name (lambda (,next-symbol)
                                 (lambda ,formals ,@body))))
               
               (let ([name (cadr s)]
                     [body (cddr s)])
                 `(cons ',name ,@body)))))


    (define (compute-functor s next-symbol)
      (and s
           (let ([formals (cadr s)]
                 [body (cddr s)])
             `(lambda (,next-symbol)
                (lambda ,formals ,@body)))))


    (define (compute-class-functor specifier)
      (compute-functor specifier class-next-function-name))


    (define (compute-class-method-functor specifier)
      (compute-named-functor specifier class-method-next-function-name))


    (define (compute-instance-functor specifier)
      (compute-functor specifier instance-next-function-name))


    (define (compute-instance-method-functor specifier)
      (compute-named-functor specifier method-next-function-name))

    (define (compute-member s type)
      (if (not (list? s))
          `(list ',s)
          (let* ([name (car s)]
                 [options (cdr s)]
                 [value (get-keyword-option options init-value: #u)]
                 [form (get-keyword-option options init-form: #u)])
            
            (assert (not (and (defined? form) (defined? value)))
                    (format "Both init-form and init-value specified in %s member specifier: %s" type s))
            
            (cond [(defined? form)
                   `(list ',name init-form: (lambda () ,form))]
                  
                  [(defined? value)
                   `(list ',name init-value: ,value)]

                  [#t
                   (assert #f (format "Unrecognized %s member specifier: %s" type s))]))))

    
    (define (compute-class-member specifier)
      (compute-member specifier 'class))

    
    (define (compute-class-members specifiers)
      `(list ,@(delete-duplicates (map compute-class-member specifiers)
                                  (lambda (x y)
                                    (equal? (cadr x) (cadr y))))))


    (define (compute-class-member-initializers specifiers obj-symbol)
      (let loop ([bindings '()]
                 [forms '()]
                 [specifiers specifiers])
        (if (null? specifiers)
            (cons (reverse bindings) (reverse forms))
            (let ([s (car specifiers)])
              (if (list? s)
                  (let* ([name (car s)]
                         [options (cdr s)]
                         [value (get-keyword-option options init-value: #u)]
                         [form (get-keyword-option options init-form: #u)])
                    (assert (not (and (defined? form) (defined? value))))
                    (cond [(defined? form)
                           (loop bindings
                                 (cons `(object-set! ,obj-symbol ',name ,form)
                                       forms)
                                 (cdr specifiers))]

                          [(defined? value)
                           (let ([sym (gensym name)])
                             (loop (cons (list sym value) bindings)
                                   (cons `(object-set! ,obj-symbol ',name ,sym)
                                         forms)
                                   (cdr specifiers)))]

                          [#t
                           (loop bindings forms (cdr specifiers))]))
                  (loop bindings forms (cdr specifiers)))))))



    (define (compute-class-member-initializer member-specifiers)
      (let ([obj-symbol (gensym 'This)])
        (let* ([initializers (compute-class-member-initializers member-specifiers obj-symbol)]
               [initial-value-bindings (car initializers)]
               [initialization-forms (cdr initializers)])
          (and (not (null? initialization-forms))
               (if (null? initial-value-bindings)
                   `(lambda (,obj-symbol)
                      ,@initialization-forms)
                   `(let ,initial-value-bindings
                      (lambda (,obj-symbol)
                        ,@initialization-forms)))))))


    (define (compute-instance-member specifier)
      (compute-member specifier 'instance))

    
    (define (compute-instance-members specifiers)
      `(list ,@(delete-duplicates (map compute-instance-member specifiers)
                                  (lambda (x y)
                                    (equal? (cadr x) (cadr y))))))

    (define (compute-instance-default-initializer member-specifiers)
      (let* ([obj-symbol (gensym 'this)]
             [initializers (filter identity
                                   (map (lambda (s)
                                          (and (list? s)
                                               (let ([name (car s)]
                                                     [value (get-keyword-option (cdr s) init-value: #f)])
                                                 (and value
                                                      `(object-set! ,obj-symbol ',name ,value)))))
                                        member-specifiers))])
        (and (not (null? initializers))
             `(lambda (,obj-symbol)
                ,@initializers))))



    (define (compute-instance-member-initializer member-specifiers)
      (let* ([obj-symbol (gensym 'this)]
             [initializers (filter identity
                                   (map (lambda (s)
                                          (and (list? s)
                                               (let ([name (car s)]
                                                     [form (get-keyword-option (cdr s) init-form: #f)])
                                                 (and form
                                                      `(object-set! ,obj-symbol ',name ,form)))))
                                        member-specifiers))])
        (and (not (null? initializers))
             `(lambda (,obj-symbol)
                ,@initializers))))


    (define-macro (class stx)
      (assert (<= 3 (length stx)))
      (let* ([syntax (car stx)]
             [name (cadr stx)]
             [direct-supers (caddr stx)]
             [body (cdddr stx)]
             [metaclass-specifier (get-clause body 'metaclass #f)]
             [class-functor-specifier (get-clause body 'class-function #f)]
             [class-method-specifiers (all-clauses body 'class-method)]
             [class-member-specifiers (apply append (map cdr (all-clauses body 'class-members)))]
             [instance-functor-specifier (get-clause body 'instance-function #f)]
             [method-specifiers (all-clauses body 'method)]
             [instance-member-specifiers (apply append (map cdr (all-clauses body 'members)))])
        
        (assert (symbol? name))
        (assert (list? direct-supers))
        `(let ([Class ,(if metaclass-specifier
                           (cadr metaclass-specifier)
                           `(object-ref ,syntax default-metaclass:))]
               [direct-supers (list ,@direct-supers)])
           (Class name: ',name
                  class-specifier: ',(cdr stx)
                  direct-superclasses: direct-supers
                  class-functor: ,(compute-class-functor class-functor-specifier)
                  class-members: ,(compute-class-members class-member-specifiers)
                  class-member-initializer: ,(compute-class-member-initializer class-member-specifiers)
                  class-method-functors: (list ,@(map compute-class-method-functor class-method-specifiers))
                  instance-functor: ,(compute-instance-functor instance-functor-specifier)
                  instance-method-functors: (list ,@(map compute-instance-method-functor method-specifiers))
                  instance-members: ,(compute-instance-members instance-member-specifiers)))))

    
    (set! class.default-metaclass #f)
    

    (define (all-method-names class-body)
      (map (lambda (method-specifier)
             (let ([formals (cadr method-specifier)])
               (if (list? formals)
                   (car formals)
                   formals)))
           (append (all-clauses class-body 'class-method)
                   (all-clauses class-body 'method))))
    
    
    (define-macro (define-class stx)
      `(begin
         (define ,(cadr stx) (class ,@(cdr stx)))
         ,@(map (lambda (name)
                  `(define-generic ,name))
                (all-method-names (cdddr stx)))))
    

    (define-macro (class-function stx)
      (compute-class-functor stx))

    (define-macro (class-method stx)
      (compute-class-method-functor stx))

    (define-macro (instance-function stx)
      (compute-instance-functor stx))

    (define-macro (method stx)
      (compute-instance-method-functor stx))

    (define-macro (define-generic stx)
      (let ([name (cadr stx)])
        `(define ,name
           (lambda args
             (apply (object-ref (car args) ',name) args)))))

    (module test

      (define-macro (trial stx)
        `(assert ,@(cdr stx) (format "%s failed" ',@(cdr stx))))

      (define-macro (fail stx)
        `(assert (eq? 'exception (except (lambda (e) 'exception)
                                   ,@(cdr stx)))
                 (format "%s failed" ',@(cdr stx))))


      (trial (equal? '(lambda (next) (lambda (This . args) body))
                     (compute-functor '(class-function (This . args) body) 'next)))

      (trial (equal? '(cons 'foo (lambda (next-method) (lambda (this x) (bar))))
                     (compute-named-functor '(method (foo this x) (bar)) 'next-method)))


      (trial (equal? '(lambda (next-function) (lambda (This x) body))
                     (compute-class-functor '(class-function (This x) body))))

      (trial (equal? '(cons 'xyzzy (lambda (next-method) (lambda (This y) body)))
                     (compute-class-method-functor '(class-method (xyzzy This y) body))))

      (trial (equal? '(lambda (next-function) (lambda (this . options) body))
                     (compute-instance-functor '(instance-function (this . options) body))))

      (trial (equal? '(cons 'finish (lambda (next-method) (lambda (this update) body)))
                     (compute-instance-method-functor '(instance-method (finish this update) body))))

      (trial (equal? identity (fold-functors identity '())))
      (trial (equal? identity (fold-functors identity '(#f #f #f))))
      (trial (equal? identity (fold-functors identity (list identity identity))))
      
      (define (one) 1)
      (trial (equal? one (fold-functors identity (list (lambda () one)))))
      (trial (equal? one (fold-functors one (list identity))))


      (set! result (compute-class-member-initializers '(class-members
                                                        foo
                                                        (bar init-value: 'soap)
                                                        (bash init-form: (shell current-directory)))
                                                      'Thingie))
      (define initial-value-bindings (car result))
      (define initialization-forms (cdr result))

      (trial (= 1 (length initial-value-bindings)))
      (trial (equal? ''soap (cadar initial-value-bindings)))
      
      (define temp-symbol (caar initial-value-bindings))

      (trial (= 2 (length initialization-forms)))
      (trial (member '(object-set! Thingie 'bash (shell current-directory))
                     initialization-forms))
      (trial (member `(object-set! Thingie 'bar ,temp-symbol)
                     initialization-forms))

      (set! result (compute-class-member-initializer '(class-members
                                                       foo
                                                       (bar init-value: 'soap)
                                                       (bash init-form: (shell current-directory)))))

      (trial (= 3 (length result)))
      (trial (equal? 'let (car result)))
      (trial (= 1 (length (cadr result))))
      (trial (equal? ''soap (cadar (cadr result))))

      (set! temp-symbol (caar (cadr result)))

      (trial (= 4 (length (caddr result))))
      (trial (equal? 'lambda (car (caddr result))))
      (trial (= 1 (length (cadr (caddr result)))))

      (define this-symbol (car (cadr (caddr result))))

      (trial (member `(object-set! ,this-symbol 'bar ,temp-symbol)
                     (caddr result)))
      (trial (member `(object-set! ,this-symbol 'bash (shell current-directory))
                     (caddr result)))
      

      (set! result (compute-instance-default-initializer '(members
                                                           foo
                                                           (bar init-value: 'soap)
                                                           (bash init-form: (shell current-directory)))))

      (trial (= 3 (length result)))
      (trial (equal? 'lambda (car result)))
      (trial (= 1 (length (cadr result))))
      
      (set! this-symbol (car (cadr result)))

      (trial (equal? `(object-set! ,this-symbol 'bar 'soap)
                     (caddr result)))

      
      (set! result (compute-instance-member-initializer '(members
                                                          foo
                                                          (bar init-value: 'soap)
                                                          (bash init-form: (shell current-directory)))))

      (trial (= 3 (length result)))
      (trial (equal? 'lambda (car result)))
      (trial (= 1 (length (cadr result))))
      
      (set! this-symbol (car (cadr result)))

      (trial (equal? `(object-set! ,this-symbol 'bash (shell current-directory))
                     (caddr result)))
      
      "end module test")

    
    "end module syntax")


  (import * from syntax)
  
  (define (default-class-function) #u)
  (define (default-class-method-function) #u)
  (define (default-instance-function) #u)
  (define (default-instance-method-function) #u)

  
  (define-generic make-class)
  (define-generic initialize-class)
  (define-generic initialize-class-members)
  (define-generic initialize-instance-default)

  (module metaclass

    (export MetaClass)
    
    (define (compute-class-function functor cpl)
      (auto-functor (functor (fold-functors default-class-function (pick class-functor: cpl)))))


    (define (compute-class-method-function functor name cpl)
      (functor (fold-functors default-class-method-function (pick name (pick class-method-functors: cpl)))))

    
    (define (compute-instance-function functor cpl)
      (auto-functor (functor (fold-functors default-instance-function (pick instance-functor: cpl)))))

    
    (define (compute-instance-method-function functor name cpl)
      (functor (fold-functors default-instance-method-function (pick name (pick instance-method-functors: cpl)))))


    (define (compute-class-methods named-functors cpl)
      (map (lambda (pair)
             ;;           "Each pair is a symbol and a function which computes
             ;;         the resultant method given the next method."
             (let ([name (car pair)]
                   [functor (cdr pair)])
               (cons name (compute-class-method-function functor name cpl))))
           named-functors))


    (define (compute-instance-methods named-functors cpl)
      (map (lambda (pair)
             ;;           "Each pair is a symbol and a function which computes
             ;;         the resultant method given the next method."
             (let ([name (car pair)]
                   [functor (cdr pair)])
               (cons name (compute-instance-method-function functor name cpl))))
           named-functors))


    (define (compute-all-members members type cpl)
      (apply append members (pick type (reverse cpl))))
    

    (define (compute-all-class-members members cpl)
      (compute-all-members members class-members: cpl))


    (define (compute-all-instance-members members cpl)
      (compute-all-members members instance-members: cpl))
    

    (define (compute-single-initializer all-members)
      (let ([inits (delete-duplicates all-members
                                      (lambda (x y)
                                        (equal? (car x) (car y))))])
        (lambda (this)
          (for-each (lambda (i)
                      (if (equal? init-value: (cadr i))
                          (object-set! this (car i) (cdr i))
                          (object-set! this (car i) ((cdr i)))))
                    inits))))


    (define (compute-early-initializer all-members)
      (let ([inits (map (lambda (m)
                          (cons (car m) (caddr m)))
                        (delete-duplicates (filter (lambda (m)
                                                     (equal? init-value: (cadr m)))
                                                   all-members
                                                   (lambda (x y)
                                                     (equal? (car x) (car y))))))])
        (lambda (this)
          (for-each (lambda (i)
                      (object-set! this (car i) (cdr i)))
                    inits))))


    (define (compute-late-initializer all-members)
      (let ([inits (map (lambda (m)
                          (cons (car m) (caddr m)))
                        (filter (lambda (m)
                                  (equal? init-form: (cadr m)))
                                (delete-duplicates all-members
                                                   (lambda (x y)
                                                     (equal? (car x) (car y))))))])
        (lambda (this)
          (for-each (lambda (i)
                      (object-set! this (car i) ((cdr i))))
                    inits))))


    (define (MetaClass . kwargs)
      (print "MetaClass\n")
      (bind kwargs ([name ""]
                    [class-specifier '()]
                    [direct-superclasses '()]
                    [class-functor #f]
                    [class-members '()]
                    [class-method-functors '()]
                    [instance-functor #f]
                    [instance-members '()]
                    [instance-method-functors '()])
        (let* ([cpl (compute-class-precedence-list direct-superclasses)]
               [C (compute-class-function class-functor cpl)]
               [class-methods (compute-class-methods class-method-functors cpl)]
               [instance-methods (compute-instance-methods instance-method-functors cpl)])
          (set! C.class-name name)
          (set! C.id (gensym name))
          (set! C.class-specifier class-specifier)
          (set! C.direct-superclasses direct-superclasses)
          (set! C.class-precedence-list `(,@cpl ,C))
          (set! C.class-functor class-functor)
          (set! C.class-members class-members)
          (set! C.class-method-functors (make-object class-method-functors))
          (set! C.instance-functor instance-functor)
          (set! C.instance-members instance-members)
          (set! C.instance-method-functors (make-object instance-method-functors))

          (set! C.class-function C)
          (set! C.class-methods (make-object class-methods))
          (set! C.initialize-class-members (compute-single-initializer (compute-all-class-members C.class-members cpl)))
          (set! C.instance-function (compute-instance-function instance-functor cpl))
          (set! C.instance-methods (make-object instance-methods))
          
          (let ([all-instance-members (compute-all-instance-members C.instance-members cpl)])
            (set! C.initialize-instance-default (compute-early-initializer all-instance-members))
            (set! C.initialize-instance-members (compute-late-initializer all-instance-members)))

          (object-extend! C C.class-methods)

          (set! C.constructor (lambda () { this } ))
          
          (set! C.constructor.prototype (object))
          (set! C.constructor.prototype.class C)
          (set! C.constructor.prototype.constructor C.constructor)
          
          (object-extend! C.constructor.prototype C.instance-methods)

          (initialize-instance-default C)
          (initialize-class-members C)
          (initialize-class C)
          
          C)))

    (module test

      (define-macro (trial stx)
        `(assert ,@(cdr stx) (format "%s failed" ',@(cdr stx))))

      (define-macro (fail stx)
        `(assert (eq? 'exception (except (lambda (e) 'exception)
                                   ,@(cdr stx)))
                 (format "%s failed" ',@(cdr stx))))


      (define C1 (object class-functor: (lambda (next-function)
                                          (lambda (This k v)
                                            (object-set! This k v)))))

      (define C2 (object class-functor: (lambda (next-function)
                                          (lambda (This x)
                                            (next-function This foo: (cons 'bar x))))))

      (define result (compute-class-function identity (list C1 C2)))

      
      (result 'soap)
      (trial (equal? '(bar . soap) result.foo))


      (define C1 (object class-method-functors:
                         (object foo: (lambda (next-method)
                                        (lambda (This k v)
                                          (object-set! This k v))))))

      (define C2 (object class-method-functors:
                         (object foo: (lambda (next-method)
                                        (lambda (This x)
                                          (next-method This foo: (cons 'bar x)))))))


      (set! result (compute-class-method-function (lambda (next-method)
                                                    (lambda (This x)
                                                      (next-method This x)
                                                      This.foo))
                                                  'foo (list C1 C2)))
      (define target (object))
      (trial (equal? '(bar soap) (result target '(soap))))

      
      (define C1 (object instance-functor: (lambda (next-function)
                                             (lambda (this k v)
                                               (cons (object-ref this k) v)))))

      (define C2 (object instance-functor: (lambda (next-function)
                                             (lambda (this x)
                                               (next-function this foo: (cons 'bar x))))))


      (set! result (compute-instance-function identity (list C1 C2)))
      (set! result.foo 'ivory)

      (trial (equal? '(ivory bar soap) (result '(soap))))

      (define C1 (object instance-method-functors:
                         (object foo: (lambda (next-method)
                                        (lambda (this k v)
                                          (object-set! this k v))))))

      (define C2 (object instance-method-functors:
                         (object foo: (lambda (next-method)
                                        (lambda (this x)
                                          (next-method this foo: (cons 'bar x)))))))


      (set! result (compute-instance-method-function (lambda (next-method)
                                                       (lambda (this x)
                                                         (next-method this x)
                                                         (reverse this.foo)))
                                                     'foo (list C1 C2)))

      
      (trial (equal? '(soap bar) (result target '(soap))))

      "end module test")

    "end module metaclass")
  

  (import * from metaclass)

  (define-generic initialize-instance-constructor)
  
  (define-class Class ()
    
    (metaclass MetaClass)
    
    (class-function (This . args)
      (let ([class (make-class This)])
        (set! class.class This)
        (apply This.instance-methods.initialize class args)
        class))


    (class-method (make-class This)
      (compute-instance-function This This))
    
    
    (class-method (make-instance This)
      (new! This.constructor))


    (class-method (initialize-class This)
      (set! This.class This))


    (class-method (compute-class-function This instance)
      (print "compute-class-function\n")
      (auto-functor (fold-functors This.default-class-function
                                   (pick class-functor: instance.class-precedence-list))))


    (class-method (compute-class-method-function This instance name)
      (print "compute-class-method-function\n")
      (fold-functors This.default-class-method-function
                     (pick name (pick class-method-functors: instance.class-precedence-list))))


    (class-method (compute-instance-function This instance)
      (print "compute-instance-function\n")
      (printf "%s\n" instance.class-precedence-list)
      (auto-functor (fold-functors This.default-instance-function
                                   `(,@(pick instance-functor: instance.class-precedence-list)
                                     ,instance.instance-functor))))

    
    (class-method (compute-instance-method-function This instance name)
      (print "compute-instance-method-function\n")
      (fold-functors This.default-instance-method-function
                     (pick name (pick instance-method-functors: instance.class-precedence-list))))


    (class-method (compute-class-methods This instance)
      (print "compute-class-methods\n")
      (let ([methods (object)])
        (for-each (lambda (name)
                    (object-set! methods name (compute-class-method-function This instance name)))
                  (delete-duplicates (apply append (pick class-method-names: instance.class-precedence-list))))
        methods))


    (class-method (compute-instance-methods This instance)
      (print "compute-instance-methods\n")
      (let ([methods (object)])
        (for-each (lambda (name)
                    (object-set! methods name (compute-instance-method-function This instance name)))
                  (delete-duplicates (apply append (pick instance-method-names: instance.class-precedence-list))))
        methods))

    
    (class-method (compute-all-members This instance type)
      (print "compute-all-members\n")
      (apply append (pick type (reverse instance.class-precedence-list))))
    

    (class-method (compute-all-class-members This instance)
      (print "compute-all-class-members\n")
      (compute-all-members This instance class-members:))


    (class-method (compute-all-instance-members This instance)
      (print "compute-all-instance-members\n")
      (compute-all-members This instance instance-members:))


    (class-method (compute-single-initializer This all-members)
      (print "compute-single-initializer\n")
      (let ([inits (delete-duplicates all-members
                                      (lambda (x y)
                                        (equal? (car x) (car y))))])
        (lambda (this)
          (for-each (lambda (i)
                      (if (equal? init-value: (cadr i))
                          (object-set! this (car i) (cdr i))
                          (object-set! this (car i) ((cdr i)))))
                    inits))))


    (class-method (compute-early-initializer This all-members)
      (print "compute-early-initializer\n")
      (let ([inits (map (lambda (m)
                          (cons (car m) (caddr m)))
                        (delete-duplicates (filter (lambda (m)
                                                     (equal? init-value: (cadr m)))
                                                   all-members
                                                   (lambda (x y)
                                                     (equal? (car x) (car y))))))])
        (lambda (this)
          (for-each (lambda (i)
                      (object-set! this (car i) (cdr i)))
                    inits))))


    (class-method (compute-late-initializer This all-members)
      (print "compute-late-initializer\n")
      (let ([inits (map (lambda (m)
                          (cons (car m) (caddr m)))
                        (filter (lambda (m)
                                  (equal? init-form: (cadr m)))
                                (delete-duplicates all-members
                                                   (lambda (x y)
                                                     (equal? (car x) (car y))))))])
        (lambda (this)
          (for-each (lambda (i)
                      (object-set! this (car i) ((cdr i))))
                    inits))))


    (class-method (compute-initialize-class-members This instance)
      (print "compute-initialize-class-members\n")
      (compute-single-initializer This instance.all-class-members))


    (class-method (compute-initialize-instance-default This instance)
      (print "compute-initialize-instance-default\n")
      (compute-early-initializer This instance.all-instance-members))


    (class-method (compute-initialize-instance-members This instance)
      (print "compute-initialize-instance-members\n")
      (compute-late-initializer This instance.all-instance-members))


    (class-members (default-class-function:           init-value: (lambda () #u))
                   (default-class-member-function:    init-value: (lambda () #u))
                   (default-instance-function:        init-value: (lambda () #u))
                   (default-instance-method-function: init-value: (lambda () #u)))


    (instance-function (this . args)
      (let* ([instance (make-instance this)])
        (this.initialize-instance-members instance)
        (apply initialize instance args)
        instance))


    (method (initialize this . kwargs)
      (bind kwargs ([name ""]
                    [class-specifier '()]
                    [direct-superclasses '()]
                    [class-functor #f]
                    [class-members '()]
                    [class-method-functors '()]
                    [instance-functor #f]
                    [instance-members '()]
                    [instance-method-functors '()])
        (let ([Class this.class])
          
          (assert (symbol? name)
                  (format "Class: name: symbol expected: %s." name))

          (assert (list? class-specifier)
                  (format "Class: class-specifier: list expected: %s." class-speecifier))

          (assert (list? direct-superclasses)
                  (format "Class: direct-superclasses: list expected: %s." class-speecifier))

          ;;           (debug
          ;;            (for-each (lambda (c i)
          ;;                        (assert (class? c)
          ;;                                (format "Class: direct superclass #%s is not a class: %s." i c)))
          ;;                      direct-superclasses
          ;;                      (range 1 (+ 1 (length direct-superclasses)))))

          
          (set! this.class-name                   name)
          (set! this.id                           (gensym name))
          (set! this.instance-tag                 (string-append (symbol->string this.id) " instance "))
          (set! this.class-specifier              class-specifier)
          (set! this.direct-superclasses          direct-superclasses)
          (set! this.class-precedence-list        `(,@(compute-class-precedence-list direct-superclasses) ,this))
          (set! this.class-functor                class-functor)
          (set! this.class-method-names           (map car class-method-functors))
          (set! this.class-method-functors        (make-object class-method-functors))
          (set! this.class-members                class-members)
          (set! this.instance-functor             instance-functor)
          (set! this.instance-method-names        (map car instance-method-functors))
          (set! this.instance-method-functors     (make-object instance-method-functors))
          (set! this.instance-members             instance-members)

          (set! this.class-function               (compute-class-function Class this))
          (set! this.all-class-members            (compute-all-class-members Class this))
          (set! this.initialize-class-members     (compute-initialize-class-members Class this))
          (set! this.class-methods                (compute-class-methods Class this))
          (set! this.instance-function            (compute-instance-function Class this))
          (set! this.instance-methods             (compute-instance-methods Class this))
          (set! this.all-instance-members         (compute-all-instance-members Class this))
          (set! this.initialize-instance-default  (compute-initialize-instance-default Class this))
          (set! this.initialize-instance-members  (compute-initialize-instance-members Class this))

          (object-extend! this this.class-methods)

          (initialize-instance-constructor this)
          (initialize-class-members this)
          (initialize-class this))))


    "end class Class")

  (set! class.default-metaclass Class)


  (define-class Base ()
    (class-method (initialize-class)
      #u)
    
    (class-method (make-instance This)
      (new! This.constructor))

    (class-method (initialize-instance-constructor This)
      (set! This.constructor (lambda () (print "Base constructor\n") { this } ))
      
      (set! This.constructor.prototype (object))
      (set! This.constructor.prototype.class This)
      (set! This.constructor.prototype.constructor This.constructor)
      
      (object-extend! This.constructor.prototype This.instance-methods)
      
      (This.initialize-instance-default This.constructor.prototype))

    (method (initialize this . kwargs)
      (set! this.id (gensym this.class.instance-tag))
      (for-each (lambda (pair)
                  (let ([key (car pair)]
                        [value (cdr pair)])
                    
                    (assert (defined? value)
                            (format "Incomplete keyword argument %s while initializing %s instance." key this.class.class-name))
                  
                    (assert (exists (lambda (m)
                                      (equal? key (car m)))
                                    this.class.all-instance-members)
                            (format "Unrecognized keword argument %s while initializing %s instance." key this.class.class-name))

                    (object-set! this key value)))
                (pairs kwargs)))
    
    "end class Base")

  (define (subclass? A B)
    (member B A.class-precedence-list))

  (define (superclass? A B)
    (subclass? B A))

  (define (instance? A B)
    (and (or (object? A)
             (function? A))
         (defined? A.class)
         (class? A.class)
         (or (not (defined? B))
             (subclass? A.class B))))

  (define (class? A)
    (and (function? A)
         (defined? A.class)
         (subclass? A.class Class)))

  "End module mop")