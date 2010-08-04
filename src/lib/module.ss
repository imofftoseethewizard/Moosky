(define (module? x)
  { typeof(x) == 'object' && x.$namespace !== undefined})

(define (make-module name base namespace)
  (let ([new-module (Moosky.Runtime.exports.makeFrame base)])
    (object-set! new-module "$name" name)
    (object-set! new-module "$namespace" (default namespace
                                           (format "%s.%s"
                                                   (object-ref base "$namespace") name)))
    (object-set! new-module "$exports" (Object))
    (object-set! new-module "current-module" (lambda () new-module))
    new-module))

(define print Moosky.HTML.print)
(define (printf fmt . args)
  (print (apply format (cons fmt args))))

(define (parse-aka-spec name-spec error-fmt)
  (cond [(list? name-spec)
         (assert (and (= 3 (length name-spec))
                      (eq? 'as (cadr name-spec))) (format error-fmt name-spec))
         `(,(caddr name-spec) . ,(car name-spec))]

        [#t
         `(,name-spec . ,name-spec)]))

(define (parse-export-spec name-spec)
  (let* ([parsed-spec (parse-aka-spec name-spec "Improper exported name specification: <symbol> or (<expr> as <symbol>) expected: %s")])
    (assert (symbol? (car parsed-spec))"Improper exported name specification: <symbol> or (<expr> as <symbol>) expected: %s")
    parsed-spec))

(define (parse-import-spec name-spec)
  (parse-aka-spec name-spec "Improper imported name specification: <symbol> or (<symbol> as <symbol>) expected: %s"))

(define (parse-module-spec name-spec)
  (let* ([parsed-spec (parse-aka-spec name-spec "Improper module specification: <module> or (<module-expr> as <symbol>) expected: %s")])
    (assert (or (symbol? (car parsed-spec))
                (module? (car parsed-spec))) (format "Improper module specification: <module> or (<module-expr> as <symbol>) expected: %s" (car parsed-spec)))
    parsed-spec))

(define (prefix-map prefix)
  (lambda (sym)
    (string->symbol (format "%s%s" prefix sym))))

(define-macro (module stx)
  
  (assert (< 2 (length stx)) (string-append "Improper module definition: (module <name> forms...) expected: "
                                            (string-slice (format "%s" stx) 100)))
  (let* ([name (cadr stx)]
         [forms (cddr stx)]
         [private-module (gensym name)])
    (assert (symbol? name) (format "Illegal module name: symbol expected: %s" name))
    `(begin
       (define ,name (make-module ',name (current-module)))
       (let ([,private-module (make-module ',name (current-module) ',private-module)])
         (for-each (lambda (form)
                     (except (lambda (E)
                               (print (format "An error occurred in module %s while evaluating form %s:\n"
                                              ',name form)
                                      "red")
                               (print (format "%s\n" E) "red"))
                       (eval (compile form ,private-module))))
                   ',(append forms
                             (list `(module-import ,name (cons #f ,private-module) #f '*)
                                   `(module-export ,name '*))))))))

(define-macro (export stx)
  (assert (< 1 (length stx)) (format "Improper export: no exports listed: %s" stx))
  (let ([export-spec (if (eq? '* (cadr stx))
                         '*
                         `(quote ,(map (lambda (name-spec)
                                         (parse-export-spec name-spec))
                                       (cdr stx))))])
    `(module-export (current-module) ,export-spec)))


(define-macro (import stx)
  (let* ([params (if (= (length stx) 2)
                     `((from . ,(cadr stx)) (names))
                     (let loop ([options (cdr stx)]
                                [params '()])
                       (if (null? options)
                           (reverse params)
                           (let ([key (car options)])
                             (cond [(eq? key '*)
                                    (loop (cdr options) (cons (cons names: key) params))]

                                   [(member key '(from prefix map))
                                    (if (null? (cdr options))
                                        (assert #f (format "Improper import specification: option %s needs value: %s" key stx))
                                        (loop (cddr options) (cons (cons key (cadr options))
                                                                   params)))]

                                   [#t
                                    (assert (not (assoc names: params))
                                            (format "Improper import specification: * and individual names given: %s" stx))
                                    (reverse (cons (cons names: options) params))])))))]
         
         [src-module-spec (let ([src-spec (assoc from: params)])
                            (assert (or src-spec
                                        (not (member from: stx))) (format "Improper import specification: named imports must come after source module specifier (from: ...): %s" stx))
                            (assert src-spec (format "Improper import specification: no source module given (from: ...): %s" stx))
                            (let* ([parsed-spec (parse-module-spec (cdr src-spec))]
                                   [import-as (car parsed-spec)]
                                   [module-value (cdr parsed-spec)])
                              `(cons ',import-as  ,module-value)))]
         
         
         [name-map (let ([map-spec (assoc 'map params)]
                         [prefix-spec (assoc 'prefix params)])
                     (cond [(and map-spec prefix-spec)
                            (assert #f (format "Improper import specification: both prefix and map options given: %s" stx))]

                           [prefix-spec
                            `(prefix-map ',(cdr prefix-spec))]

                           [#t
                            (and map-spec
                                 (cdr map-spec))]))]

         [names (let ([names-spec (assoc 'names params)])
;;                  (printf "names-spec: %s\n" names-spec)
                  (assert names-spec (format "Improper import specification: nothing specified to import: %s" stx))
                  (let ([names (cdr names-spec)])
                    (if (eq? names '*)
                        names
                        (map parse-import-spec names))))])
    
    `(module-import (current-module) ,src-module-spec ,name-map ',names)))

(define (current-module)
  Moosky.Top)

(define (get-export module name)
  (let* ([exports (object-ref module "$exports")]
         [internal-name (if (eq? exports '*)
                            name
                            (object-ref exports name))]
         [module-name (object-ref module "$name")])
    
    (assert (defined? internal-name) (format "%s not found in exports of module %s."
                                             name module-name))
    
    (let ([export-value (object-ref module internal-name)])
      (assert export-value (format "Export %s not found in module %s."
                                   name module-name))
      export-value)))


(define (get-exports-list module)
  (let ([exports (object-ref module "$exports")])
    (if (eq? '* exports)
        (map (lambda (sym)
               (cons sym sym))
             (filter (lambda (sym)
                       (= -1 (string-search (symbol->string sym) #/\$/)))
                     (object-properties-list module)))
        (object->alist exports))))

(define (module-import target-module src-module-spec name-map names)
;;  (printf "names-- %s\n" names)
;;  (printf "src-module-spec-- %s\n" src-module-spec)
  (if (null? names)
      (object-set! target-module (car src-module-spec) (cdr src-module-spec))
      (let ([name-map (or name-map (lambda (x) x))]
            [src-module (cdr src-module-spec)])
        (for-each (lambda (name-spec)
;;                    (printf "name-spec: %s\n" name-spec)
                    (let ([imported-as (car name-spec)]
                          [exported-as (cdr name-spec)])
                      (object-set! target-module imported-as (get-export src-module exported-as))))
                  (if (eq? names '*)
                      (get-exports-list src-module)
                      names)))))

(define (module-export src-module export-specs)
;;  (printf "$exports: %s\nspecs: %s\n" (object-ref src-module "$exports") export-specs)
  (console.log "src-module" src-module)
  (if (eq? export-specs '*)
      (object-set! src-module "$exports" '*)
      (let ([exports (object-ref src-module "$exports")])
        (console.log "src-module.$exports" exports)
        (when (not (eq? exports '*))
          (for-each (lambda (pair)
;;                      (printf "pair: %s\n" pair)
                      (object-set! exports (car pair) (cdr pair)))
                    export-specs)))))

