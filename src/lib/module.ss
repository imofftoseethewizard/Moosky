;; module
;;   -- separate namespace
;;   -- inheritance
;;   -- compile/eval per enclosed sexp
;;   -- export (some, all, rename)
;;   -- import (some, all, rename)

;; (module name
;;     (import [from: module]
;;                           [prefix: symbol]
;;                                         [map: fn]
;;                                                       name [(as name)]
;;                                                                     ...)

;;       (export [prefix: symbol]
;;                             name [(as name)]
;;                                           ...)
;;         ...) 
;; make-module name imports exports forms
;;   -- define new module below Moosky.Modules
;;   -- populate with import and export functions
;;   -- compile/eval each form in the context of the new module

;; current-module
;;   -- returns reference to enclosing module

;; module-import target-module src-module name-map names
;;   -- add names from module (mapped by name-map) to current module
;;   -- partial-eval form added to

;; module-export module name-map names
;;   -- add names from module (mapped by name-map) to
(define (parse-aka-spec name-spec error-fmt)
  (cond [(list? name-spec)
         (assert (and (= 3 (length name-spec))
                      (eq? 'as (cadr name-spec))) (format error-fmt name-spec))
         `(,(caddr name-spec) . ,(car name-spec))]

        [#t
         `(,name-spec . ,name-spec)]))

(define (parse-module-spec name-spec)
  (let* ([parsed-spec (parse-aka-spec name-spec "Improper module specification: <module> or (<module-expr> as <symbol>) expected: %s")])
    (assert (symbol? (car parsed-spec)) "Improper module specification: <module> or (<module-expr> as <symbol>) expected: %s")
    parsed-spec))

(define (parse-export-spec name-spec)
  (let* ([parsed-spec (parse-aka-spec name-spec "Improper exported name specification: <symbol> or (<expr> as <symbol>) expected: %s")])
    (assert (symbol? (car parsed-spec)) "Improper exported name specification: <symbol> or (<expr> as <symbol>) expected: %s")
    parsed-spec))

(define (parse-import-spec name-spec)
  (parse-aka-spec name-spec "Improper imported name specification: <symbol> or (<symbol> as <symbol>) expected: %s"))

(define (make-module name base)
  (let ([new-module (Moosky.Runtime.exports.makeFrame base)])
    (object-set! new-module "$name" name)
    (object-set! new-module "$namespace" (format "%s.%s"
                                                 (object-ref base "$namespace") name))
    (object-set! new-module "$exports" (Object))
    (object-set! new-module "currentModule" (lambda () new-module))
    new-module))

(define print Moosky.HTML.print)
(define (printf fmt . args)
  (print (apply format (cons fmt args))))

(define-macro (module stx)
  (assert (< 2 (length stx)) (string-append "Improper module definition: (module <name> forms...) expected: "
                                            (string-slice (format "%s" stx) 100)))
  (let ([name (cadr stx)]
        [forms (cddr stx)])
    (assert (symbol? name) (format "Illegal module name: symbol expected: %s" name))
    `(begin
       (define ,name (make-module ',name (current-module)))
       (for-each (lambda (form)
                   (except (lambda (E)
                             (print (format "An error occurred in module %s while evaluating form %s:\n"
                                            ',name form)
                                    "red")
                             (print E "red"))
                     (let ([code (compile form ,name)])
                       (printf "%s\n" code)
                       (Moosky.Evaluator.evaluate code))))
                 ',forms))))


(define-macro (export stx)
  (assert (< 1 (length stx)) (format "Improper export: no exports listed: %s" stx))
  (let ([export-spec (if (eq? '* (cadr stx))
                         '*
                         `(quote ,(map (lambda (name-spec)
                                         (parse-export-spec name-spec))
                                       (cdr stx))))])
    (printf "export produced code: %s" `(module-export (current-module) ,export-spec))
    `(module-export (current-module) ,export-spec)))


(define-macro (import stx)
  (let* ([params (if (= (length stx) 2)
                     `((from . ,(cadr stx)) (names . 'none))
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
                  (printf "names-spec: %s" names-spec)
                  (assert names-spec (format "Improper import specification: nothing specified to import: %s" stx))
                  (map parse-import-spec (cdr names-spec)))])
    
    `(module-import (current-module) ,src-module-spec ,name-map ',names)))

;; make support for nested modules

(define (current-module)
  Moosky.Top)

(define (prefix-map prefix)
  (lambda (sym)
    (string->symbol (format "%s%s" prefix sym))))

(define (get-export module name)
  (let* ([exports (object-ref module "$exports")]
         [internal-name (object-ref exports name)])
    (assert (defined? internal-name) (format "Export %s not found in module %s."
                                             name (object-ref module "$name")))
    (printf "get-export: module %s; internal name %s" module internal-name)
    (object-ref module internal-name)))


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
  (printf "names-- %s\n" names)
  (printf "src-module-spec-- %s\n" src-module-spec)
  (if (eq? names 'none)
      (object-set! target-module (car src-module-spec) (cdr src-module-spec))
      (let ([name-map (or name-map (lambda (x) x))]
            [src-module (cdr src-module-spec)])
        (for-each (lambda (name-spec)
                    (printf "name-spec: %s\n" name-spec)
                    (let ([imported-as (car name-spec)]
                          [exported-as (cdr name-spec)])
                      (object-set! target-module imported-as (get-export src-module exported-as))))
                  (if (eq? names '*)
                      (get-exports-list src-module)
                      names)))))

(define (module-export src-module names)
  (printf "$exports: %s\nnames: %s\n" (object-ref src-module "$exports") names)
  (console.log src-module)
  (if (eq? names '*)
      (object-set! src-module "$exports" '*)
      (let ([exports (object-ref src-module "$exports")])
        (when (not (eq? exports '*))
          (for-each (lambda (pair)
                      (printf "pair: %s\n" pair)
                      (object-set! exports (car pair) (cdr pair)))
                    names)))))

