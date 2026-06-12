;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; transaction-with-dc-totals.scm
;;
;; Custom Transaction Report for GnuCash 5.x
;; Shows separate Debit and Credit column totals at the bottom.
;;
;; Compatible with GnuCash 5.0 and later (tested on 5.15).
;; Uses the GnuCash 5.x C++ options API (gnc-optiondb-*).
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(use-modules (gnucash engine))
(use-modules (gnucash utilities))
(use-modules (gnucash core-utils))
(use-modules (gnucash app-utils))
(use-modules (gnucash report))
(use-modules (srfi srfi-1))

;;------------------------------------------------------------------
;; Report identity
;;------------------------------------------------------------------

(define reportname (N_ "Transaction Report (D/C Totals)"))
(define report-guid "3f7a2c91-dc04-4e8b-b3a1-9f06e5d812c4")

;;------------------------------------------------------------------
;; Option section / name constants
;;------------------------------------------------------------------

(define gnc:pagename-general "General")
(define gnc:pagename-accounts "Accounts")
(define gnc:pagename-display "Display")

(define optname-start-date     (N_ "Start Date"))
(define optname-end-date       (N_ "End Date"))
(define optname-accounts       (N_ "Accounts"))
(define optname-amount         (N_ "Amount"))
(define optname-date           (N_ "Date"))
(define optname-num            (N_ "Num"))
(define optname-description    (N_ "Description"))
(define optname-memo           (N_ "Memo"))
(define optname-account-name   (N_ "Account Name"))
(define optname-other-account  (N_ "Other Account Name"))
(define optname-balance        (N_ "Running Balance"))
(define optname-show-totals    (N_ "Show Debit/Credit Totals"))

;;------------------------------------------------------------------
;; Helper: read option value from a GnuCash 5.x optiondb
;;------------------------------------------------------------------

(define (opt-val options section name)
  (gnc-option-value options section name))

;;------------------------------------------------------------------
;; Column vector indices
;;------------------------------------------------------------------

(define col:date          0)
(define col:num           1)
(define col:description   2)
(define col:memo          3)
(define col:account       4)
(define col:other-account 5)
(define col:amount-single 6)
(define col:debit         7)
(define col:credit        8)
(define col:balance       9)
(define col-count         10)

(define (build-column-used options)
  (let ((cv (make-vector col-count #f)))
    (when (opt-val options gnc:pagename-display optname-date)
      (vector-set! cv col:date #t))
    (when (opt-val options gnc:pagename-display optname-num)
      (vector-set! cv col:num #t))
    (when (opt-val options gnc:pagename-display optname-description)
      (vector-set! cv col:description #t))
    (when (opt-val options gnc:pagename-display optname-memo)
      (vector-set! cv col:memo #t))
    (when (opt-val options gnc:pagename-display optname-account-name)
      (vector-set! cv col:account #t))
    (when (opt-val options gnc:pagename-display optname-other-account)
      (vector-set! cv col:other-account #t))
    (let ((amt (opt-val options gnc:pagename-display optname-amount)))
      (cond
        ((equal? amt "Single")
         (vector-set! cv col:amount-single #t))
        ((equal? amt "Double")
         (vector-set! cv col:debit  #t)
         (vector-set! cv col:credit #t))))
    (when (opt-val options gnc:pagename-display optname-balance)
      (vector-set! cv col:balance #t))
    cv))

(define (num-cols cv)
  (let loop ((i 0) (n 0))
    (if (>= i col-count) n
        (loop (+ i 1) (if (vector-ref cv i) (+ n 1) n)))))

;;------------------------------------------------------------------
;; Build the table header list
;;------------------------------------------------------------------

(define (make-heading-list cv)
  (append
    (if (vector-ref cv col:date)          (list (G_ "Date"))        '())
    (if (vector-ref cv col:num)           (list (G_ "Num"))         '())
    (if (vector-ref cv col:description)   (list (G_ "Description")) '())
    (if (vector-ref cv col:memo)          (list (G_ "Memo"))        '())
    (if (vector-ref cv col:account)       (list (G_ "Account"))     '())
    (if (vector-ref cv col:other-account) (list (G_ "Transfer"))    '())
    (if (vector-ref cv col:amount-single) (list (G_ "Amount"))      '())
    (if (vector-ref cv col:debit)         (list (G_ "Debit"))       '())
    (if (vector-ref cv col:credit)        (list (G_ "Credit"))      '())
    (if (vector-ref cv col:balance)       (list (G_ "Balance"))     '())))

;;------------------------------------------------------------------
;; Render one split as a table row; return the gnc-monetary value
;;------------------------------------------------------------------

(define (add-split-row! table split cv row-style)
  (let* ((parent   (xaccSplitGetParent split))
         (account  (xaccSplitGetAccount split))
         (currency (if (null? account)
                       (gnc-default-currency)
                       (xaccAccountGetCommodity account)))
         (damount  (if (gnc:split-voided? split)
                       (xaccSplitVoidFormerAmount split)
                       (xaccSplitGetAmount split)))
         (split-value (gnc:make-gnc-monetary currency damount))
         (row '()))

    (when (vector-ref cv col:date)
      (set! row (append row
        (list (gnc:make-html-table-cell/markup
               "text-cell"
               (qof-print-date (xaccTransGetDate parent)))))))

    (when (vector-ref cv col:num)
      (set! row (append row
        (list (gnc:make-html-table-cell/markup
               "text-cell"
               (xaccTransGetNum parent))))))

    (when (vector-ref cv col:description)
      (set! row (append row
        (list (gnc:make-html-table-cell/markup
               "text-cell"
               (xaccTransGetDescription parent))))))

    (when (vector-ref cv col:memo)
      (set! row (append row
        (list (gnc:make-html-table-cell/markup
               "text-cell"
               (xaccSplitGetMemo split))))))

    (when (vector-ref cv col:account)
      (set! row (append row
        (list (gnc:make-html-table-cell/markup
               "text-cell"
               (if (null? account) ""
                   (xaccAccountGetName account)))))))

    (when (vector-ref cv col:other-account)
      (let* ((other (xaccSplitGetOtherSplit split))
             (oacc  (if (null? other) '() (xaccSplitGetAccount other))))
        (set! row (append row
          (list (gnc:make-html-table-cell/markup
                 "text-cell"
                 (if (null? oacc) "" (xaccAccountGetName oacc))))))))

    ;; Single amount column
    (when (vector-ref cv col:amount-single)
      (set! row (append row
        (list (gnc:make-html-table-cell/markup
               "number-cell" split-value)))))

    ;; Debit: positive amounts
    (when (vector-ref cv col:debit)
      (set! row (append row
        (if (gnc-numeric-positive-p (gnc:gnc-monetary-amount split-value))
            (list (gnc:make-html-table-cell/markup "number-cell" split-value))
            (list (gnc:make-html-table-cell " "))))))

    ;; Credit: negative amounts shown as positive
    (when (vector-ref cv col:credit)
      (set! row (append row
        (if (gnc-numeric-negative-p (gnc:gnc-monetary-amount split-value))
            (list (gnc:make-html-table-cell/markup
                   "number-cell"
                   (gnc:monetary-neg split-value)))
            (list (gnc:make-html-table-cell " "))))))

    (when (vector-ref cv col:balance)
      (set! row (append row
        (list (gnc:make-html-table-cell/markup
               "number-cell"
               (gnc:make-gnc-monetary currency (xaccSplitGetBalance split)))))))

    (gnc:html-table-append-row/markup! table row-style row)
    split-value))

;;------------------------------------------------------------------
;; Append the debit / credit total rows at the bottom of the table
;;------------------------------------------------------------------

(define (append-totals-rows! table cv debit-total credit-total currency)
  (let* ((double-mode? (vector-ref cv col:debit))
         ;; Count columns before the debit/credit pair
         (pre-cols (let loop ((i 0) (n 0))
                     (cond ((= i col:debit) n)
                           ((vector-ref cv i) (loop (+ i 1) (+ n 1)))
                           (else (loop (+ i 1) n)))))
         (pre-span (max 1 pre-cols)))

    (if double-mode?
        (begin
          ;; ---- Total Debit row ----
          (let* ((label (gnc:make-html-table-cell/markup
                          "total-label-cell" (G_ "Total Debit")))
                 (amt   (gnc:make-html-table-cell/markup
                          "total-number-cell"
                          (gnc:make-gnc-monetary currency debit-total)))
                 (row   (list label amt)))
            (gnc:html-table-cell-set-colspan! label pre-span)
            ;; blank cell under Credit column
            (when (vector-ref cv col:credit)
              (set! row (append row (list (gnc:make-html-table-cell " ")))))
            (when (vector-ref cv col:balance)
              (set! row (append row (list (gnc:make-html-table-cell " ")))))
            (gnc:html-table-append-row/markup! table "grand-total" row))

          ;; ---- Total Credit row ----
          (let* ((label (gnc:make-html-table-cell/markup
                          "total-label-cell" (G_ "Total Credit")))
                 (blank (gnc:make-html-table-cell " "))
                 (amt   (gnc:make-html-table-cell/markup
                          "total-number-cell"
                          (gnc:make-gnc-monetary currency credit-total)))
                 (row   (list label blank amt)))
            (gnc:html-table-cell-set-colspan! label pre-span)
            (when (vector-ref cv col:balance)
              (set! row (append row (list (gnc:make-html-table-cell " ")))))
            (gnc:html-table-append-row/markup! table "grand-total" row)))

        ;; Single-column mode: show net grand total
        (let* ((ncols (num-cols cv))
               (net   (gnc-numeric-sub debit-total credit-total
                                       GNC-DENOM-AUTO GNC-RND-ROUND))
               (label (gnc:make-html-table-cell/markup
                        "total-label-cell" (G_ "Grand Total")))
               (amt   (gnc:make-html-table-cell/markup
                        "total-number-cell"
                        (gnc:make-gnc-monetary currency net)))
               (row   (list label amt)))
          (gnc:html-table-cell-set-colspan! label (max 1 (- ncols 1)))
          (gnc:html-table-append-row/markup! table "grand-total" row)))))

;;------------------------------------------------------------------
;; Options generator  (GnuCash 5.x API)
;;------------------------------------------------------------------

(define (options-generator)
  (let ((options (gnc-new-optiondb)))

    ;; Date range
    (gnc:options-add-date-interval!
      options gnc:pagename-general
      optname-start-date optname-end-date "a")

    ;; Account selector
    (gnc-register-account-list-option options
      gnc:pagename-accounts optname-accounts
      "a" (N_ "Report on these accounts") '())

    ;; --- Display booleans ---
    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-date
      "a" (N_ "Show the transaction date?") #t)

    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-num
      "b" (N_ "Show the transaction number?") #t)

    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-description
      "c" (N_ "Show the description?") #t)

    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-memo
      "d" (N_ "Show the memo?") #t)

    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-account-name
      "e" (N_ "Show the account name?") #f)

    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-other-account
      "f" (N_ "Show the other account name?") #f)

    ;; Amount display mode
    (gnc-register-multichoice-option options
      gnc:pagename-display optname-amount
      "g" (N_ "Amount display mode") "Double"
      (list (vector "None"   (N_ "No amount column"))
            (vector "Single" (N_ "Single column"))
            (vector "Double" (N_ "Separate Debit and Credit columns"))))

    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-balance
      "h" (N_ "Show running balance?") #f)

    (gnc-register-simple-boolean-option options
      gnc:pagename-display optname-show-totals
      "i" (N_ "Show separate Debit and Credit total rows at the bottom?") #t)

    options))

;;------------------------------------------------------------------
;; Report renderer
;;------------------------------------------------------------------

(define (report-renderer report-obj)
  (let* ((options  (gnc:report-options report-obj))
         (document (gnc:make-html-document))
         (cv       (build-column-used options))
         (accounts (opt-val options gnc:pagename-accounts optname-accounts))
         (start-date (gnc:time64-start-day-time
                       (gnc:date-option-absolute-time
                         (opt-val options gnc:pagename-general optname-start-date))))
         (end-date   (gnc:time64-end-day-time
                       (gnc:date-option-absolute-time
                         (opt-val options gnc:pagename-general optname-end-date))))
         (show-totals? (opt-val options gnc:pagename-display optname-show-totals)))

    (gnc:html-document-set-title! document (G_ "Transaction Report (D/C Totals)"))

    (if (null? accounts)
        (gnc:html-document-add-object!
          document
          (gnc:make-html-text
            (gnc:html-markup-p
              (G_ "No accounts selected. Please open report options and choose accounts."))))

        (let* ((table        (gnc:make-html-table))
               (debit-sum    (gnc-numeric-zero))
               (credit-sum   (gnc-numeric-zero))
               (report-currency #f)
               (row-num      0))

          (gnc:html-table-set-col-headers! table (make-heading-list cv))

          ;; Build and run split query
          (let* ((query (qof-query-create-for-splits)))
            (qof-query-set-book query (gnc-get-current-book))
            (xaccQueryAddAccountMatch query accounts QOF-GUID-MATCH-ANY QOF-QUERY-AND)
            (xaccQueryAddDateMatchTT  query #t start-date #t end-date QOF-QUERY-AND)
            (qof-query-set-sort-order query
              (list SPLIT-TRANS TRANS-DATE-POSTED)
              (list SPLIT-TRANS TRANS-NUM)
              '())

            (for-each
              (lambda (split)
                (let* ((style      (if (odd? row-num) "normal-row" "alternate-row"))
                       (split-val  (add-split-row! table split cv style))
                       (amount     (gnc:gnc-monetary-amount split-val))
                       (currency   (gnc:gnc-monetary-commodity split-val)))

                  (unless report-currency
                    (set! report-currency currency))

                  (if (gnc-numeric-positive-p amount)
                      (set! debit-sum
                        (gnc-numeric-add debit-sum amount GNC-DENOM-AUTO GNC-RND-ROUND))
                      (set! credit-sum
                        (gnc-numeric-add credit-sum (gnc-numeric-neg amount)
                                         GNC-DENOM-AUTO GNC-RND-ROUND)))
                  (set! row-num (+ row-num 1))))
              (qof-query-run query))

            (qof-query-destroy query))

          ;; Append totals rows
          (when (and show-totals? report-currency)
            (append-totals-rows! table cv debit-sum credit-sum report-currency))

          (gnc:html-document-add-object! document table)))

    document))

;;------------------------------------------------------------------
;; Register the report with GnuCash
;;------------------------------------------------------------------

(gnc:define-report
  'version       1
  'name          reportname
  'report-guid   report-guid
  'menu-tip      (N_ "Transaction listing with separate Debit and Credit totals")
  ;; No menu-path: report appears at the top level of the Reports menu
  'options-generator options-generator
  'renderer      report-renderer)

;;==================================================================
;; INSTALLATION — GnuCash 5.x
;;
;; 1. Find your directories: Help → About GnuCash
;;      GNC_USERDATA_DIR   → copy this .scm file here
;;      GNC_USERCONFIG_DIR → edit/create config-user.scm here
;;
;; 2. Copy this file:
;;      Linux/macOS:  ~/.local/share/gnucash/
;;      Windows:      %APPDATA%\GnuCash\
;;    (exact path shown under GNC_USERDATA_DIR in Help → About)
;;
;; 3. In GNC_USERCONFIG_DIR, open or create config-user.scm and add:
;;      (load (gnc-build-userdata-path "transaction-with-dc-totals.scm"))
;;
;; 4. Restart GnuCash.
;;    The report appears under Reports → Utility →
;;    "Transaction Report (D/C Totals)"
;;
;; USAGE
;;    Open report options → Display tab
;;    Set Amount = "Double"  →  separate Debit and Credit columns
;;    Two total rows appear at the bottom: Total Debit and Total Credit
;;    Set Amount = "Single"  →  one net Grand Total row instead
;;==================================================================
