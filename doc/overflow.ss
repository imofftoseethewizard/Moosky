  (define-class Class
    
    (metaclass ProtoClass)
    
    (class-function (This . kwargs)
      (let ([class (make-instance This)])
        (initialize-class This class kwargs)
        class))

    (class-method (make-instance This)
      (compute-instance-function This This.instance-functor This.class-precedence-list))
    
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
;;             "Each pair is a symbol and a function which computes
;;         the resultant method given the next method."
             (let ([name (car pair)]
                   [functor (cdr pair)])
               (cons name
                     (functor (compute-class-method-function This name cpl)))))
           named-functors))


    (class-method (compute-instance-methods This named-functors cpl)
      (map (lambda (pair)
;;             "Each pair is a symbol and a function which computes
;;         the resultant method given the next method."
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

    "End class Class")
