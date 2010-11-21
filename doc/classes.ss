"
Architecture of Objects/Classes:

Object-oriented programming is, in my view, one of a set of highly
idiomatic forms of structured function composition.  While Javascript
supports it's own variant internally, it is also possible to define
alternate idioms.  In the case of Moosky, its lisp heritage presents
an alternate view of objects in which lack the notion of this or self,
primarily due to the influence of multiple-dispatch generics in CLOS
and the Meta-Object Protocol.  Since this seems now to flow more
naturally with lisp syntax, I've chosen to support objects using
prototype inheritance for members, but using the following trivial
generic implementation, rather than use the this keyword.  (Part of the
reason for avoiding this, is that a basic debugging system can be
structured using the this pointers as a basis for stack walking.)

Three different class implementations:

class-0:
  no inheritance
  next-method is provided as a null stub.
  this is essentially a record with methods

class-1:
  single inheritance
  next-method is resolved at parse time

class-k:
  multiple inheritance
  next-method is resolved at parse time
"

(define-macro (define-generic stx)
  (let ([name (cadr stx)])
    `(define ,name
      (lambda (o . args)
        (apply (object-ref o ',name) o args)))))

(define-generic init)

(define-macro (new! stx)
  `(JS (NEW ,(cadr stx) ,(cddr stx))))

(define (make-instance-prototype args)
  (make-object args))

(define (delete-duplicates L)
  (reverse
   (fold-left (lambda (result x)
                (if (member x result)
                    result
                    (cons x result)))
              '()
              (cdr L))))

(define (compute-class-precedence-list direct-supers)
  
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
               (reverse direct-supers)))))


(define (compute-member-initializers specifiers obj-symbol)
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
                                     
                             

(define (compute-initializer member-specifiers)
  (let ([obj-symbol (gensym 'obj)])
    (let-values ([(initial-value-bindings initialization-forms)
                  (compute-member-initializers member-specifiers obj-symbol)])
      `(let ,initial-value-bindings
         (lambda (,obj-symbol)
           ,@initialization-forms)))))


(define (compute-functor s next-symbol)
  (and s
       (if (list? (cadr s))
           (let ([name (caadr s)]
                 [formals (cdadr s)]
                 [body (cddr s)])
             `(cons ,name (lambda (,next-symbol)
                            (lambda ,formals ,@body))))
           
           (let ([name (cadr s)]
                 [body (cddr s)])
             `(cons ,name (lambda (,next-symbol)
                            ,@body))))))


(define (compute-method-functors method-specifiers)
  (map (lambda (s)
         (compute-functor s 'next-method))
       method-specifiers))


(define (compute-method name cpl)
  (let loop ([next-method default-next-method]
             [cpl cpl])
    (if (null? cpl)
        next-method
        (let* ([c (car cpl)]
               [functor (object-ref c.method-functors name)])
          (if functor
              (loop (functor next-method) (cdr cpl))
              (loop next-method (cdr cpl)))))))


;class
;is-a
;kind-of

(define class-function-parameter 'class)
(define instance-function-parameter 'self)

(define (Class . options)

(define default-meta-class Class)

(define (all-clauses clauses kw)
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


(define (pick objs sym)
  (map (lambda (obj)
         (object-ref obj sym))
       objs))


(define (compute-class-function functor cpl)
  (functor
   (fold-left (lambda (f functor) (functor f))
              default-class-function
              (pick class-functor: cpl))))


(define (compute-instance-function functor cpl)
  (functor 
   (fold-left (lambda (f functor)
                (functor f))
              default-instance-function
              (pick instance-functor: cpl))))


(define (compute-method-function functor name cpl)
  (functor
   (fold-left (lambda (f functor) (functor f))
              default-method-function
              (pick name (pick method-functors: cpl)))))

  
(define (make-methods named-functors cpl)
  (map (lambda (pair)
         "Each pair is a symbol and a function which computes
         the resultant method given the next method."
         (let ([name (car pair)]
               [functor (cdr pair)])
           (cons name
                 (functor (compute-method-function name cpl)))))
       named-functors))))))
      
(define-macro (define-class stx)
  "(define-class name (list of base classes)
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

    (members
      foo
      (bar init-value: anything init-form: (sexp ...))


  "
  (assert (>= 3 (length stx)))
  (let* ([name (cadr stx)]
         [direct-supers (caddr stx)]
         [body (cdddr stx)]
         [metaclass-specifier (get-clause body 'metaclass #f)]
         [method-specifiers (all-clauses body 'method)]
         [member-specifiers (apply append (map cdr (all-clauses body 'members)))])
    
    (assert (symbol? name))
    (assert (list? direct-supers))
    `(let ([Class ,(if metaclass-specifier
                       (cadr metaclass-specifier)
                       default-metaclass)]
           [name ',name]
           [cpl (compute-precedence-list (list ,@base))]
           [init-functor ,(compute-init-functor member-specifiers)]
           [method-functors (list ,@(compute-method-functors method-specifiers))])
                          
       (Class
         name: name
         
         class-specifier: ',(cdr stx)
         class-precedence-list: cpl
         
         init-functor: init-functor
         initializer: (compute-initializer init-functor cpl)
         
         method-functors: (make-object method-functors)
         methods: (make-object (make-methods method-functors cpl))))))
