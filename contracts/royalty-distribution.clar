(define-map royalty-pools
    { work-hash: (buff 32) }
    {
        total-collected: uint,
        total-distributed: uint,
        active: bool
    }
)

(define-map participant-balances
    { work-hash: (buff 32), participant: principal }
    {
        earned: uint,
        withdrawn: uint
    }
)

(define-map payment-history
    { work-hash: (buff 32), payment-id: uint }
    {
        payer: principal,
        amount: uint,
        timestamp: uint,
        distributed: bool
    }
)

(define-data-var next-payment-id uint u1)

(define-public (pay-for-usage (work-hash (buff 32)) (amount uint))
    (let (
        (payment-id (var-get next-payment-id))
        (pool (default-to {total-collected: u0, total-distributed: u0, active: true} 
                         (map-get? royalty-pools {work-hash: work-hash})))
    )
        (begin
            (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
            (map-set payment-history
                {work-hash: work-hash, payment-id: payment-id}
                {
                    payer: tx-sender,
                    amount: amount,
                    timestamp: stacks-block-height,
                    distributed: false
                })
            (map-set royalty-pools
                {work-hash: work-hash}
                {
                    total-collected: (+ (get total-collected pool) amount),
                    total-distributed: (get total-distributed pool),
                    active: true
                })
            (var-set next-payment-id (+ payment-id u1))
            ;; (try! (distribute-payment work-hash payment-id amount))
            (ok payment-id)
        )
    )
)

(define-private (distribute-payment (work-hash (buff 32)) (payment-id uint) (total-amount uint))
    (let (
        (owner-share (calculate-owner-share work-hash total-amount))
        (participants (get-all-participants work-hash))
    )
        (begin
            ;; (try! (distribute-to-owner work-hash owner-share))
            ;; (try! (distribute-to-participants work-hash participants total-amount))
            (map-set payment-history
                {work-hash: work-hash, payment-id: payment-id}
                (merge (unwrap-panic (map-get? payment-history {work-hash: work-hash, payment-id: payment-id}))
                       {distributed: true}))
            (ok true)
        )
    )
)

(define-private (calculate-owner-share (work-hash (buff 32)) (total-amount uint))
    (let ((total-participant-percentage (get-total-participant-percentage work-hash)))
        (if (>= total-participant-percentage u100)
            u0
            (/ (* total-amount (- u100 total-participant-percentage)) u100)
        )
    )
)

(define-private (get-total-participant-percentage (work-hash (buff 32)))
    u0
)

(define-private (get-all-participants (work-hash (buff 32)))
    (list)
)

(define-private (distribute-to-owner (work-hash (buff 32)) (amount uint))
    (if (> amount u0)
        (let ((current-balance (default-to {earned: u0, withdrawn: u0}
                                         (map-get? participant-balances {work-hash: work-hash, participant: tx-sender}))))
            (begin
                (map-set participant-balances
                    {work-hash: work-hash, participant: tx-sender}
                    {
                        earned: (+ (get earned current-balance) amount),
                        withdrawn: (get withdrawn current-balance)
                    })
                (ok true)
            )
        )
        (ok true)
    )
)

(define-private (distribute-to-participants (work-hash (buff 32)) (participants (list 10 principal)) (total-amount uint))
    (ok true)
)

(define-public (distribute-to-participant (work-hash (buff 32)) (participant principal) (total-amount uint))
    (let (
        (revenue-share (map-get? revenue-shares {hash: work-hash, participant: participant}))
        (current-balance (default-to {earned: u0, withdrawn: u0}
                                   (map-get? participant-balances {work-hash: work-hash, participant: participant})))
    )
        (if (is-some revenue-share)
            (let (
                (share-percentage (get percentage (unwrap-panic revenue-share)))
                (participant-amount (/ (* total-amount share-percentage) u100))
            )
                (begin
                    (map-set participant-balances
                        {work-hash: work-hash, participant: participant}
                        {
                            earned: (+ (get earned current-balance) participant-amount),
                            withdrawn: (get withdrawn current-balance)
                        })
                    (map-set revenue-shares
                        {hash: work-hash, participant: participant}
                        (merge (unwrap-panic revenue-share)
                               {total-received: (+ (get total-received (unwrap-panic revenue-share)) participant-amount)}))
                    (ok true)
                )
            )
            (ok true)
        )
    )
)

(define-public (withdraw-earnings (work-hash (buff 32)))
    (let (
        (balance (map-get? participant-balances {work-hash: work-hash, participant: tx-sender}))
    )
        (if (is-some balance)
            (let (
                (available (- (get earned (unwrap-panic balance)) (get withdrawn (unwrap-panic balance))))
            )
                (if (> available u0)
                    (begin
                        (try! (as-contract (stx-transfer? available tx-sender tx-sender)))
                        (map-set participant-balances
                            {work-hash: work-hash, participant: tx-sender}
                            {
                                earned: (get earned (unwrap-panic balance)),
                                withdrawn: (+ (get withdrawn (unwrap-panic balance)) available)
                            })
                        (ok available)
                    )
                    (err u400)
                )
            )
            (err u401)
        )
    )
)


(define-private (distribute-single-participant (data {participant: principal, work-hash: (buff 32), amount: uint}))
    (distribute-to-participant (get work-hash data) (get participant data) (get amount data))
)

(define-read-only (get-participant-balance (work-hash (buff 32)) (participant principal))
    (map-get? participant-balances {work-hash: work-hash, participant: participant})
)

(define-read-only (get-available-balance (work-hash (buff 32)) (participant principal))
    (let ((balance (map-get? participant-balances {work-hash: work-hash, participant: participant})))
        (if (is-some balance)
            (ok (- (get earned (unwrap-panic balance)) (get withdrawn (unwrap-panic balance))))
            (ok u0)
        )
    )
)

(define-read-only (get-royalty-pool (work-hash (buff 32)))
    (map-get? royalty-pools {work-hash: work-hash})
)

(define-read-only (get-payment-details (work-hash (buff 32)) (payment-id uint))
    (map-get? payment-history {work-hash: work-hash, payment-id: payment-id})
)

(define-read-only (get-total-earnings (work-hash (buff 32)))
    (let ((pool (map-get? royalty-pools {work-hash: work-hash})))
        (if (is-some pool)
            (ok (get total-collected (unwrap-panic pool)))
            (ok u0)
        )
    )
)

(define-map revenue-shares
    { hash: (buff 32), participant: principal }
    {
        percentage: uint,
        total-received: uint
    }
)