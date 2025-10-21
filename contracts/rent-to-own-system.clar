;; Rent-to-Own Smart Leasing System with Property Insurance Management
;; A comprehensive system enabling rent-to-own leasing with integrated property insurance

;; Error Constants
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
(define-constant ERR_DEPOSIT_ALREADY_PAID (err u11))
(define-constant ERR_DEPOSIT_NOT_FOUND (err u12))
(define-constant ERR_CLAIM_PERIOD_EXPIRED (err u13))
(define-constant ERR_INSUFFICIENT_DEPOSIT (err u14))
;; New Insurance Error Constants
(define-constant ERR_INSURANCE_NOT_FOUND (err u15))
(define-constant ERR_CLAIM_NOT_FOUND (err u16))
(define-constant ERR_POLICY_EXPIRED (err u17))
(define-constant ERR_INSUFFICIENT_COVERAGE (err u18))
(define-constant ERR_CLAIM_ALREADY_PROCESSED (err u19))
(define-constant ERR_PREMIUM_OVERDUE (err u20))

;; System Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant LATE_PENALTY_RATE u5)
(define-constant EARLY_EXIT_PENALTY_RATE u15)
(define-constant COMPLETION_BONUS_RATE u10)
(define-constant DAMAGE_CLAIM_WINDOW u1008)
;; New Insurance Constants
(define-constant INSURANCE_GRACE_PERIOD u144)
(define-constant MAX_CLAIM_PERCENTAGE u80)
(define-constant PREMIUM_CYCLE_BLOCKS u4032) ;; ~4 weeks

;; Data Variables
(define-data-var next-property-id uint u1)
(define-data-var next-lease-id uint u1)
(define-data-var next-insurance-policy-id uint u1)
(define-data-var next-insurance-claim-id uint u1)

;; Core System Maps
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

(define-map security-deposits 
  uint 
  {
    lease-id: uint,
    amount: uint,
    deposited-block: uint,
    is-claimed: bool,
    claim-amount: uint,
    claim-reason: (string-ascii 200),
    claim-block: uint
  }
)

;; Property Insurance System Maps
(define-map insurance-policies
  uint
  {
    property-id: uint,
    policy-holder: principal,
    coverage-amount: uint,
    premium-amount: uint,
    start-block: uint,
    end-block: uint,
    is-active: bool,
    last-premium-payment: uint,
    total-premiums-paid: uint
  }
)

(define-map insurance-claims
  uint
  {
    policy-id: uint,
    claimant: principal,
    claim-amount: uint,
    claim-reason: (string-ascii 200),
    claim-block: uint,
    is-processed: bool,
    approved-amount: uint,
    processing-block: uint
  }
)

(define-map premium-payments
  {policy-id: uint, payment-number: uint}
  {
    amount: uint,
    payment-block: uint,
    is-on-time: bool
  }
)

(define-map policy-payment-count uint uint)

;; Core Leasing Functions
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

;; Property Insurance Management Functions
(define-public (register-insurance-policy (property-id uint) (coverage-amount uint) (premium-amount uint) (policy-duration uint))
  (let 
    (
      (property (unwrap! (map-get? properties property-id) ERR_PROPERTY_NOT_FOUND))
      (policy-id (var-get next-insurance-policy-id))
      (current-block stacks-block-height)
      (end-block (+ current-block policy-duration))
    )
    (asserts! (is-eq tx-sender (get owner property)) ERR_NOT_AUTHORIZED)
    (asserts! (> coverage-amount u0) ERR_INVALID_PARAMS)
    (asserts! (> premium-amount u0) ERR_INVALID_PARAMS)
    (asserts! (> policy-duration u0) ERR_INVALID_PARAMS)
    (asserts! (<= coverage-amount (* (get value property) u2)) ERR_INVALID_PARAMS) ;; Max 200% of property value
    
    (map-set insurance-policies policy-id {
      property-id: property-id,
      policy-holder: tx-sender,
      coverage-amount: coverage-amount,
      premium-amount: premium-amount,
      start-block: current-block,
      end-block: end-block,
      is-active: true,
      last-premium-payment: current-block,
      total-premiums-paid: u0
    })
    (map-set policy-payment-count policy-id u0)
    (var-set next-insurance-policy-id (+ policy-id u1))
    (ok policy-id)
  )
)

(define-public (pay-insurance-premium (policy-id uint))
  (let 
    (
      (policy (unwrap! (map-get? insurance-policies policy-id) ERR_INSURANCE_NOT_FOUND))
      (current-block stacks-block-height)
      (payment-count (default-to u0 (map-get? policy-payment-count policy-id)))
      (new-payment-count (+ payment-count u1))
      (expected-payment-block (+ (get last-premium-payment policy) PREMIUM_CYCLE_BLOCKS))
      (is-late (> current-block (+ expected-payment-block INSURANCE_GRACE_PERIOD)))
      (premium-amount (get premium-amount policy))
    )
    (asserts! (get is-active policy) ERR_POLICY_EXPIRED)
    (asserts! (is-eq tx-sender (get policy-holder policy)) ERR_NOT_AUTHORIZED)
    (asserts! (<= current-block (get end-block policy)) ERR_POLICY_EXPIRED)
    
    ;; If payment is too late, deactivate policy
    (if is-late
      (begin
        (map-set insurance-policies policy-id (merge policy {is-active: false}))
        ERR_PREMIUM_OVERDUE
      )
      (begin
        (try! (stx-transfer? premium-amount tx-sender (as-contract tx-sender)))
        
        (map-set premium-payments {policy-id: policy-id, payment-number: new-payment-count} {
          amount: premium-amount,
          payment-block: current-block,
          is-on-time: true
        })
        
        (map-set policy-payment-count policy-id new-payment-count)
        
        (map-set insurance-policies policy-id (merge policy {
          last-premium-payment: current-block,
          total-premiums-paid: (+ (get total-premiums-paid policy) premium-amount)
        }))
        
        (ok premium-amount)
      )
    )
  )
)

(define-public (file-insurance-claim (policy-id uint) (claim-amount uint) (reason (string-ascii 200)))
  (let 
    (
      (policy (unwrap! (map-get? insurance-policies policy-id) ERR_INSURANCE_NOT_FOUND))
      (claim-id (var-get next-insurance-claim-id))
      (current-block stacks-block-height)
      (max-claimable (/ (* (get coverage-amount policy) MAX_CLAIM_PERCENTAGE) u100))
    )
    (asserts! (get is-active policy) ERR_POLICY_EXPIRED)
    (asserts! (is-eq tx-sender (get policy-holder policy)) ERR_NOT_AUTHORIZED)
    (asserts! (<= current-block (get end-block policy)) ERR_POLICY_EXPIRED)
    (asserts! (> claim-amount u0) ERR_INVALID_PARAMS)
    (asserts! (<= claim-amount max-claimable) ERR_INSUFFICIENT_COVERAGE)
    
    (map-set insurance-claims claim-id {
      policy-id: policy-id,
      claimant: tx-sender,
      claim-amount: claim-amount,
      claim-reason: reason,
      claim-block: current-block,
      is-processed: false,
      approved-amount: u0,
      processing-block: u0
    })
    (var-set next-insurance-claim-id (+ claim-id u1))
    (ok claim-id)
  )
)

(define-public (process-insurance-claim (claim-id uint) (approved-amount uint))
  (let 
    (
      (claim (unwrap! (map-get? insurance-claims claim-id) ERR_CLAIM_NOT_FOUND))
      (policy (unwrap! (map-get? insurance-policies (get policy-id claim)) ERR_INSURANCE_NOT_FOUND))
      (current-block stacks-block-height)
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED) ;; Only contract owner can process claims
    (asserts! (not (get is-processed claim)) ERR_CLAIM_ALREADY_PROCESSED)
    (asserts! (<= approved-amount (get claim-amount claim)) ERR_INVALID_PARAMS)
    
    (if (> approved-amount u0)
      (try! (as-contract (stx-transfer? approved-amount tx-sender (get claimant claim))))
      true)
    
    (map-set insurance-claims claim-id (merge claim {
      is-processed: true,
      approved-amount: approved-amount,
      processing-block: current-block
    }))
    
    (ok approved-amount)
  )
)

;; Helper Functions
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

;; Read-Only Functions
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

;; Insurance Read-Only Functions
(define-read-only (get-insurance-policy (policy-id uint))
  (map-get? insurance-policies policy-id)
)

(define-read-only (get-insurance-claim (claim-id uint))
  (map-get? insurance-claims claim-id)
)

(define-read-only (get-premium-payment (policy-id uint) (payment-number uint))
  (map-get? premium-payments {policy-id: policy-id, payment-number: payment-number})
)

(define-read-only (get-policy-status (policy-id uint))
  (match (map-get? insurance-policies policy-id)
    policy (let 
      (
        (current-block stacks-block-height)
        (next-premium-due (+ (get last-premium-payment policy) PREMIUM_CYCLE_BLOCKS))
        (is-premium-overdue (> current-block (+ next-premium-due INSURANCE_GRACE_PERIOD)))
      )
      (ok {
        is-active: (and (get is-active policy) (not is-premium-overdue)),
        coverage-amount: (get coverage-amount policy),
        next-premium-due: next-premium-due,
        blocks-until-premium-due: (if (> next-premium-due current-block) 
                                   (- next-premium-due current-block) 
                                   u0),
        is-premium-overdue: is-premium-overdue,
        expires-at-block: (get end-block policy)
      })
    )
    ERR_INSURANCE_NOT_FOUND
  )
)

(define-read-only (get-total-properties)
  (- (var-get next-property-id) u1)
)

(define-read-only (get-total-leases)
  (- (var-get next-lease-id) u1)
)

(define-read-only (get-total-insurance-policies)
  (- (var-get next-insurance-policy-id) u1)
)

(define-read-only (get-total-insurance-claims)
  (- (var-get next-insurance-claim-id) u1)
)
