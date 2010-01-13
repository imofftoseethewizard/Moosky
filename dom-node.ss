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

(define-macro (define-element-property-getter form)
  (let ([property-name (cadr form)])
    `(define ,property-name
       (let ([property-name-string ,(symbol->string property-name)])
         (lambda (elem)
           { @^(elem)[@^(property-name-string)] } )))))

(define-macro (define-element-property-setter form)
  (let* ([property-name (cadr form)]
         [setter-name (string->symbol (string-append "set-"
                                                      (symbol->string property-name)
                                                      "!"))])
    `(define ,setter-name
       (let ([property-name-string ,(symbol->string property-name)])
         (lambda (elem v)
           { @^(elem)[@^(property-name-string)] = @^(v) }
           #u)))))

(define-macro (define-element-property-accessors form)
  `(begin ,@(let loop ([names (cdr form)]
                       [defs '(#u)])
              (if (null? names)
                  (reverse defs)
                  (loop (cdr names)
                        (let ([property (car names)])
                          (if (pair? property)
                              (if (eq? 'mutable (car property))
                                  (cons* `(define-element-property-getter ,(cadr property))
                                         `(define-element-property-setter ,(cadr property))
                                         defs)
                                  (begin
                                    ;; should throw an exception
                                    (console.log "Unrecognized property descriptor:")
                                    (console.log property)
                                    (console.log "Ignoring.")
                                    defs))
                              (cons `(define-element-property-getter ,property)
                                    defs))))))))

(define-element-property-accessors
  baseURI
  childNodes
  firstChild
  lastChild
  localName
  namespaceURI
  nextSibling
  nodeName
  nodeType
  ownerDocument
  parentNode
  previousSibling
  text
  xml
  (mutable nodeValue)
  (mutable prefix)
  (mutable textContent))

(define-macro (define-element-method form)
  (let* ([descriptor (cadr form)]
         [method-name (car descriptor)]
         [formals (cdr descriptor)]
         [object-argument (car formals)]
         [method-arguments (cdr formals)])
    `(define ,method-name
       (let ([method-name-string ,(symbol->string method-name)])
         (lambda (elem . arguments)
           { @^(elem)[@^(method-name-string)].apply(@^(elem), @(list->vector arguments)) } )))))

(define-element-methods
  (appendChild elem child)
  (cloneNode elem)
  (compareDocumentPosition elem other)
  (hasAttributes elem)
  (hasChildNodes elem)
  (insertBefore elem other)
  (isEqualNode elem other)
  (isSameNode elem other)
  (lookupNamespaceURI elem prefix)
  (lookupPrefix elem URI)
  (normalize elem)
  (removeChild elem child)
  (replaceChild elem new old))


;; Here's a little usage example.
;;   #n means null.
(define (lastSibling elem)
  (let ([next (nextSibling elem)])
    (if (eq? #n next)
        elem
        (lastSibling next))))

(define window { window })
(define document { document })