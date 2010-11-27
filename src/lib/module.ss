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



;;============================================================================
;;
;; print
;;
;; a very useful auxiliary that should live elsewhere.
;;

(define print Moosky.HTML.print)
(define (printf fmt . args)
  (print (apply format (cons fmt args))))



;;============================================================================
;;
;; (make-module name base namespace)
;;
;; name gives the name of the new module.  It can be a symbol or a string.
;; (In fact, it can be anything and it need not be distinct from the names
;; of other defined modules.)  This is primarily used when creating diagnostic
;; messages.
;;
;; base is a module from which the new one will inherit.  Specifically, base
;; is set as the prototype of a null constructor.  A call to that constructor
;; creates the new module, which thanks to javascript's prototype facility,
;; provides access to all of the properties of base as if they were properties
;; of the new module.
;; creates the basic structure of the module.  makeFrame uses javascript's
;; prototype implementation to provide access to the base module in the derived
;; module.
;;
;; A module is a an object which has a few specific properties.
;;
;; $name: the name of the module.
;; $namespace: (to be obsoleted)
;; $exports
;; prototype facility of javascript).  
;;

(define (make-module name base namespace)
  (let ([new-module (Moosky.Runtime.exports.makeFrame base)])
    (object-set! new-module "$name" name)
    (object-set! new-module "$namespace" (default namespace
                                           (let ([base-namespace (object-ref base "$namespace")])
                                             (if (defined? base-namespace)
                                                 (format "%s.%s" base-namespace name)
                                                 name))))
    (object-set! new-module "$exports" (Object))
    (object-set! new-module "current-module" (lambda () new-module))
    new-module))

(define (module? x)
  { typeof(x) == 'object' && x.$namespace !== undefined })

(define (module-name M)
  (object-ref M "$name"))

(define (module-namespace M)
  (object-ref M "$namespace"))

(define (module-exports M)
  (object-ref M "$exports"))


;;============================================================================
;;
;; (module-export src-module export-specs)
;;
;; src-module is a module.
;;
;; export-specs is a list of pairs or the symbol *.  If it is a list, then the
;; car of each pair is the symbol representing the external name of the item;
;; the cdr is a symbol representing the internal name of the item.
;;

(define (module-export src-module export-specs)
  (if (eq? export-specs '*)
      (object-set! src-module "$exports" '*)
      (let ([exports (object-ref src-module "$exports")])
        (when (not (eq? exports '*))
          (for-each (lambda (pair)
                      (object-set! exports (car pair) (cdr pair)))
                    export-specs)))))



;;============================================================================
;;
;; (get-export module name)
;;
;; module is the module to look in.
;;
;; name is the name to look for.  It can be a string or a symbol.
;;

(define (get-export M name)
  (let* ([exports (module-exports M)]
         [internal-name (if (eq? exports '*)
                            name
                            (object-ref exports name))]
         [module-name (module-name M)])

    (assert (defined? internal-name) (format "%s not found in exports of module %s."
                                             name module-name))
    
    (let ([export-value (object-ref M internal-name)])
      (assert (defined? export-value) (format "Export %s not found in module %s."
                                              name module-name))
      export-value)))


(define (get-exports-list module)
  (let ([exports (object-ref module "$exports")])
    (if (eq? '* exports)
        (filter (lambda (sym)
                  (and (= -1 (string-search (symbol->string sym) #/\$/))
                       (not (eq? sym 'current-module))))
                (object-properties-list module))
        (map car (object->alist exports)))))



;;============================================================================
;;
;; (module-import target-module src-module-spec name-map names)
;;
;; target-module is the module that will receive the imports.
;;
;; src-module-spec is a pair.  The first is the name of the imported module;
;; the second is the imported module itself.
;;
;; name-map is a function that takes a symbol and returns a symbol or a string.
;; The returned value will be the name which the import takes in target module.
;; Provide #f to use the exported names as is.
;;
;; names is either a single symbol, '*, indicating that all exports of the
;; source module should be imported into the target, or it is a list of pairs,
;; each of which specifies the names of the exported item in the target
;; and source modules, respectively.  That is, the first element of each pair
;; is a symbol which gives the name the object will have in the target module;
;; the second symbol in the pair gives the name under which the object is
;; exported from the source module.  If names is null, then only the source
;; module itself will be imported under the name given in src-module-spec.
;;

(define (module-import target-module src-module-spec name-map import-specs)
  (if (null? import-specs)
      (object-set! target-module (car src-module-spec) (cdr src-module-spec))
      
      (let ([name-map (or name-map (lambda (x) x))]
            [src-module (cdr src-module-spec)])
        (for-each (lambda (import-spec)
                    (let ([imported-as (car import-spec)]
                          [exported-as (cdr import-spec)])
                      (object-set! target-module imported-as (get-export src-module exported-as))))
                  (if (eq? import-specs '*)
                      (map (lambda (sym)
                             (cons sym sym))
                           (get-exports-list src-module))
                      import-specs)))))



;;============================================================================
;;
;; parse-aka-spec
;; parse-export-spec
;; parse-import-spec
;; parse-module-spec
;;
;; syntax processing helpers that transform a symbol A, or a list of the form
;; (A as B) into, (A . A) and (B . A), respectively.
;;

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
  (let* ([parsed-spec (parse-aka-spec name-spec "Improper imported name specification: <symbol> or (<symbol> as <symbol>) expected: %s")])
    (assert (and (symbol? (car parsed-spec))
                 (symbol? (cdr parsed-spec)))
            "Improper exported name specification: <symbol> or (<expr> as <symbol>) expected: %s")
    parsed-spec))

(define (parse-module-spec name-spec)
  (let* ([parsed-spec (parse-aka-spec name-spec "Improper module specification: <module> or (<module-expr> as <symbol>) expected: %s")])
    (assert (symbol? (car parsed-spec)) (format "Improper module specification: <module> or (<module-expr> as <symbol>) expected: %s" (car parsed-spec)))
    parsed-spec))


;;============================================================================
;;
;; prefix-map
;;
;; Used to make a name-map when the prefix: option is given to import or export.
;;
;;

(define (prefix-map prefix)
  (lambda (sym)
    (string->symbol (format "%s%s" prefix sym))))



;;============================================================================
;;
;; module
;;
;; Makes two modules, a private one in which all of the module's forms are
;; evaluated; and a public one in which its exports are present.
;;
;; there is a serious bug in this implementation: if a macro is defined that
;; uses a function defined in the same module, then the function will not
;; be found.  The entirety of the module undergoes syntax expansion before
;; any of it is evaluated.
;;

(define-macro (module stx)
  
  (assert (< 2 (length stx)) (string-append "Improper module definition: (module <name> forms...) expected: "
                                            (string-slice (format "%s" stx) 100)))
  (let* ([external-name (cadr stx)]
         [internal-name (gensym external-name)]
         [forms (cddr stx)]
         [private-module (gensym "private")])
    (assert (symbol? external-name) (format "Illegal module name: symbol expected: %s" external-name))
    `(begin
       (define ,external-name (make-module ',external-name (object)))
       (printf "Compiling module %s\n" ',external-name)
       (let ([,private-module (make-module ',external-name (current-module) ',private-module)])
         (for-each (lambda (form)
                     (except (lambda (E)
                               (print (format "An error occurred in module %s while evaluating form %s:\n"
                                              ',external-name form)
                                      "red")
                               (print (format "%s\n" E) "red"))
                       
                       (when (equal? ',external-name 'foo)
                         (printf "%s\n" form)
                         (printf "%s\n" (compile form ,private-module)))
                       
                       (eval (compile form ,private-module))))
                   ',(append (list `(define ,internal-name ,external-name))
                             forms
                             (list `(module-import ,internal-name (cons #f ,private-module) #f '*)
                                   `(module-export ,internal-name (map (lambda (sym)
                                                                         (cons sym sym))
                                                                       (get-exports-list ,private-module))))))))))

(define-macro (export stx)
  (assert (< 1 (length stx)) (format "Improper export: no exports listed: %s" stx))
  (let ([export-spec (if (eq? '* (cadr stx))
                         '*
                         `,(map (lambda (name-spec)
                                         (parse-export-spec name-spec))
                                (cdr stx)))])
    `(module-export (current-module) ',export-spec)))


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

;;============================================================================
;;
;; tests
;;
;;


(define-macro (trial stx)
  `(begin
     (assert ,@(cdr stx) (format "%s failed" ',@(cdr stx)))
     #t))

(define-macro (fail stx)
  `(assert (eq? 'exception (except (lambda (e) 'exception)
                             ,@(cdr stx)))
           (format "%s failed" ',@(cdr stx))))

(let ([M (make-module 'foo (object bar: "test") "FOO")])
  (trial (not (module? #f)))
  (trial (not (module? 'foo)))
  (trial (not (module? "foo")))
  (trial (not (module? '(a b))))
  (trial (not (module? (lambda (x) x))))
  (trial (not (module? (object))))
  (trial (not (module? 12)))
  (trial (module? M))
  (trial (eq? (module-name M) 'foo))
  (trial (eq? (module-namespace M) "FOO"))
  (trial (object? (module-exports M)))
  (trial (null? (object->alist (module-exports M))))
  (trial (defined? M.current-module))
  (trial (function? M.current-module))
  (trial (eq? (M.current-module) M))
  (trial (eq? M.bar "test")))

(let ([M1 (make-module 'foo (object bar: "test"))])
  (trial (module? M1))
  (trial (eq? (module-name M1) 'foo))
  (trial (eq? (module-namespace M1) 'foo))
  (trial (object? (module-exports M1)))
  (trial (null? (object->alist (module-exports M1))))
  (trial (defined? M1.current-module))
  (trial (function? M1.current-module))
  (trial (eq? (M1.current-module) M1))
  (trial (eq? M1.bar "test"))
  
  (let ([M2 (make-module 'bar M1 "BAR")])
    (trial (module? M2))
    (trial (eq? (module-name M2) 'bar))
    (trial (eq? (module-namespace M2) "BAR"))
    (trial (object? (module-exports M2)))
    (trial (null? (object->alist (module-exports M2))))
    (trial (defined? M2.current-module))
    (trial (function? M2.current-module))
    (trial (eq? (M2.current-module) M2))
    (trial (eq? M2.bar "test"))
    (set! M2.bar "changed")
    (trial (eq? M1.bar "test"))
    (trial (eq? M2.bar "changed")))
  
  (let ([M2 (make-module 'bar M1)])
    (trial (module? M2))
    (trial (eq? (module-name M2) 'bar))
    (trial (eq? (module-namespace M2) "foo.bar"))
    (trial (object? (module-exports M2)))
    (trial (null? (object->alist (module-exports M2))))
    (trial (defined? M2.current-module))
    (trial (function? M2.current-module))
    (trial (eq? (M2.current-module) M2))
    (trial (eq? M2.bar "test"))
    (set! M2.bar "changed")
    (trial (eq? M1.bar "test"))
    (trial (eq? M2.bar "changed"))))
  
(trial (equal? '(foo . foo) (parse-aka-spec 'foo "%s")))
(trial (equal? '(bar . foo) (parse-aka-spec '(foo as bar) "%s")))
(fail (parse-aka-spec '() "%s"))
(fail (parse-aka-spec '(foo) "%s"))
(fail (parse-aka-spec '(foo bar) "%s"))
(fail (parse-aka-spec '(foo is bar) "%s"))
(fail (parse-aka-spec '(foo = bar) "%s"))
(fail (parse-aka-spec '(foo as) "%s"))
(fail (parse-aka-spec '(foo as bar mitzvah) "%s"))

(fail (parse-export-spec "foo"))
(fail (parse-export-spec (foo as "bar")))
(trial (equal? '(bar . "foo") (parse-export-spec '("foo" as bar))))
(trial (equal? '(bar . bar) (parse-export-spec 'bar)))

(fail (parse-module-spec "foo"))
(fail (parse-module-spec (foo as "bar")))
(fail (parse-module-spec ("foo" as bar)))

(let ([M (make-module 'foo-mod (object) "")])
  (trial (equal? `(foo-mod . ,M) (parse-module-spec `(,M as foo-mod)))))

(let ([M (make-module 'foo (object))])
  (set! M.bar 'quux)
  (module-export M '((baz . bar)))
  (trial (eq? (object-ref (module-exports M) 'baz)
              'bar))

  (trial (eq? (get-export M 'baz) M.bar))
  (trial (equal? '(baz) (get-exports-list M)))
  
  (let ([N (make-module 'foo-user (object))])
    (module-import N `(foo . ,M) #f '((baz . baz)))
    (trial (eq? N.baz M.bar)))
  
  (let ([N (make-module 'foo-user (object))])
    (module-import N `(foo . ,M) #f '*)
    (trial (eq? N.baz M.bar)))

  (let ([N (make-module 'foo-user (object))])
    (module-import N `(foo . ,M) #f '((gloop . baz)))
    (trial (eq? N.gloop M.bar)))

  (let ([N (make-module 'foo-user (object))])
    (module-import N `(foo . ,M) #f '())
    (trial (eq? N.foo M))))


