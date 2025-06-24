;; Loan Officer Verification Contract
;; Manages verification and authorization of banking loan officers

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_ALREADY_VERIFIED (err u402))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_INVALID_LICENSE (err u405))

;; Data structures
(define-map verified-officers
  { officer-address: principal }
  {
    license-number: (string-ascii 20),
    bank-name: (string-ascii 50),
    verification-date: uint,
    is-active: bool,
    approval-limit: uint
  }
)

(define-map officer-metrics
  { officer-address: principal }
  {
    total-applications: uint,
    approved-loans: uint,
    rejected-loans: uint,
    total-volume: uint
  }
)

;; Verify a new loan officer
(define-public (verify-officer
  (officer-address principal)
  (license-number (string-ascii 20))
  (bank-name (string-ascii 50))
  (approval-limit uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? verified-officers { officer-address: officer-address })) ERR_ALREADY_VERIFIED)
    (asserts! (> (len license-number) u0) ERR_INVALID_LICENSE)

    (map-set verified-officers
      { officer-address: officer-address }
      {
        license-number: license-number,
        bank-name: bank-name,
        verification-date: block-height,
        is-active: true,
        approval-limit: approval-limit
      }
    )

    (map-set officer-metrics
      { officer-address: officer-address }
      {
        total-applications: u0,
        approved-loans: u0,
        rejected-loans: u0,
        total-volume: u0
      }
    )

    (ok true)
  )
)

;; Check if officer is verified and active
(define-read-only (is-verified-officer (officer-address principal))
  (match (map-get? verified-officers { officer-address: officer-address })
    officer-data (get is-active officer-data)
    false
  )
)

;; Get officer details
(define-read-only (get-officer-details (officer-address principal))
  (map-get? verified-officers { officer-address: officer-address })
)

;; Get officer metrics
(define-read-only (get-officer-metrics (officer-address principal))
  (map-get? officer-metrics { officer-address: officer-address })
)

;; Update officer metrics (called by other contracts)
(define-public (update-officer-metrics
  (officer-address principal)
  (application-count uint)
  (approved-count uint)
  (rejected-count uint)
  (volume uint))
  (let ((current-metrics (default-to
          { total-applications: u0, approved-loans: u0, rejected-loans: u0, total-volume: u0 }
          (map-get? officer-metrics { officer-address: officer-address }))))
    (map-set officer-metrics
      { officer-address: officer-address }
      {
        total-applications: (+ (get total-applications current-metrics) application-count),
        approved-loans: (+ (get approved-loans current-metrics) approved-count),
        rejected-loans: (+ (get rejected-loans current-metrics) rejected-count),
        total-volume: (+ (get total-volume current-metrics) volume)
      }
    )
    (ok true)
  )
)

;; Deactivate officer
(define-public (deactivate-officer (officer-address principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? verified-officers { officer-address: officer-address })) ERR_NOT_FOUND)

    (map-set verified-officers
      { officer-address: officer-address }
      (merge
        (unwrap-panic (map-get? verified-officers { officer-address: officer-address }))
        { is-active: false }
      )
    )
    (ok true)
  )
)
