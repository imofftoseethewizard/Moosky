(module mop

  (import * from digraph)
  (export *)
  
  (define (delete-duplicates L)
    (reverse
     (fold-left (lambda (result x)
                  (if (member x result)
                      result
                      (cons x result)))
                '()
                L)))

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


  (define (default-class-function) #u)
  (define (default-class-method-function) #u)
  (define (default-instance-function) #u)
  (define (default-instance-method-function) #u)

  (define class-this-parameter-name 'This)
  (define class-next-function-name 'next-function)
  
  (define class-method-this-parameter-name 'This)
  (define class-method-next-function-name 'next-method)
  
  (define instance-this-parameter-name 'this)
  (define instance-next-function-name 'next-function)
  
  (define method-this-parameter-name 'this)
  (define method-next-function-name 'next-method)
  

  (define (fold-functors f-initial functors)
    (fold-left (lambda (f functor)
                 (if functor
                     (functor f)
                     f))
               f-initial
               functors))
  

  (define (compute-class-function functor cpl)
    (fold-functors default-class-function (pick class-functor: cpl)))


  (define (compute-class-method-function functor name cpl)
    (fold-functors default-class-method-function (pick name (pick class-method-functors: cpl))))

  
  (define (compute-instance-function functor cpl)
    (fold-functors default-instance-function (pick instance-functor: cpl)))

  
  (define (compute-instance-method-function functor name cpl)
    (fold-functors default-instance-method-function (pick name (pick instance-method-functors: cpl))))


  (define (compute-class-methods named-functors cpl)
    (map (lambda (pair)
           ;;           "Each pair is a symbol and a function which computes
           ;;         the resultant method given the next method."
           (let ([name (car pair)]
                 [functor (cdr pair)])
             (cons name
                   (functor (compute-class-method-function name cpl)))))
         named-functors))


  (define (compute-instance-methods named-functors cpl)
    (map (lambda (pair)
           ;;           "Each pair is a symbol and a function which computes
           ;;         the resultant method given the next method."
           (let ([name (car pair)]
                 [functor (cdr pair)])
             (cons name
                   (functor (compute-instance-method-function name cpl)))))
         named-functors))


  (define (compute-initialize-class f cpl)
    (let ([initializers (filter identity
                                (append (pick class-initializer: cpl)
                                        (list f)))])
      (lambda (obj)
        (for-each (lambda (init)
                    (init obj))
                  initializers))))


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



  (define (compute-class-initializer member-specifiers)
    (let ([obj-symbol (gensym 'This)])
      (let* ([initializers (compute-class-member-initializers member-specifiers obj-symbol)]
             [initial-value-bindings (car initializers)]
             [initialization-forms (cdr initializers)])
        `(let ,initial-value-bindings
           (lambda (,obj-symbol)
             ,@initialization-forms)))))


  (define (compute-instance-default-initializer member-specifiers)
    (let ([obj-symbol (gensym 'this)])
      `(lambda (,obj-symbol)
         ,@(filter identity (map (lambda (s)
                                   (and (list? s)
                                        (let ([name (car s)]
                                              [value (get-keyword-option (cdr s) init-value: #f)])
                                          (and value
                                               `(object-set! ,obj-symbol ',name ,value)))))
                                 member-specifiers)))))



  (define (compute-instance-initializer member-specifiers)
    (let ([obj-symbol (gensym 'this)])
      `(lambda (,obj-symbol)
         ,@(filter identity (map (lambda (s)
                                   (and (list? s)
                                        (let ([name (car s)]
                                              [form (get-keyword-option (cdr s) init-form: #f)])
                                          (and form
                                               `(object-set! ,obj-symbol ',name ,form)))))
                                 member-specifiers)))))

  
  (define-macro (define-class stx)
    ;;    (define-class name (list of base classes)
    ;;      (metaclass foo)
    ;;      (class-function (args) body...)  ; where 'class is defined in body
    ;;      (class-methods
    ;;         ...)
    ;;      (class-members
    ;;         ...)
    ;;      (instance-function (args) body) ;  where 'self is defined in body
    ;;      (method (name . args)
    ;;        (apply next-method args)
    ;;        body...)
    ;;
    ;;      (metaclass foo)
    ;;
    ;;      (method (name . args)
    ;;        (apply next-method args)
    ;;        body...)
    ;;      ...
    ;;
    ;;      (members
    ;;        foo
    ;;        (bar init-value: anything init-form: (sexp ...))

    (assert (>= 3 (length stx)))
    (let* ([name (cadr stx)]
           [direct-supers (caddr stx)]
           [body (cdddr stx)]
           [metaclass-specifier (get-clause body 'metaclass #f)]
           [class-functor-specifier (get-clause body 'class-function #f)]
           [class-method-specifiers (all-clauses body 'class-method)]
           [class-member-specifiers (apply append (map cdr (all-clauses body 'class-members)))]
           [instance-functor-specifier (get-clause body 'instance-function #f)]
           [method-specifiers (all-clauses body 'method)]
           [member-specifiers (apply append (map cdr (all-clauses body 'members)))])
      
      (assert (symbol? name))
      (assert (list? direct-supers))
      `(let ([Class ,(if metaclass-specifier
                         (cadr metaclass-specifier)
                         default-metaclass)])
         (Class name: ',name
                class-specifier: ',(cdr stx)
                direct-superclasses: direct-supers
                class-precedence-list: (compute-class-precedence-list (list ,@direct-supers))
                class-functor: ,(compute-class-functor class-functor-specifier)
                class-initializer: ,(compute-class-initializer class-member-specifiers)
                class-method-functors: (list ,@(map compute-class-method-functor class-method-specifiers))
                instance-functor: ,(compute-instance-functor instance-functor-specifier)
                instance-method-functors: (list ,@(map compute-instance-method-functor method-specifiers))
                instance-default-initializer: ,(compute-instance-default-initializer member-specifiers)
                instance-initializer: ,(compute-instance-initializer member-specifiers)))))


  (define-macro (class-function stx)
    (compute-class-functor stx))

  (define-macro (class-method-function stx)
    (compute-class-method-functor stx))

  (define-macro (instance-function stx)
    (compute-instance-functor stx))

  (define-macro (method stx)
    (compute-instance-method-functor stx))

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


    (define C1 (object class-functor: (lambda (next-function)
                                        (lambda (This k v)
                                          (object-set! This k v)))))

    (define C2 (object class-functor: (lambda (next-function)
                                        (lambda (This x)
                                          (next-function This foo: (cons 'bar x))))))


    (define result (compute-class-function identity (list C1 C2)))

    
    (define target (object))
    (result target 'soap)
    (trial (equal? '(bar . soap) target.foo))


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

  
    (trial (equal? '(bar soap) (result target '(soap))))

    
    (define C1 (object instance-functor: (lambda (next-function)
                                           (lambda (this k v)
                                             (cons (object-ref this k) v)))))

    (define C2 (object instance-functor: (lambda (next-function)
                                           (lambda (this x)
                                             (next-function this foo: (cons 'bar x))))))


    (set! result (compute-instance-function identity (list C1 C2)))
    (set! target (object foo: 'ivory))

    (trial (equal? '(ivory bar soap) (result target '(soap))))

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

  
    (trial (equal? '(bar soap) (result target '(soap))))

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

    (set! result (compute-class-initializer '(class-members
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

    
    (set! result (compute-instance-initializer '(members
                                                 foo
                                                 (bar init-value: 'soap)
                                                 (bash init-form: (shell current-directory)))))

    (trial (= 3 (length result)))
    (trial (equal? 'lambda (car result)))
    (trial (= 1 (length (cadr result))))
    
    (set! this-symbol (car (cadr result)))

    (trial (equal? `(object-set! ,this-symbol 'bash (shell current-directory))
                   (caddr result)))
    

    (printf "%s\n" (apply define-class '((define-class Foo (metaclass Foozerizer)))))
    
    "End module Test")
  
  "End module Mop")
