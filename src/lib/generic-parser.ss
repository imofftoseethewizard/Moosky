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

(module parser

  (export make-parse-context make-parse-frame
          context-frame context-ref context-tag
          context-set! context-extend!
          find-context
          add-binding! get-binding
          parse)

  ;;==========================================================================
  ;;
  ;; This module provides a generic framework for implementing syntax
  ;; processors.
  ;;
  ;;

  (define (assoc-ref obj lst)
    (let ([r (assoc obj lst)])
      (and r (cdr r))))

  
  
  ;;--------------------------------------------------------------------------
  ;;
  ;; (make-parse-frame stx tag bindings)
  ;;
  ;; stx is an abstract syntax tree to be parsed.
  ;;
  ;; tag is the tag of the new frame.
  ;;
  ;; bindings are any initial bindings to be set.
  ;;
  ;; kernel is the syntax-specific kernel to the parser.
  ;;
  ;; make-parse-frame builds a simple object and returns it.
  ;;

  (define (make-parse-frame stx tag bindings kernel)
    (object stx: stx 
            tag: tag
            kernel: kernel
            bindings: (default bindings '())))


  ;;--------------------------------------------------------------------------
  ;;
  ;; (make-parse-context stx ctx tag bindings kernel)
  ;;
  ;; stx is an abstract syntax tree to be parsed.
  ;;
  ;; ctx is a parse context.
  ;;
  ;; tag is the tag of the new frame.
  ;;
  ;; bindings are any initial bindings to be set.
  ;;
  ;; kernel is the syntax-specific kernel to the parser.  Default
  ;;   is to use the kernel of ctx.
  ;;
  ;; make-parse-context makes a new parse-frame and prepends it to ctx. Its value
  ;; is the result.
  ;;
  
  (define (make-parse-context stx ctx tag bindings kernel)
    (cons (make-parse-frame stx (default bindings '())
                            '()
                            (if (null? ctx)
                                (and (assert (defined? kernel) "make-parse-context: null parent context, but no kernel given.")
                                     kernel)
                                ctx.kernel))
          ctx))


  
  (define (context-frame ctx)
    (car ctx))

  (define (context-ref ctx sym)
    (object-ref (context-frame ctx) sym))

  (define (context-tag ctx)
    (context-ref ctx tag:))

  (define (context-stx ctx)
    (context-ref ctx stx:))

  (define (context-local-bindings ctx)
    (context-ref ctx bindings:))
  
  ;;--------------------------------------------------------------------------
  ;;
  ;; (context-bindings ctx)
  ;;
  ;; ctx is the parse context from which to retrieve bindings
  ;;
  ;; context-bindings returns the binding information for all symbols bound in
  ;; the context.
  ;;
  
  (define (context-bindings ctx)
    (assert (not (null? ctx)))
    (apply append (map (lambda (ctx-frame)
                         (object-ref ctx-frame bindings:))
                       ctx)))
  
  
  (define (context-alias ctx sym)
    (let ([alias-binding (find (lambda (binding)
                                 (eq? binding.symbol sym))
                               (context-local-bindings ctx))])
      (if alias-binding
          alias-binding.alias
          (if (root-context? ctx)
              sym
              (context-alias (next-context ctx) sym)))))
           
  (define (context-extend! ctx . props)
    (apply object-extend! ctx props))

  (define (mapcdr proc . lists)
    (if (null? lists)
        '()
        (if (null? (car lists))
            ;; all lists must be empty
            (let loop ([lists (cdr lists)])
              (if (null? lists)
                  '()
                  (if (not (null? (car lists)))
                      '&exception1
                      (loop (cdr lists)))))
            ;; all lists must have at least one element
            (let loop ([lists lists]
                       [result '()])
              (if (null? (car lists))
                  (let check-loop ([lists (cdr lists)])
                    (if (null? lists)
                        (reverse result)
                        (if (not (null? (car lists)))
                            '&exception2
                            (check-loop (cdr lists)))))
                  (loop (map cdr lists)
                        (cons (apply proc lists) result)))))))

  (define (I x) x)
  
  (define (cdrs L)
    (mapcdr I L))
  
  (define (context-stack ctx)
    (cdrs ctx))

  (define (root-context? ctx)
    (null? (cdr ctx)))

  (define next-context cdr)
  
    
  ;;--------------------------------------------------------------------------
  ;;
  ;; (add-binding! ctx sym obj)
  ;;
  ;; ctx is a parse context to add the binding to.
  ;;
  ;; sym is the symbol to be bound.
  ;;
  ;; obj is an arbitrary object that holds values about the binding.
  ;;
  
  (define (add-binding! ctx sym obj)
    (assert (not (null? ctx)))
    (let ([ctx-frame (car ctx)])
      (set! ctx-frame.bindings (cons (cons sym obj) ctx-frame.bindings))))



  ;;--------------------------------------------------------------------------
  ;;
  ;; (get-binding ctx sym)
  ;;
  ;; ctx is the parse context in which to search for the binding.
  ;;
  ;; sym is the bound symbol to be searched for.
  ;;
  ;; get-binding returns the binding information for the symbol.  Symbols
  ;; not found in the current parse frame will be searched for in earlier
  ;; frames in the context.  If the symbol is not found then the result will
  ;; be #f.
  ;;
  
  (define (get-binding ctx sym)
    (assert (not (null? ctx)))
    (let ([ctx-frame (car ctx)])
      (or (assoc-ref sym ctx-frame.bindings)
          (and (not (null? (cdr ctx)))
               (get-binding (cdr ctx) sym)))))

  
  ;;--------------------------------------------------------------------------
  ;;
  ;; (make-parse-error-message stx ctx msg)
  ;;
  ;; stx is the syntax that cannot be successfully parsed.
  ;;
  ;; ctx is the context in which the attempted parsing took place.
  ;;
  ;; msg is a message describing what went wrong.
  ;;
  ;; parse-error computes a message describing the error.
  ;;
  
  (define (make-parse-error-message stx ctx msg)
    (format "syntax-error: while parsing %s\n%s" stx msg))
  


  ;;--------------------------------------------------------------------------
  ;;
  ;; (parse stx ctx)
  ;;
  ;; stx is the syntax to be parsed.
  ;;
  ;; ctx is the parse context in which the syntax is to be parsed.
  ;;
  ;; This is the appropriate place to decorate the result syntax with source
  ;; information.
  ;;
  
  (define (parse stx ctx)
    (assert (not (null? ctx)))
    
    (except (lambda (e)
              (raise (make-parse-error-message stx ctx e.message)))
      (let ([kernel (object-ref (car ctx) kernel:)])
        (kernel stx ctx))))



  (module test

    (define-macro (trial stx)
      `(assert ,@(cdr stx) (format "%s failed" ',@(cdr stx))))

    (define-macro (fail stx)
      `(assert (eq? 'exception (except (lambda (e) 'exception)
                                 ,@(cdr stx)))
               (format "%s failed" ',@(cdr stx))))

    
    ;;------------------------------------------------------------------------
    ;;
    ;; test goals:
    ;;
    ;; 1. Bindings
    ;;    add-binding! adds to the appropriate frame.
    ;;    add-binding! appropriately shadows earlier values, both
    ;;     in the current frame an in earlier frames.
    ;;    get-bindings shows appropriately models lexical scoping.
    ;;
    ;; 2. Errors
    ;;    check that error predicates (error-parser?, error-frame?) work.
    ;;    check that make-error-parser and error-parser? work together
    ;;    check that make-error-frame and error-frame? work together
    ;;    check that make-parse-error-message makes correct messages
    ;;
    ;; 3. Parser
    ;;    check that parser is called and the returned value is used correctly
    ;;    check that errors are raised with appropriate messages when parser fails
    ;;    check that the appropriate parser is called given the parser return
    ;;    check that error results are raised with appropriate messages
    ;;    check that results are delivered
    ;;

    (define (plus-parser stx ctx)
      (assert (= 3 (length stx)) (format "plus expects 2 parameters: %s" stx))
      `(,@(parse (cadr stx) ctx) + ,@(parse (caddr stx) ctx)))

    (define (plus-expression? stx)
      (and (list? stx)
           (eq? (car stx) '+)))
    
    (define (times-parser stx ctx)
      (assert (= 3 (length stx)) (format "times expects 2 parameters: %s" stx))
      (let* ([left (cadr stx)]
             [right (caddr stx)]
             [parsed-left (parse left ctx)]
             [parsed-right (parse right ctx)])
        `(,@(if (plus-expression? left)
                `("(" ,@parsed-left ")")
                parsed-left)
          *
          ,@(if (plus-expression? left)
                `("(" ,@parsed-right ")")
                parsed-right))))


    (define (value-parser stx ctx)
      (assert (number? stx) (format "only numbers are allowed as values: %s" stx))
      stx)

    (define (test-kernel stx ctx)
      (let ([parser (if (list? stx)
                        (case (car stx)
                          [(+) plus-parser]
                          [(*) times-parser]
                          [else (make-error-parser (format "%s: unrecognized operator" (car stx)))])
                        value-parser)])
        (parser stx ctx)))


    (define stx '(* (+ 1 2) (+ 3 4)))
    
    (define base-ctx (make-parse-context stx '() 'base '() test-kernel))
    (define test-ctx (make-parse-context stx base-ctx))


    ;; Bindings

    (add-binding! base-ctx 'foo "foo base binding")
    (add-binding! test-ctx 'foo "foo test binding")
    
    (trial (string=? "foo base binding" (get-binding base-ctx 'foo)))
    (trial (string=? "foo test binding" (get-binding test-ctx 'foo)))
    

    ;; Errors

    (trial (error-result? (make-error-result "foo")))
    (trial (error-result? ((make-error-parser "foo") stx test-ctx)))
    

    ;; Parser

    (trial (eq? 1 (value-parser 1 base-ctx)))
    (trial (eq? 1 (parse 1 base-ctx)))
    
    (fail (value-parser '() base-ctx))

    (trial (equal? '(1 + 2) (plus-parser '(+ 1 2) base-ctx)))
    (trial (equal? '(4 * 4) (times-parser '(* 4 4) base-ctx)))
    
    (trial (equal? '("(" 1 + 2 ")" * "(" 3 + 4 ")") (parse stx base-ctx)))
    
    (fail (plus-parser '(+ 1 2 3 4) base-ctx))

    "End Module test")


  "End Module parser")
