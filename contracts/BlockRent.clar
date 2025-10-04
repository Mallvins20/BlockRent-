;; -----------------------------------------------------------------------------
;; BlockRent.clar
;; A professional, secure Clarity smart contract for land rental agreements.
;; - Register land parcels
;; - Create rental agreements (landlord -> tenant)
;; - Pay rent (tenant transfers STX directly to landlord)
;; - Renew and terminate agreements
;; - Query agreement/land/lease status
;;
;; Security improvements:
;; - All user inputs are validated
;; - Proper checks for zero values and valid ranges
;; - Principal validation to prevent self-transactions
;; -----------------------------------------------------------------------------

(define-constant contract-version "1.0")
(define-constant contract-owner tx-sender)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u1))
(define-constant ERR-NOT-FOUND (err u2))
(define-constant ERR-INVALID-LAND-OWNER (err u3))
(define-constant ERR-LAND-NOT-FOUND (err u4))
(define-constant ERR-NOT-LAND-OWNER (err u5))
(define-constant ERR-INVALID-DURATION (err u6))
(define-constant ERR-INVALID-PERIOD (err u7))
(define-constant ERR-LAND-NOT-REGISTERED (err u8))
(define-constant ERR-NOT-TENANT (err u9))
(define-constant ERR-TRANSFER-FAILED (err u10))
(define-constant ERR-AGREEMENT-NOT-FOUND (err u11))
(define-constant ERR-NOT-PARTY (err u12))
(define-constant ERR-INVALID-EXTRA-DURATION (err u13))
(define-constant ERR-AGREEMENT-NOT-FOUND-RENEW (err u14))
(define-constant ERR-NOT-AUTHORIZED-TERMINATE (err u15))
(define-constant ERR-AGREEMENT-NOT-FOUND-TERMINATE (err u16))
(define-constant ERR-CHECK-FAILED (err u17))
(define-constant ERR-NEXT-RENT-NOT-FOUND (err u18))
(define-constant ERR-NOT-CONTRACT-OWNER (err u19))
(define-constant ERR-ADMIN-DEACTIVATE-FAILED (err u20))
(define-constant ERR-INVALID-RENT-AMOUNT (err u21))
(define-constant ERR-INVALID-TENANT (err u22))
(define-constant ERR-INVALID-NEW-OWNER (err u23))
(define-constant ERR-INVALID-META (err u24))

;; -------------------------
;; DATA COUNTERS
;; -------------------------
(define-data-var land-counter uint u0)
(define-data-var agreement-counter uint u0)

;; -------------------------
;; DATA STRUCTURES
;; -------------------------
(define-map lands
  { land-id: uint }
  {
    owner: principal,
    meta: (string-ascii 64)
  }
)

(define-map agreements
  { agreement-id: uint }
  {
    land-id: uint,
    landlord: principal,
    tenant: principal,
    rent-amount: uint,
    start-block: uint,
    duration: uint,
    period: uint,
    auto-renew: bool,
    active: bool
  }
)

;; -------------------------
;; HELPERS
;; -------------------------
(define-read-only (is-contract-owner (caller principal))
  (ok (is-eq caller contract-owner))
)

(define-read-only (now-block)
  (ok stacks-block-height)
)

(define-read-only (agreement-expiry (agreement-id uint))
  (match (map-get? agreements { agreement-id: agreement-id })
    agreement
    (ok (+ (get start-block agreement) (get duration agreement)))
    ERR-NOT-FOUND
  )
)

(define-read-only (is-agreement-active (agreement-id uint))
  (match (map-get? agreements { agreement-id: agreement-id })
    agreement
    (let ((active-flag (get active agreement))
          (expiry (+ (get start-block agreement) (get duration agreement))))
      (ok (and active-flag (<= stacks-block-height expiry))))
    ERR-NOT-FOUND
  )
)

;; -------------------------
;; PUBLIC: LAND MANAGEMENT
;; -------------------------

;; <CHANGE> Added validation for meta string length
(define-public (register-land (meta (string-ascii 64)))
  (let ((new-id (+ (var-get land-counter) u1)))
    (begin
      ;; Validate meta is not empty
      (asserts! (> (len meta) u0) ERR-INVALID-META)
      (map-set lands { land-id: new-id } { owner: tx-sender, meta: meta })
      (var-set land-counter new-id)
      (print { event: "register-land", land-id: new-id, owner: tx-sender, meta: meta })
      (ok new-id)
    )
  )
)

;; <CHANGE> Added validation to prevent self-transfer and check new-owner is valid
(define-public (transfer-land (land-id uint) (new-owner principal))
  (match (map-get? lands { land-id: land-id })
    land
    (let ((current-owner (get owner land)))
      (begin
        ;; Validate caller is current owner
        (asserts! (is-eq tx-sender current-owner) ERR-INVALID-LAND-OWNER)
        ;; Validate land-id is not zero
        (asserts! (> land-id u0) ERR-LAND-NOT-FOUND)
        ;; Validate new-owner is not the same as current owner
        (asserts! (not (is-eq new-owner current-owner)) ERR-INVALID-NEW-OWNER)
        (map-set lands { land-id: land-id } { owner: new-owner, meta: (get meta land) })
        (print { event: "transfer-land", land-id: land-id, from: current-owner, to: new-owner })
        (ok true)
      )
    )
    ERR-LAND-NOT-FOUND
  )
)

;; -------------------------
;; PUBLIC: AGREEMENT LIFECYCLE
;; -------------------------

;; <CHANGE> Added comprehensive input validation for all parameters
(define-public (create-agreement
               (land-id uint)
               (tenant principal)
               (rent-amount uint)
               (duration uint)
               (period uint)
               (auto-renew bool))
  (match (map-get? lands { land-id: land-id })
    land
    (let ((owner (get owner land)))
      (begin
        ;; Validate caller is land owner
        (asserts! (is-eq tx-sender owner) ERR-NOT-LAND-OWNER)
        ;; Validate land-id is not zero
        (asserts! (> land-id u0) ERR-LAND-NOT-REGISTERED)
        ;; Validate tenant is not the same as landlord
        (asserts! (not (is-eq tenant tx-sender)) ERR-INVALID-TENANT)
        ;; Validate rent-amount is greater than zero
        (asserts! (> rent-amount u0) ERR-INVALID-RENT-AMOUNT)
        ;; Validate duration is greater than zero
        (asserts! (> duration u0) ERR-INVALID-DURATION)
        ;; Validate period is greater than zero
        (asserts! (> period u0) ERR-INVALID-PERIOD)
        ;; Validate period is not greater than duration
        (asserts! (<= period duration) ERR-INVALID-PERIOD)
        
        (let ((id (+ (var-get agreement-counter) u1))
              (start stacks-block-height))
          (map-set agreements { agreement-id: id }
            {
              land-id: land-id,
              landlord: tx-sender,
              tenant: tenant,
              rent-amount: rent-amount,
              start-block: start,
              duration: duration,
              period: period,
              auto-renew: auto-renew,
              active: true
            })
          (var-set agreement-counter id)
          (print { event: "create-agreement", agreement-id: id, land-id: land-id, landlord: tx-sender, tenant: tenant, rent: rent-amount, start-block: start, duration: duration })
          (ok id)
        )
      )
    )
    ERR-LAND-NOT-REGISTERED
  )
)

;; <CHANGE> Added validation for agreement-id and amount checks
(define-public (pay-rent (agreement-id uint))
  (match (map-get? agreements { agreement-id: agreement-id })
    ag
    (let ((tenant (get tenant ag))
          (landlord (get landlord ag))
          (amount (get rent-amount ag)))
      (begin
        ;; Validate agreement-id is not zero
        (asserts! (> agreement-id u0) ERR-AGREEMENT-NOT-FOUND)
        ;; Validate caller is tenant
        (asserts! (is-eq tx-sender tenant) ERR-NOT-TENANT)
        ;; Validate agreement is active
        (asserts! (get active ag) ERR-NOT-AUTHORIZED)
        ;; Validate rent amount is greater than zero
        (asserts! (> amount u0) ERR-INVALID-RENT-AMOUNT)
        ;; Transfer STX directly from tenant to landlord
        (unwrap! (stx-transfer? amount tx-sender landlord) ERR-TRANSFER-FAILED)
        (print { event: "rent-paid", agreement-id: agreement-id, payer: tx-sender, amount: amount, to: landlord, block-height: stacks-block-height })
        (ok amount)
      )
    )
    ERR-AGREEMENT-NOT-FOUND
  )
)

;; <CHANGE> Added validation for agreement-id and extra-duration
(define-public (renew-agreement (agreement-id uint) (extra-duration uint))
  (match (map-get? agreements { agreement-id: agreement-id })
    ag
    (let ((landlord (get landlord ag))
          (tenant (get tenant ag))
          (current-start (get start-block ag))
          (current-duration (get duration ag)))
      (begin
        ;; Validate agreement-id is not zero
        (asserts! (> agreement-id u0) ERR-AGREEMENT-NOT-FOUND-RENEW)
        ;; Validate caller is landlord or tenant
        (asserts! (or (is-eq tx-sender landlord) (is-eq tx-sender tenant)) ERR-NOT-PARTY)
        ;; Validate extra-duration is greater than zero
        (asserts! (> extra-duration u0) ERR-INVALID-EXTRA-DURATION)
        ;; Validate agreement is active
        (asserts! (get active ag) ERR-NOT-AUTHORIZED)
        
        ;; New duration adds to existing duration
        (map-set agreements { agreement-id: agreement-id }
          {
            land-id: (get land-id ag),
            landlord: landlord,
            tenant: tenant,
            rent-amount: (get rent-amount ag),
            start-block: current-start,
            duration: (+ current-duration extra-duration),
            period: (get period ag),
            auto-renew: (get auto-renew ag),
            active: (get active ag)
          })
        (print { event: "renew-agreement", agreement-id: agreement-id, new-duration: (+ current-duration extra-duration), by: tx-sender })
        (ok true)
      )
    )
    ERR-AGREEMENT-NOT-FOUND-RENEW
  )
)

;; <CHANGE> Added validation for agreement-id and reason
(define-public (terminate-agreement (agreement-id uint) (reason (string-ascii 64)))
  (match (map-get? agreements { agreement-id: agreement-id })
    ag
    (let ((landlord (get landlord ag))
          (tenant (get tenant ag)))
      (begin
        ;; Validate agreement-id is not zero
        (asserts! (> agreement-id u0) ERR-AGREEMENT-NOT-FOUND-TERMINATE)
        ;; Validate caller is authorized (landlord, tenant, or contract owner)
        (asserts! (or (is-eq tx-sender landlord) (is-eq tx-sender tenant) (is-eq tx-sender contract-owner)) ERR-NOT-AUTHORIZED-TERMINATE)
        ;; Validate reason is not empty
        (asserts! (> (len reason) u0) ERR-INVALID-META)
        
        (map-set agreements { agreement-id: agreement-id }
          {
            land-id: (get land-id ag),
            landlord: landlord,
            tenant: tenant,
            rent-amount: (get rent-amount ag),
            start-block: (get start-block ag),
            duration: (get duration ag),
            period: (get period ag),
            auto-renew: (get auto-renew ag),
            active: false
          })
        (print { event: "terminate-agreement", agreement-id: agreement-id, by: tx-sender, block-height: stacks-block-height, reason: reason })
        (ok true)
      )
    )
    ERR-AGREEMENT-NOT-FOUND-TERMINATE
  )
)

;; -------------------------
;; READ-ONLY QUERIES
;; -------------------------

(define-read-only (get-land (land-id uint))
  (map-get? lands { land-id: land-id })
)

(define-read-only (get-agreement (agreement-id uint))
  (map-get? agreements { agreement-id: agreement-id })
)

;; <CHANGE> Added validation for agreement-id parameter
(define-read-only (check-landlord-agreement (owner principal) (agreement-id uint))
  (begin
    ;; Validate agreement-id is not zero
    (asserts! (> agreement-id u0) ERR-CHECK-FAILED)
    (match (map-get? agreements { agreement-id: agreement-id })
      ag
      (ok (is-eq (get landlord ag) owner))
      ERR-CHECK-FAILED
    )
  )
)

;; <CHANGE> Added validation for agreement-id parameter
(define-read-only (next-rent-due (agreement-id uint))
  (begin
    ;; Validate agreement-id is not zero
    (asserts! (> agreement-id u0) ERR-NEXT-RENT-NOT-FOUND)
    (match (map-get? agreements { agreement-id: agreement-id })
      ag
      (let ((start (get start-block ag))
            (period (get period ag))
            (duration (get duration ag))
            (now stacks-block-height))
        (if (< now start)
            (ok start)
            (let ((elapsed (- now start)))
              (let ((periods-elapsed (/ elapsed period)))
                (ok (+ start (* (+ periods-elapsed u1) period)))
              )
            )
        )
      )
      ERR-NEXT-RENT-NOT-FOUND
    )
  )
)

(define-read-only (get-contract-owner)
  (ok contract-owner)
)

(define-read-only (get-counters)
  (ok { land-counter: (var-get land-counter), agreement-counter: (var-get agreement-counter) })
)

;; -------------------------
;; ADMIN: emergency function (contract owner only)
;; -------------------------
;; <CHANGE> Added validation for agreement-id and reason parameters
(define-public (admin-deactivate (agreement-id uint) (reason (string-ascii 64)))
  (begin
    ;; Validate caller is contract owner
    (asserts! (is-eq tx-sender contract-owner) ERR-NOT-CONTRACT-OWNER)
    ;; Validate agreement-id is not zero
    (asserts! (> agreement-id u0) ERR-ADMIN-DEACTIVATE-FAILED)
    ;; Validate reason is not empty
    (asserts! (> (len reason) u0) ERR-INVALID-META)
    
    (match (map-get? agreements { agreement-id: agreement-id })
      ag
      (begin
        (map-set agreements { agreement-id: agreement-id }
          {
            land-id: (get land-id ag),
            landlord: (get landlord ag),
            tenant: (get tenant ag),
            rent-amount: (get rent-amount ag),
            start-block: (get start-block ag),
            duration: (get duration ag),
            period: (get period ag),
            auto-renew: (get auto-renew ag),
            active: false
          })
        (print { event: "admin-deactivate", agreement-id: agreement-id, reason: reason, by: tx-sender })
        (ok true)
      )
      ERR-ADMIN-DEACTIVATE-FAILED
    )
  )
)

;; -----------------------------------------------------------------------------
;; End of BlockRent.clar
;; -----------------------------------------------------------------------------