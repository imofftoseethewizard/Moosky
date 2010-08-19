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

(define-macro (? stx) `({$lastInspector} (quote ,(cdr stx))))

(define-macro (let stx)
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

(define-macro (let* stx)
  (let ([bindings (cadr stx)]
        [body (cddr stx)])
    (if (null? bindings)
        `(let () ,@body)
        `(let (,(car bindings))
           (let* ,(cdr bindings) ,@body)))))

(define-macro (letrec stx)
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

(define-macro (letrec* stx)
  `(letrec ,@(cdr stx)))

(define-macro (let-values stx)
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
                       (cons temps temp-bindings)))))))

(define-macro (let*-values stx)
  (let ([bindings (cadr stx)]
        [body (cddr stx)])
    (if (null? bindings)
        `(let () ,@body)
        `(let-values (,(car bindings))
           (let*-values ,(cdr bindings) ,@body)))))

(define-macro (case stx)
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

(define-macro (cond stx)
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

(define-macro define
  (let ([DEFINE (string->symbol "$define")])
    (lambda (stx)
      (let ([target (cadr stx)]
            [value (cddr stx)])
        (if (null? value)
            `(,DEFINE ,target)
            (if (symbol? target)
                `(begin
                   (,DEFINE ,target)
                   (set! ,target ,@value))
                (let ([target (car target)]
                      [formals (cdr target)])
                  `(begin
                     (,DEFINE ,target)
                     (set! ,target (lambda ,formals ,@value))))))))))


(define (undefined? x)
  (eq? x #u))

(define (defined? x)
  (not (eq? x #u)))

(define (raise x)
  #{ (function () { throw @^(x) })() }#)

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

(define-macro (guard stx)
  (assert (<= 3 (length stx)) (format "syntax error: (guard <final-thunk> forms...): %s" stx))
  (let ([final-thunk (cadr stx)]
        [forms (cddr stx)])
    `(call-with-guard (lambda () ,@forms) ,final-thunk)))

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

(define-macro (except stx)
  (assert (<= 3 (length stx)) (format "syntax error: (except <handler> forms...): %s" stx))
  (let ([handler (cadr stx)]
        [forms (cddr stx)])
    `(call-with-exception-handler (lambda () ,@forms) ,handler)))

(define (assert b msg)
  (or b (raise (string-append "assert-failed: " msg))))

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


(define-macro (when stx)
  `(and ,(cadr stx)
        (begin ,@(cddr stx))))
