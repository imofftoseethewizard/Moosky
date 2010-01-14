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
                                  (let ([result (cons* `(define-element-property-getter ,(cadr property))
                                                       `(define-element-property-setter ,(cadr property))
                                                       defs)])
                                    result)
                                  (begin
                                    ;; should throw an exception
                                    (console.log "Unrecognized property descriptor:")
                                    (console.log property)
                                    (console.log "Ignoring.")
                                    defs))
                              (cons `(define-element-property-getter ,property)
                                    defs))))))))

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

(define-macro (define-element-methods form)
  `(begin ,@(let loop ([descriptors (cdr form)]
                       [defs '(#u)])
              (if (null? descriptors)
                  (reverse defs)
                  (loop (cdr descriptors)
                        (cons `(define-element-method ,(car descriptors))
                              defs))))))


;; DOM Node

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


;;; HTML Document Object

;; Document Object Collections

(define-element-property-accessors
  anchors
  forms
  images
  links)

(define-element-property-accessors
  body
  domain
  lastModified
  referrer
  title
  URL
  (mutable cookie))

(define-element-methods
  (close doc)
  (getElementById doc id)
  (getElementsByName doc name)
  (getElementsByTagName doc tagName)
  (open doc mimeType replace)
  (write doc . expressions)
  (writeln doc . expressions))



;;; Common HTML Object Properties and Methods

(define-element-property-accessors
  contentDocument
  (mutable accessKey)
  (mutable alt)
  (mutable align)
  (mutable coords)
  (mutable className)
  (mutable dir)
  (mutable frameBorder)
  (mutable height)
  (mutable href)
  (mutable id)
  (mutable lang)
  (mutable longDesc)
  (mutable marginHeight)
  (mutable marginWidth)
  (mutable scrolling)
  (mutable shape)
  (mutable src)
  (mutable tabIndex)
  (mutable target)
  (mutable title)
  (mutable type)
  (mutable width))



;;; HTML Anchor Object

(define-element-property-accessors
  (mutable charset)
  (mutable hreflang)
  (mutable innerHTML)
  (mutable name)
  (mutable rel)
  (mutable rev))

(define-element-methods
  (blur elem)
  (focus elem))



;;; HTML Area Object

(define-element-property-accessors
  (mutable hash)
  (mutable host)
  (mutable noHref)
  (mutable pathname)
  (mutable protocol)
  (mutable search))



;;; HTML Base Object

;;; HTML Body Object



;;; HTML Button Object

(define-element-property-accessors
  (mutable disabled)
  form
  (mutable value))



;;; HTML Event Object

(define-element-property-accessors
  altKey
  button
  clientX
  clientY
  ctrlKey
  metaKey
  relatedTarget
  screenX
  screenY
  shiftKey

  bubbles
  cancelable
  currentTarget
  eventPhase
  timeStamp
  
  (mutable onabort)
  (mutable onblur)
  (mutable onchange)
  (mutable onclick)
  (mutable ondblclick)
  (mutable onerror)
  (mutable onfocus)
  (mutable onkeydown)
  (mutable onkeypress)
  (mutable onkeyup)
  (mutable onload)
  (mutable onmousedown)
  (mutable onmousemove)
  (mutable onmouseout)
  (mutable onmouseover)
  (mutable onmouseup)
  (mutable onreset)
  (mutable onresize)
  (mutable onselect)
  (mutable onsubmit)
  (mutable onunload))



;;; HTML Form Object

(define-element-property-accessors
  elements)

(define-element-property-accessors
  (mutable acceptCharset)
  (mutable action)
  (mutable enctype)
  length
  (mutable method))

(define-element-methods
  (reset form)
  (submit form))


;;; HTML Frame Object

(define-element-property-accessors
  (mutable noResize))


;;; HTML Frameset Object

(define-element-property-accessors
  (mutable cols)
  (mutable rows))


;;; HTML IFrame Object


;;; HTML Frame Object

(define-element-property-accessors
  complete
  isMap
  (mutable border)
  (mutable hspace)
  (mutable lowsrc)
  (mutable useMap)
  (mutable vspace))


;; Here's a little usage example.
;;   #n means null.
(define (lastSibling elem)
  (let ([next (nextSibling elem)])
    (if (eq? #n next)
        elem
        (lastSibling next))))

(define window { window })
(define document { document })

