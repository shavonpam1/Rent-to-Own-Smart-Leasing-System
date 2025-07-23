(define-constant ERR_NOT_AUTHORIZED (err u1))
(define-constant ERR_PROPERTY_NOT_FOUND (err u2))
(define-constant ERR_LEASE_NOT_FOUND (err u3))
(define-constant ERR_LEASE_EXPIRED (err u4))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u5))
(define-constant ERR_ALREADY_OWNER (err u6))
(define-constant ERR_LEASE_ACTIVE (err u7))
(define-constant ERR_INVALID_PARAMS (err u8))
(define-constant ERR_PAYMENT_LATE (err u9))
(define-constant ERR_EARLY_EXIT (err u10))

(define-constant CONTRACT_OWNER tx-sender)
(define-constant LATE_PENALTY_RATE u5)
(define-constant EARLY_EXIT_PENALTY_RATE u15)
(define-constant COMPLETION_BONUS_RATE u10)

(define-data-var next-property-id uint u1)
(define-data-var next-lease-id uint u1)

(define-map properties 
  uint 
  {
    owner: principal,
    address: (string-ascii 100),
    value: uint,
    monthly-rent: uint,
    equity-rate: uint,
    is-available: bool
  }
)

(define-map leases 
  uint 
  {
    property-id: uint,
    tenant: principal,
    monthly-rent: uint,
    equity-rate: uint,
    start-block: uint,
    end-block: uint,
    total-payments: uint,
    accumulated-equity: uint,
    is-active: bool,
    ownership-threshold: uint
  }
)

(define-map payments 
  {lease-id: uint, payment-number: uint}
  {
    amount: uint,
    equity-amount: uint,
    payment-block: uint,
    is-on-time: bool
  }
)

(define-map lease-payment-count uint uint)

(define-public (register-property (address (string-ascii 100)) (value uint) (monthly-rent uint) (equity-rate uint))
  (let ((property-id (var-get next-property-id)))
    (asserts! (> value u0) ERR_INVALID_PARAMS)
    (asserts! (> monthly-rent u0) ERR_INVALID_PARAMS)
    (asserts! (<= equity-rate u100) ERR_INVALID_PARAMS)
    (map-set properties property-id {
      owner: tx-sender,
      address: address,
      value: value,
      monthly-rent: monthly-rent,
      equity-rate: equity-rate,
      is-available: true
    })
    (var-set next-property-id (+ property-id u1))
    (ok property-id)
  )
)

(define-public (create-lease (property-id uint) (tenant principal) (lease-duration uint))
  (let 
    (
      (property (unwrap! (map-get? properties property-id) ERR_PROPERTY_NOT_FOUND))
      (lease-id (var-get next-lease-id))
      (current-block stacks-block-height)
      (end-block (+ current-block lease-duration))
      (ownership-threshold (/ (* (get value property) u80) u100))
    )
    (asserts! (is-eq tx-sender (get owner property)) ERR_NOT_AUTHORIZED)
    (asserts! (get is-available property) ERR_LEASE_ACTIVE)
    (asserts! (> lease-duration u0) ERR_INVALID_PARAMS)
    
    (map-set properties property-id (merge property {is-available: false}))
    (map-set leases lease-id {
      property-id: property-id,
      tenant: tenant,
      monthly-rent: (get monthly-rent property),
      equity-rate: (get equity-rate property),
      start-block: current-block,
      end-block: end-block,
      total-payments: u0,
      accumulated-equity: u0,
      is-active: true,
      ownership-threshold: ownership-threshold
    })
    (map-set lease-payment-count lease-id u0)
    (var-set next-lease-id (+ lease-id u1))
    (ok lease-id)
  )
)

(define-public (make-payment (lease-id uint))
  (let 
    (
      (lease (unwrap! (map-get? leases lease-id) ERR_LEASE_NOT_FOUND))
      (current-block stacks-block-height)
      (payment-count (default-to u0 (map-get? lease-payment-count lease-id)))
      (new-payment-count (+ payment-count u1))
      (expected-payment-block (+ (get start-block lease) (* payment-count u1008)))
      (is-late (> current-block (+ expected-payment-block u144)))
      (base-rent (get monthly-rent lease))
      (penalty (if is-late (/ (* base-rent LATE_PENALTY_RATE) u100) u0))
      (total-amount (+ base-rent penalty))
      (equity-amount (if is-late 
                        (/ (* base-rent (get equity-rate lease)) u100)
                        (/ (* total-amount (get equity-rate lease)) u100)))
    )
    (asserts! (get is-active lease) ERR_LEASE_EXPIRED)
    (asserts! (is-eq tx-sender (get tenant lease)) ERR_NOT_AUTHORIZED)
    (asserts! (<= current-block (get end-block lease)) ERR_LEASE_EXPIRED)
    
    (try! (stx-transfer? total-amount tx-sender (get-property-owner (get property-id lease))))
    
    (map-set payments {lease-id: lease-id, payment-number: new-payment-count} {
      amount: total-amount,
      equity-amount: equity-amount,
      payment-block: current-block,
      is-on-time: (not is-late)
    })
    
    (map-set lease-payment-count lease-id new-payment-count)
    
    (let ((updated-lease (merge lease {
      total-payments: (+ (get total-payments lease) total-amount),
      accumulated-equity: (+ (get accumulated-equity lease) equity-amount)
    })))
      (map-set leases lease-id updated-lease)
      
      (if (>= (get accumulated-equity updated-lease) (get ownership-threshold updated-lease))
        (transfer-ownership lease-id)
        (ok true))
    )
  )
)

(define-public (early-exit (lease-id uint))
  (let 
    (
      (lease (unwrap! (map-get? leases lease-id) ERR_LEASE_NOT_FOUND))
      (property (unwrap! (map-get? properties (get property-id lease)) ERR_PROPERTY_NOT_FOUND))
      (penalty-amount (/ (* (get accumulated-equity lease) EARLY_EXIT_PENALTY_RATE) u100))
      (refund-amount (- (get accumulated-equity lease) penalty-amount))
    )
    (asserts! (is-eq tx-sender (get tenant lease)) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active lease) ERR_LEASE_EXPIRED)
    
    (map-set leases lease-id (merge lease {is-active: false}))
    (map-set properties (get property-id lease) (merge property {is-available: true}))
    
    (if (> refund-amount u0)
      (unwrap-panic (stx-transfer? refund-amount (get owner property) tx-sender))
      true)
    
    (ok refund-amount)
  )
)

(define-public (complete-lease (lease-id uint))
  (let 
    (
      (lease (unwrap! (map-get? leases lease-id) ERR_LEASE_NOT_FOUND))
      (property (unwrap! (map-get? properties (get property-id lease)) ERR_PROPERTY_NOT_FOUND))
      (current-block stacks-block-height)
      (bonus-amount (/ (* (get accumulated-equity lease) COMPLETION_BONUS_RATE) u100))
      (total-equity (+ (get accumulated-equity lease) bonus-amount))
    )
    (asserts! (is-eq tx-sender (get tenant lease)) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active lease) ERR_LEASE_EXPIRED)
    (asserts! (>= current-block (get end-block lease)) ERR_EARLY_EXIT)
    
    (map-set leases lease-id (merge lease {
      is-active: false,
      accumulated-equity: total-equity
    }))
    
    (if (>= total-equity (get ownership-threshold lease))
      (unwrap-panic (transfer-ownership lease-id))
      (unwrap-panic (stx-transfer? total-equity (get owner property) tx-sender)))
    
    (ok total-equity)
  )
)

(define-private (transfer-ownership (lease-id uint))
  (let 
    (
      (lease (unwrap! (map-get? leases lease-id) ERR_LEASE_NOT_FOUND))
      (property (unwrap! (map-get? properties (get property-id lease)) ERR_PROPERTY_NOT_FOUND))
    )
    (map-set properties (get property-id lease) (merge property {
      owner: (get tenant lease),
      is-available: false
    }))
    (ok true)
  )
)

(define-private (get-property-owner (property-id uint))
  (get owner (unwrap-panic (map-get? properties property-id)))
)

(define-read-only (get-property (property-id uint))
  (map-get? properties property-id)
)

(define-read-only (get-lease (lease-id uint))
  (map-get? leases lease-id)
)

(define-read-only (get-payment (lease-id uint) (payment-number uint))
  (map-get? payments {lease-id: lease-id, payment-number: payment-number})
)

(define-read-only (get-lease-payment-count (lease-id uint))
  (default-to u0 (map-get? lease-payment-count lease-id))
)

(define-read-only (get-equity-progress (lease-id uint))
  (match (map-get? leases lease-id)
    lease (ok {
      accumulated-equity: (get accumulated-equity lease),
      ownership-threshold: (get ownership-threshold lease),
      progress-percentage: (/ (* (get accumulated-equity lease) u100) (get ownership-threshold lease))
    })
    ERR_LEASE_NOT_FOUND
  )
)

(define-read-only (get-next-payment-due (lease-id uint))
  (match (map-get? leases lease-id)
    lease (let 
      (
        (payment-count (get-lease-payment-count lease-id))
        (next-payment-block (+ (get start-block lease) (* (+ payment-count u1) u1008)))
        (current-block stacks-block-height)
      )
      (ok {
        next-payment-block: next-payment-block,
        blocks-until-due: (if (> next-payment-block current-block) 
                            (- next-payment-block current-block) 
                            u0),
        is-overdue: (> current-block next-payment-block)
      })
    )
    ERR_LEASE_NOT_FOUND
  )
)

(define-read-only (calculate-penalty (lease-id uint))
  (match (map-get? leases lease-id)
    lease (let 
      (
        (payment-count (get-lease-payment-count lease-id))
        (expected-payment-block (+ (get start-block lease) (* payment-count u1008)))
        (current-block stacks-block-height)
        (is-late (> current-block (+ expected-payment-block u144)))
        (base-rent (get monthly-rent lease))
      )
      (ok (if is-late (/ (* base-rent LATE_PENALTY_RATE) u100) u0))
    )
    ERR_LEASE_NOT_FOUND
  )
)

(define-read-only (get-total-properties)
  (- (var-get next-property-id) u1)
)

(define-read-only (get-total-leases)
  (- (var-get next-lease-id) u1)
)

(define-read-only (is-property-available (property-id uint))
  (match (map-get? properties property-id)
    property (ok (get is-available property))
    ERR_PROPERTY_NOT_FOUND
  )
)

(define-read-only (get-lease-status (lease-id uint))
  (match (map-get? leases lease-id)
    lease (ok {
      is-active: (get is-active lease),
      blocks-remaining: (if (> (get end-block lease) stacks-block-height)
                         (- (get end-block lease) stacks-block-height)
                         u0),
      ownership-achieved: (>= (get accumulated-equity lease) (get ownership-threshold lease))
    })
    ERR_LEASE_NOT_FOUND
  )
)
