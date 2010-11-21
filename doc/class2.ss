(module mop

  (define (delete-duplicates L)
    (reverse
     (fold-left (lambda (result x)
                  (if (member x result)
                      result
                      (cons x result)))
                '()
                (cdr L))))

  (define (pick objs sym)
    (map (lambda (obj)
           (object-ref obj sym))
         objs))

  (define (get-keyword-option options kw def)
    (let ([tail (member kw options)])
      (and tail (cadr tail))))


  (define-macro (bind stx)
    (let* ([target (cadr stx)]
           [bindings (map (lambda (b)
                            (if (list? b)
                                `(,(car b) (get-keyword-option ,target ',(car b) ,(cadr b)))
                                `(,b (get-keyword-option ,target ',b #f))))
                          (caddr stx))]
           [body (cddr stx)])
      `(let ,bindings ,@body)))

  
  (define (Class . options))

  (define default-meta-class Class)

  (define (default-class-function))
  (define (default-instance-function))
  (define (default-method-function))

  (define class-this-parameter-name 'This)
  (define class-next-function-name 'next-function)
  
  (define class-method-this-parameter-name 'This)
  (define class-method-next-function-name 'next-method)
  
  (define instance-this-parameter-name 'this)
  (define instance-next-function-name 'next-function)
  
  (define method-this-parameter-name 'this)
  (define method-next-function-name 'next-method)
  
  (define (all-clauses clauses kw)
    "clauses is a list of specification clauses, each a list headed by
a keyword or symbol indicating the clause type.  kw is a symbol or
keyword indicating the clause types to be returned.
    "
    (filter (lambda (x)
              (and (list? x)
                   (equal? (car x) kw)))
            clauses))

  (define (get-clause clauses kw default)
    (let ([all (all-clauses clauses kw)])
      (case (length all)
        [(0) default]
        [(1) (car all)]
        [else (assert #f)])))


  (define (compute-class-precedence-list direct-supers))
  
  "Computes the class precedence list for a given list of direct superclasses.
Note that the direct superclasses are in specification order; that is,
the most specific class is first, the most fundamental last.  The
result of this function has the reverse order, from most fundamental
to most specific.
"

  (delete-duplicates
   (apply append
          (map (lambda (super)
                 super.class-precedence-list)
               (reverse direct-supers))))


  (define (compute-functor s this-symbol next-symbol)
    (and s
         (if (list? (cadr s))
             (let ([name (caadr s)]
                   [formals (cons this-symbol (cdadr s))]
                   [body (cddr s)])
               `(cons ,name (lambda (,next-symbol)
                              (lambda ,formals ,@body))))
             
             (let ([name (cadr s)]
                   [body (cddr s)])
               `(cons ,name ,@body)))))


  (define (compute-class-functor specifier)
    (compute-functor specifier
                     class-this-parameter-name
                     class-next-function-name))


  (define (compute-class-method-functor specifier)
    (compute-functor specifier
                     class-method-this-parameter-name
                     class-method-next-function-name))


  (define (compute-instance-functor specifier)
    (compute-functor specifier
                     instance-this-parameter-name
                     instance-next-function-name))


  (define (compute-method-functor specifier)
    (compute-functor specifier
                     method-this-parameter-name
                     method-next-function-name))


  (define (compute-class-function functor cpl)
    (functor
     (fold-left (lambda (f functor) (functor f))
                default-class-function
                (pick class-functor: cpl))))


  (define (compute-class-method-function functor name cpl)
    (functor
     (fold-left (lambda (f functor) (functor f))
                default-class-method-function
                (pick name (pick class-functor: cpl)))))


  (define (compute-instance-function functor cpl)
    (functor 
     (fold-left (lambda (f functor)
                  (functor f))
                default-instance-function
                (pick instance-functor: cpl))))

  (define (compute-initialize-class f cpl)
    (lambda (obj)
      (for-each (lambda (f)
                  (f obj))
                (pick class-initializer: cpl))
      (f obj)))


  (define (compute-method-function functor name cpl)
    (functor
     (fold-left (lambda (f functor) (functor f))
                default-method-function
                (pick name (pick method-functors: cpl)))))


  (define (compute-class-methods named-functors cpl)
    (map (lambda (pair)
           "Each pair is a symbol and a function which computes
         the resultant method given the next method."
           (let ([name (car pair)]
                 [functor (cdr pair)])
             (cons name
                   (functor (compute-class-method-function name cpl)))))
         named-functors))


  (define (compute-instance-methods named-functors cpl)
    (map (lambda (pair)
           "Each pair is a symbol and a function which computes
         the resultant method given the next method."
           (let ([name (car pair)]
                 [functor (cdr pair)])
             (cons name
                   (functor (compute-method-function name cpl)))))
         named-functors))


  (define (compute-class-member-initializers specifiers obj-symbol)
    (let loop ([bindings '()]
               [forms '()]
               [specifiers specifiers])
      (if (null? specifiers)
          (values (reverse bindings) (reverse forms))
          (let ([s (car specifiers)])
            (if (list? s)
                (let* ([name (car s)]
                       [options (cdr s)]
                       [value (get-keyword-option options init-value: #u)]
                       [form (get-keyword-option options init-form: #u)])
                  (assert (not (and (defined? form) (defined? value))))
                  (cond [(defined? form)
                         (loop bindings
                               (cons `(object-set! ,obj-symbol ,name ,form)
                                     forms)
                               (cdr specifiers))]

                        [(defined? value)
                         (let ([sym (gensym name)])
                           (loop (cons (list sym value) bindings)
                                 (cons `(object-set! ,obj-symbol ,name ,sym)
                                       forms)
                                 (cdr specifiers)))]

                        [#t
                         (loop bindings forms (cdr specifiers))]))
                (loop bindings forms (cdr specifiers)))))))



  (define (compute-class-initializer member-specifiers)
    (let ([obj-symbol (gensym 'obj)])
      (let-values ([(initial-value-bindings initialization-forms)
                    (compute-class-member-initializers member-specifiers obj-symbol)])
        `(let ,initial-value-bindings
           (lambda (,obj-symbol)
             ,@initialization-forms)))))


  (define (compute-instance-default-initializer member-specifiers)
    (let ([obj-symbol (gensym 'obj)])
      `(lambda (,obj-symbol)
         ,@(filter true? (map (lambda (s)
                                (and (list? s)
                                     (let ([name (car s)]
                                           [value (get-keyword-option (cdr s) init-value: #f)])
                                       (and value
                                            `(object-set! ,obj-symbol ,name ,value)))))
                              member-specifiers)))))



  (define (compute-instance-initializer member-specifiers)
    (let ([obj-symbol (gensym 'obj)])
      `(lambda (,obj-symbol)
         ,@(filter true? (map (lambda (s)
                                (and (list? s)
                                     (let ([name (car s)]
                                           [form (get-keyword-option (cdr s) init-form: #f)])
                                       (and form
                                            `(object-set! ,obj-symbol ,name ,form)))))
                              member-specifiers)))))


  (define-macro (define-class stx)
    "
    (define-class name (list of base classes)
      (metaclass foo)
      (class-function (args) body...)  ; where 'class is defined in body
      (class-methods
         ...)
      (class-members
         ...)
      (instance-function (args) body) ;  where 'self is defined in body
      (method (name . args)
        (apply next-method args)
        body...)

      (metaclass foo)

      (method (name . args)
        (apply next-method args)
        body...)
      ...

      (members
        foo
        (bar init-value: anything init-form: (sexp ...))
  "
    (assert (>= 3 (length stx)))
    (let* ([name (cadr stx)]
           [direct-supers (caddr stx)]
           [body (cdddr stx)]
           [metaclass-specifier (get-clause body 'metaclass #f)]
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
                class-precedence-list: (compute-class-precedence-list (list ,@base))
                instance-functor: ,(compute-instance-functor instance-functor-specifier)
                instance-method-functors: (list ,@(map compute-method-functor method-specifiers))
                instance-default-initializer: ,(compute-instance-default-initializer member-specifiers)
                instance-initializer: ,(compute-instance-initializer member-specifiers)))))


  (define-macro (instance-function stx)
    (compute-instance-functor stx))

  (define-macro (method stx)
    (compute-method-functor stx))

  (define (ProtoClass . kwargs)
    (bind kwargs
      ([name '']
       [class-specifier '()]
       [class-precedence-list '()]
       [instance-functor #f]
       [instance-default-intializer #f]
       [instance-initializer #f]
       [instance-method-functors #f])
      (let ([C (make-class-instance)]
            [cpl class-precedence-list]
            [class-methods (compute-class-methods class-method-functors cpl)]
            [instance-methods (compute-instance-methods instance-method-functors cpl)])
        (set! C.name name)
        (set! C.class-specifier class-specifier)
        (set! C.class-precedence-list class-precedence-list)
        (set! C.class-initializer class-initializer)
        (set! C.class-method-functors (make-object class-method-functors))
        (set! C.instance-functor instance-functor)
        (set! C.instance-default-initializer instance-default-initializer)
        (set! C.instance-initializer instance-initializer)
        (set! C.instance-method-functors (make-object instance-method-functors))

        (set! C.class-function (compute-class-function class-functor cpl))
        (set! C.class-methods (make-object class-methods))
        (set! C.initialize-class (compute-initialize-class C.class-initializer cpl))
        (set! C.instance-function (compute-instance-function instance-functor cpl))
        (set! C.instance-methods (make-object instance-methods))
        (set! C.initialize-instance-default (compute-initialize-instance-default C.instance-default-initializer cpl))
        (set! C.initialize-instance (compute-initialize-instance C.instance-initializer cpl))

        (for-each (lambda (pair)
                    (object-set! C (car pair) (cadr pair)))
                  class-methods)

        (initialize-class C)
        
        (set! C.prototype (or C.instance-function (Object)))
        
        (initialize-instance-default C.prototype)

        (for-each (lambda (pair)
                    (object-set! C.prototype (car pair) (cadr pair)))
                  instance-methods)

        (set! C.prototype.constructor C))))


  (define-class Class
    
    (metaclass ProtoClass)
    
    (class-function (This . kwargs)
      (let ([class (make-instance This)])
        (initialize-class This class kwargs)
        class))

    (class-method (initialize-class This class kwargs)
      (bind kwargs ([name '']
                    [class-specifier '()]
                    [class-precedence-list '()]
                    [class-functor #f]
                    [class-initializer #f]
                    [class-method-functors #f]
                    [instance-functor #f]
                    [instance-default-intializer #f]
                    [instance-initializer #f]
                    [instance-method-functors #f])
        (let ([cpl class-precedence-list]
              [class-methods (make-object (compute-class-methods This class-method-functors cpl))]
              [instance-methods (make-object (compute-instance-methods This instance-method-functors cpl))])
          
          (for-each (lambda (c)
                      (c.class-initializer class)
                      (object-extend! class c.class-methods))
                    cpl)

          (class-initializer class)
          (object-extend! class class-methods)

          (set! class.name name)
          (set! class.metaclass This)
          (set! class.class-specifier class-specifier)
          (set! class.class-precedence-list class-precedence-list)
          (set! class.class-functor class-functor)
          (set! class.class-initializer class-initializer)
          (set! class.class-method-functors (make-object class-method-functors))
          (set! class.instance-functor instance-functor)
          (set! class.instance-default-initializer instance-default-initializer)
          (set! class.instance-initializer instance-initializer)
          (set! class.instance-method-functors (make-object instance-method-functors))

          (set! class.class-function (compute-class-function This class-functor cpl))
          (set! class.class-methods class-methods)
          (set! class.instance-function (compute-instance-function This instance-functor cpl))
          (set! class.instance-methods instance-methods)
          (set! class.initialize-instance (compute-initialize-instance This class.instance-initializer cpl))

          (set! class.instance-constructor (lambda () #u))
          (set! class.instance-constructor.prototype (or class.instance-function (Object)))
          
          (for-each (lambda (c)
                      (c.instance-default-initializer class.instance-constructor.prototype)
                      (object-extend! class.instance-constructor.prototype c.instance-methods))
                    cpl)
          
          (class.instance-default-initializer class.instance-constructor.prototype)
          (object-extend! class.instance-constructor.prototype class.instance-methods)

          (set! class.instance-constructor.prototype.constructor class.instance-constructor))))
    
    
    (class-method (make-instance This)
      (compute-instance-function This This.instance-functor cpl))
    
    (class-method (compute-class-function This functor cpl)
      (functor
       (fold-left (lambda (f functor) (functor f))
                  This.default-class-function
                  (pick class-functor: cpl))))


    (class-method (compute-class-method-function This functor name cpl)
      (functor
       (fold-left (lambda (f functor) (functor f))
                  This.default-class-method-function
                  (pick name (pick class-functor: cpl)))))


    (class-method (compute-instance-function This functor cpl)
      (functor 
       (fold-left (lambda (f functor)
                    (functor f))
                  This.default-instance-function
                  (pick instance-functor: cpl))))

    
    (class-method (compute-instance-method-function This functor name cpl)
      (functor
       (fold-left (lambda (f functor) (functor f))
                  This.default-instance-method-function
                  (pick name (pick method-functors: cpl)))))


    (class-method (compute-class-methods This named-functors cpl)
      (map (lambda (pair)
             "Each pair is a symbol and a function which computes
         the resultant method given the next method."
             (let ([name (car pair)]
                   [functor (cdr pair)])
               (cons name
                     (functor (compute-class-method-function This name cpl)))))
           named-functors))


    (class-method (compute-instance-methods This named-functors cpl)
      (map (lambda (pair)
             "Each pair is a symbol and a function which computes
         the resultant method given the next method."
             (let ([name (car pair)]
                   [functor (cdr pair)])
               (cons name
                     (functor (compute-instance-method-function This name cpl)))))
           named-functors))


    (instance-function (this . kwargs)
      (let ([instance (make-instance this)])
        (initialize-instance this instance)
        (initialize instance)
        instance))

    (method (make-instance this)
      (new! this.instance-constructor))

    (class-method (compute-class-methods This class-method-functors cpl)
    ))  

  "End module Mop")

