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

(define-private (are-keywords-valid (keywords (list 8 (string-ascii 40))))
  (and
    (> (len keywords) u0)
    (<= (len keywords) u8)
    (is-eq (len (filter is-valid-keyword keywords)) (len keywords))
  )
)

;; Core Paper Registration Function
(define-public (register-scientific-paper (title (string-ascii 80)) (size uint) (abstract (string-ascii 256)) (keywords (list 8 (string-ascii 40))))
  (let
    (
      (paper-id (+ (var-get paper-sequence-number) u1))
    )
    ;; Input validation block
    (asserts! (> (len title) u0) ERR_INVALID_PAPER_TITLE)
    (asserts! (< (len title) u81) ERR_INVALID_PAPER_TITLE)
    (asserts! (> size u0) ERR_INVALID_PAPER_SIZE)
    (asserts! (< size u2000000000) ERR_INVALID_PAPER_SIZE)
    (asserts! (> (len abstract) u0) ERR_INVALID_PAPER_TITLE)
    (asserts! (< (len abstract) u257) ERR_INVALID_PAPER_TITLE)
    (asserts! (are-keywords-valid keywords) ERR_INVALID_PAPER_TITLE)

    ;; Store paper metadata in catalog
    (map-insert scientific-papers
      { paper-id: paper-id }
      {
        paper-title: title,
        paper-author: tx-sender,
        paper-size: size,
        submission-block: block-height,
        paper-abstract: abstract,
        paper-keywords: keywords
      }
    )

    ;; Grant initial access permission to author
    (map-insert access-registry
      { paper-id: paper-id, researcher: tx-sender }
      { can-view: true }
    )

    ;; Update global sequence number
    (var-set paper-sequence-number paper-id)
    (ok paper-id)
  )
)

;; Alternative implementation with more readable structure
(define-public (catalog-new-paper (title (string-ascii 80)) (size uint) (abstract (string-ascii 256)) (keywords (list 8 (string-ascii 40))))
  (let
    (
      (paper-id (+ (var-get paper-sequence-number) u1))
    )
    ;; Comprehensive validation suite
    (asserts! (> (len title) u0) ERR_INVALID_PAPER_TITLE)
    (asserts! (< (len title) u81) ERR_INVALID_PAPER_TITLE)
    (asserts! (> size u0) ERR_INVALID_PAPER_SIZE)
    (asserts! (< size u2000000000) ERR_INVALID_PAPER_SIZE)
    (asserts! (> (len abstract) u0) ERR_INVALID_PAPER_TITLE)
    (asserts! (< (len abstract) u257) ERR_INVALID_PAPER_TITLE)
    (asserts! (are-keywords-valid keywords) ERR_INVALID_PAPER_TITLE)

    ;; Register paper in scientific database
    (map-insert scientific-papers
      { paper-id: paper-id }
      {
        paper-title: title,
        paper-author: tx-sender,
        paper-size: size,
        submission-block: block-height,
        paper-abstract: abstract,
        paper-keywords: keywords
      }
    )

    ;; Configure initial access permissions
    (map-insert access-registry
      { paper-id: paper-id, researcher: tx-sender }
      { can-view: true }
    )

    ;; Update global sequence counter
    (var-set paper-sequence-number paper-id)
    (ok paper-id)
  )
)

;; Paper Metadata Update Function
(define-public (update-paper-metadata (paper-id uint) (revised-title (string-ascii 80)) (revised-size uint) (revised-abstract (string-ascii 256)) (revised-keywords (list 8 (string-ascii 40))))
  (let
    (
      (paper-data (unwrap! (map-get? scientific-papers { paper-id: paper-id }) ERR_PAPER_NONEXISTENT))
    )
    ;; Verify the paper exists in registry
    (asserts! (paper-exists-in-registry paper-id) ERR_PAPER_NONEXISTENT)
    ;; Confirm requester is the original author
    (asserts! (is-eq (get paper-author paper-data) tx-sender) ERR_ACCESS_VIOLATION)

    ;; Validate updated metadata fields
    (asserts! (> (len revised-title) u0) ERR_INVALID_PAPER_TITLE)
    (asserts! (< (len revised-title) u81) ERR_INVALID_PAPER_TITLE)
    (asserts! (> revised-size u0) ERR_INVALID_PAPER_SIZE)
    (asserts! (< revised-size u2000000000) ERR_INVALID_PAPER_SIZE)
    (asserts! (> (len revised-abstract) u0) ERR_INVALID_PAPER_TITLE)
    (asserts! (< (len revised-abstract) u257) ERR_INVALID_PAPER_TITLE)
    (asserts! (are-keywords-valid revised-keywords) ERR_INVALID_PAPER_TITLE)

    ;; Apply metadata updates while preserving immutable fields
    (map-set scientific-papers
      { paper-id: paper-id }
      (merge paper-data { 
        paper-title: revised-title, 
        paper-size: revised-size, 
        paper-abstract: revised-abstract, 
        paper-keywords: revised-keywords 
      })
    )
    (ok true)
  )
)

;; Withdrawal Function - Removes paper from archive
(define-public (withdraw-scientific-paper (paper-id uint))
  (let
    (
      (paper-data (unwrap! (map-get? scientific-papers { paper-id: paper-id }) ERR_PAPER_NONEXISTENT))
    )
    ;; Verify paper exists
    (asserts! (paper-exists-in-registry paper-id) ERR_PAPER_NONEXISTENT)
    ;; Verify requester has authority
    (asserts! (is-eq (get paper-author paper-data) tx-sender) ERR_ACCESS_VIOLATION)

    ;; Remove paper from scientific repository
    (map-delete scientific-papers { paper-id: paper-id })
    (ok true)
  )
)

;; User Interface Generation Functions

;; Generates formatted paper display for interface
(define-public (create-paper-display (paper-id uint))
  (let
    (
      (paper-data (unwrap! (map-get? scientific-papers { paper-id: paper-id }) ERR_PAPER_NONEXISTENT))
    )
    ;; Construct UI display object
    (ok {
      page-title: "Scientific Paper Details",
      paper-title: (get paper-title paper-data),
      paper-author: (get paper-author paper-data),
      paper-abstract: (get paper-abstract paper-data),
      paper-keywords: (get paper-keywords paper-data)
    })
  )
)

;; Retrieves formatted paper metadata for UI rendering
(define-public (generate-paper-view (paper-id uint))
  (let
    (
      (paper-data (unwrap! (map-get? scientific-papers { paper-id: paper-id }) ERR_PAPER_NONEXISTENT))
    )
    ;; Construct presentation data structure
    (ok {
      title: (get paper-title paper-data),
      author: (get paper-author paper-data),
      size: (get paper-size paper-data),
      abstract: (get paper-abstract paper-data),
      keywords: (get paper-keywords paper-data)
    })
  )
)

;; Optimized Read Functions

;; Lightweight paper information retrieval
(define-public (retrieve-paper-basic (paper-id uint))
  (let
    (
      (paper-data (unwrap! (map-get? scientific-papers { paper-id: paper-id }) ERR_PAPER_NONEXISTENT))
    )
    ;; Return essential information only
    (ok {
      paper-title: (get paper-title paper-data),
      paper-author: (get paper-author paper-data),
      paper-size: (get paper-size paper-data)
    })
  )
)
;; This function delivers minimal paper identification data to reduce computational costs

;; Ultra-efficient paper lookup
(define-public (retrieve-paper-minimal (paper-id uint))
  (let
    (
      (paper-data (unwrap! (map-get? scientific-papers { paper-id: paper-id }) ERR_PAPER_NONEXISTENT))
    )
    ;; Return only paper identification essentials for maximum efficiency
    (ok {
      paper-title: (get paper-title paper-data),
      paper-author: (get paper-author paper-data)
    })
  )
)
;; This optimized function provides only core identification details

;; Specialized abstract retrieval function
(define-public (retrieve-paper-abstract (paper-id uint))
  (let
    (
      (paper-data (unwrap! (map-get? scientific-papers { paper-id: paper-id }) ERR_PAPER_NONEXISTENT))
    )
    (ok (get paper-abstract paper-data))
  )
)

;; Paper Submission Validation Suite
(define-public (validate-paper-submission (title (string-ascii 80)) (size uint) (abstract (string-ascii 256)) (keywords (list 8 (string-ascii 40))))
  (begin
    ;; Validate paper title parameters
    (asserts! (> (len title) u0) ERR_INVALID_PAPER_TITLE)
    (asserts! (< (len title) u81) ERR_INVALID_PAPER_TITLE)

    ;; Validate paper size parameters
    (asserts! (> size u0) ERR_INVALID_PAPER_SIZE)
    (asserts! (< size u2000000000) ERR_INVALID_PAPER_SIZE)

    ;; Validate abstract length constraints
    (asserts! (> (len abstract) u0) ERR_INVALID_PAPER_TITLE)
    (asserts! (< (len abstract) u257) ERR_INVALID_PAPER_TITLE)

    ;; Validate keyword format and constraints
    (asserts! (are-keywords-valid keywords) ERR_INVALID_PAPER_TITLE)

    ;; All validations passed
    (ok true)
  )
)

