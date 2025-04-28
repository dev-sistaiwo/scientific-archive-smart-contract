;; Scientific Archive Management Smart Contract

;; Global Constants for Error Handling
(define-constant CONTRACT_ADMINISTRATOR tx-sender)
(define-constant ERR_ACCESS_VIOLATION (err u305))
(define-constant ERR_UNAUTHORIZED_USER (err u300))
(define-constant ERR_PAPER_NONEXISTENT (err u301))
(define-constant ERR_PAPER_DUPLICATE (err u302))
(define-constant ERR_INVALID_PAPER_TITLE (err u303))
(define-constant ERR_INVALID_PAPER_SIZE (err u304))

;; Primary State Tracker
(define-data-var paper-sequence-number uint u0)

;; Primary Storage Structures
(define-map scientific-papers
  { paper-id: uint }
  {
    paper-title: (string-ascii 80),
    paper-author: principal,
    paper-size: uint,
    submission-block: uint,
    paper-abstract: (string-ascii 256),
    paper-keywords: (list 8 (string-ascii 40))
  }
)

(define-map access-registry
  { paper-id: uint, researcher: principal }
  { can-view: bool }
)

;; Helper Functions for Validation


(define-private (is-paper-creator (paper-id uint) (author principal))
  (match (map-get? scientific-papers { paper-id: paper-id })
    paper-data (is-eq (get paper-author paper-data) author)
    false
  )
)

(define-private (get-paper-size (paper-id uint))
  (default-to u0 
    (get paper-size 
      (map-get? scientific-papers { paper-id: paper-id })
    )
  )
)

(define-private (paper-exists-in-registry (paper-id uint))
  (is-some (map-get? scientific-papers { paper-id: paper-id }))
)

(define-private (is-valid-keyword (keyword (string-ascii 40)))
  (and 
    (> (len keyword) u0)
    (< (len keyword) u41)
  )
)
