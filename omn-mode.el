;;; omn-mode.el --- Support for OWL Manchester Notation

;; Copyright (C) 2013  Free Software Foundation, Inc.

;; Author: Phillip Lord <phillip.lord@newcastle.ac.uk>
;; Maintainer: Phillip Lord <phillip.lord@newcastle.ac.uk>
;; Website: https://www.russet.org.uk/blog
;; Version: 1.2

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; Defines a major mode for editing the Manchester OWL syntax.
;; Basically, this is just a bit of font locking.

;;; Code:

;; (defgroup omn-mode nil
;;   "Major mode to edit OWL Manchester Notation."
;;   :group 'languages)

(defvar omn-obsolete-electric-indent nil
  "Set to t to use the old electric indent.  Better use `electric-indent-mode'.")

(defvar omn-imenu-generic-expression
  '(
    ("Class"  "Class: \\([a-zA-Z:_]+\\)" 1)
    ("ObjectProperty" "ObjectProperty: \\([a-zA-Z:_]+\\)" 1)
    ("Individual" "Individual: \\([a-zA-Z:_]+\\)" 1)
    )

  "Imenu support for OMN.
See `imenu-generic-expression' for details")


(defvar omn-mode-entity-keywords
  '(
    "Ontology:"
    "Namespace:"
    "Class:"
    "Individual:"
    "ObjectProperty:"
    "DataProperty:"
    "Import:"
    "Datatype:"
    "AnnotationProperty:"
    "DisjointClasses:"
    "Prefix:"
    "owl:Thing"))

(defvar omn-mode-property-keywords
  '(
    "EquivalentTo:"
    "SubClassOf:"
    "Annotations:"
    "Characteristics:"
    "DisjointUnion:"
    "DisjointWith:"
    "Domain:"
    "Range:"
    "InverseOf:"
    "SubPropertyOf:"
    "SameAs:"
    "DifferentFrom:"
    "SubPropertyChain:"
    "Types:"
    "Facts:"
    "HasKey:"
    ))


;; indentation engine
(defun omn-indent-line()
  (indent-line-to
   (omn-determine-line-indent)))

(defun omn-determine-line-indent()
  (save-excursion
    (beginning-of-line)
    ;; check the first word

    (let* ((match (re-search-forward "\\w+" (line-end-position) t))
           (word (if match
                     (match-string 0)
                   "")))

      (cond
       ;; ((not match)
       ;;  (progn
       ;;    (if (not (forward-line -1))
       ;;        (omn-determine-line-indent)
       ;;      0)))

       ;; if it is string, ident should be 0.
       ((nth 3 (syntax-ppss (point)))
        0)

       ;; if it is a comment
       ((nth 4 (syntax-ppss (point)))
        ;; if there is a next line, indent the same as that
        (cond
         ((eq 0 (forward-line 1))
          (omn-determine-line-indent))
         ;; if there isn't return the same as the line before
         ((eq 0 (forward-line -1))
          (omn-determine-line-indent))
         ;; who knows?
         (t 0)))

       ;; if it is one of Class:, Prefix: or so on, then indent should be 0
       ((member word omn-mode-entity-keywords)
        0)
       ;; if it is Annotations:, SubClassOf: or so on, then indent should be 4
       ((member word omn-mode-property-keywords)
        4)

       ;; if it is something else, then 8
       (t 8)))))


;;;###autoload
(add-to-list 'auto-mode-alist '("\\.pomn\\'" . omn-mode))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.omn\\'" . omn-mode))

(defvar omn-font-lock-defaults
  `(,(concat "\\_<"
             (regexp-opt omn-mode-entity-keywords t)
             "\\_>")
    (,(mapconcat
       (lambda(x) x)
       '("\\<some\\>"
         "\\<only\\>"
         "\\<and\\>"
         "\\<or\\>"
         "\\<not\\>"
         "\\<exactly\\>"
         "\\<max\\>"
         "\\<min\\>"
         "\\<inverse\\>"
         "\\<value\\>"
         "Transitive"
         "Functional"
         "InverseFunctional"
         "Reflexive"
         "Symmetric"
         "Asymmetric"
         "Irreflexive"
         )
       "\\|")
     . font-lock-type-face)
    (,(regexp-opt omn-mode-property-keywords)
     . font-lock-builtin-face)
    ("\\w+:\\w+" . font-lock-function-name-face)
    ("@\\w+" . font-lock-constant-face)))


(defvar omn-mode-syntax-table
  (let ((st (make-syntax-table)))
    ;; string quotes
    (modify-syntax-entry ?\" "\"" st)
    ;; define comment characters for syntax
    (modify-syntax-entry ?\# "<" st)
    (modify-syntax-entry ?\n ">" st)
    ;; For name space prefixes, including the "_" which is used by genids.
    (modify-syntax-entry ?\_ "w" st)
    (modify-syntax-entry ?\: "w" st)
    st))

(defvar omn-mode-map
  (let ((map (make-sparse-keymap)))
    (when omn-obsolete-electric-indent
      (dolist (x `(" " "," ":"))
        (define-key map x 'omn-mode-electric-indent))
      ;; need to bind to return as well
      (define-key map (kbd "RET") 'omn-mode-electric-newline))
    map))

(defun omn-mode-electric-indent()
  (interactive)
  (self-insert-command 1)
  (omn-mode-indent-here))

(defun omn-mode-indent-here()
  (let ((m (point-marker)))
    (omn-indent-line)
    (goto-char (marker-position m))))

(defun omn-mode-electric-newline()
  (interactive)
  (newline)
  (save-excursion
    (forward-line -1)
    (omn-indent-line)))

;;;###autoload
(define-derived-mode omn-mode fundamental-mode "Omn"
  "Major mode for editing OWL Manchester Notation.

This is a format for specifying OWL ontologies, that is designed
to be easy to type and to read. It is fully documented and
specified at https://www.w3.org/TR/owl2-manchester-syntax/"

  ;; Specialised syntax handling to recognise URLs. This is a bit underhand,
  ;; but we define the < and > characters to be "generic-string" delimiters.
  ;; This results in fontification for URLs which is no bad thing.
  ;; Additionally, it makes the comment character work, as "#" is a valid in a
  ;; URL. There is a slight irony that in a format for a web-centric document,
  ;; we should treat URLs as having no semantics!
  (setq-local syntax-propertize-function
              (syntax-propertize-rules
               ("\\(<\\)[^ ]*\\(>\\)" (1 "|") (2 "|"))))

  ;; font-lock stuff
  (setq font-lock-defaults
        '(omn-font-lock-defaults))

  (set (make-local-variable 'comment-start) "#")
  (set (make-local-variable 'comment-end) "")
  ;; no idea what this is about -- stolen from generic
  (set (make-local-variable 'comment-start-skip) "#+\\s-*")

  (set (make-local-variable 'imenu-generic-expression)
       omn-imenu-generic-expression)

  (set (make-local-variable 'electric-indent-chars)
       (append `(?\  ?\, ?\:)
               (if (boundp 'electric-indent-chars)
                   (default-value 'electric-indent-chars)
                 '(?\n))))
  (set (make-local-variable 'indent-line-function) 'omn-indent-line))

(provide 'omn-mode)
;;; omn-mode.el ends here
