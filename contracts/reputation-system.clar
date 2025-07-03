(define-map work-ratings
    { work-hash: (buff 32), rater: principal }
    {
        rating: uint,
        review: (string-utf8 200),
        timestamp: uint
    }
)

(define-map work-reputation
    { work-hash: (buff 32) }
    {
        total-ratings: uint,
        sum-ratings: uint,
        average-rating: uint,
        review-count: uint
    }
)

(define-map user-reputation
    { user: principal }
    {
        works-rated: uint,
        helpful-votes: uint,
        reputation-score: uint
    }
)

(define-map review-helpfulness
    { work-hash: (buff 32), rater: principal, voter: principal }
    { helpful: bool }
)

(define-public (rate-work (work-hash (buff 32)) (rating uint) (review (string-utf8 200)))
    (let (
        (existing-rating (map-get? work-ratings {work-hash: work-hash, rater: tx-sender}))
        (current-reputation (default-to 
            {total-ratings: u0, sum-ratings: u0, average-rating: u0, review-count: u0}
            (map-get? work-reputation {work-hash: work-hash})))
        (user-rep (default-to 
            {works-rated: u0, helpful-votes: u0, reputation-score: u0}
            (map-get? user-reputation {user: tx-sender})))
    )
        (if (and (<= rating u5) (> rating u0))
            (if (is-none existing-rating)
                (let (
                    (new-total (+ (get total-ratings current-reputation) u1))
                    (new-sum (+ (get sum-ratings current-reputation) rating))
                    (new-average (/ new-sum new-total))
                    (new-review-count (+ (get review-count current-reputation) u1))
                )
                    (begin
                        (map-set work-ratings
                            {work-hash: work-hash, rater: tx-sender}
                            {
                                rating: rating,
                                review: review,
                                timestamp: stacks-block-height
                            })
                        (map-set work-reputation
                            {work-hash: work-hash}
                            {
                                total-ratings: new-total,
                                sum-ratings: new-sum,
                                average-rating: new-average,
                                review-count: new-review-count
                            })
                        (map-set user-reputation
                            {user: tx-sender}
                            {
                                works-rated: (+ (get works-rated user-rep) u1),
                                helpful-votes: (get helpful-votes user-rep),
                                reputation-score: (+ (get reputation-score user-rep) u10)
                            })
                        (ok true)
                    )
                )
                (err u1)
            )
            (err u2)
        )
    )
)

(define-public (update-rating (work-hash (buff 32)) (new-rating uint) (new-review (string-utf8 200)))
    (let (
        (existing-rating (map-get? work-ratings {work-hash: work-hash, rater: tx-sender}))
        (current-reputation (unwrap-panic (map-get? work-reputation {work-hash: work-hash})))
    )
        (if (and 
                (is-some existing-rating) 
                (<= new-rating u5) 
                (> new-rating u0))
            (let (
                (old-rating (get rating (unwrap-panic existing-rating)))
                (new-sum (+ (- (get sum-ratings current-reputation) old-rating) new-rating))
                (new-average (/ new-sum (get total-ratings current-reputation)))
            )
                (begin
                    (map-set work-ratings
                        {work-hash: work-hash, rater: tx-sender}
                        {
                            rating: new-rating,
                            review: new-review,
                            timestamp: stacks-block-height
                        })
                    (map-set work-reputation
                        {work-hash: work-hash}
                        {
                            total-ratings: (get total-ratings current-reputation),
                            sum-ratings: new-sum,
                            average-rating: new-average,
                            review-count: (get review-count current-reputation)
                        })
                    (ok true)
                )
            )
            (err u3)
        )
    )
)

(define-public (vote-review-helpful (work-hash (buff 32)) (rater principal) (helpful bool))
    (let (
        (existing-vote (map-get? review-helpfulness {work-hash: work-hash, rater: rater, voter: tx-sender}))
        (rater-rep (default-to 
            {works-rated: u0, helpful-votes: u0, reputation-score: u0}
            (map-get? user-reputation {user: rater})))
    )
        (if (is-none existing-vote)
            (begin
                (map-set review-helpfulness
                    {work-hash: work-hash, rater: rater, voter: tx-sender}
                    {helpful: helpful})
                (if helpful
                    (begin
                        (map-set user-reputation
                            {user: rater}
                            {
                                works-rated: (get works-rated rater-rep),
                                helpful-votes: (+ (get helpful-votes rater-rep) u1),
                                reputation-score: (+ (get reputation-score rater-rep) u5)
                            })
                        (ok true)
                    )
                    (ok true)
                )
            )
            (err u4)
        )
    )
)

(define-public (remove-rating (work-hash (buff 32)))
    (let (
        (existing-rating (map-get? work-ratings {work-hash: work-hash, rater: tx-sender}))
        (current-reputation (unwrap-panic (map-get? work-reputation {work-hash: work-hash})))
    )
        (if (is-some existing-rating)
            (let (
                (rating-value (get rating (unwrap-panic existing-rating)))
                (new-total (- (get total-ratings current-reputation) u1))
                (new-sum (- (get sum-ratings current-reputation) rating-value))
                (new-average (if (> new-total u0) (/ new-sum new-total) u0))
                (new-review-count (- (get review-count current-reputation) u1))
            )
                (begin
                    (map-delete work-ratings {work-hash: work-hash, rater: tx-sender})
                    (map-set work-reputation
                        {work-hash: work-hash}
                        {
                            total-ratings: new-total,
                            sum-ratings: new-sum,
                            average-rating: new-average,
                            review-count: new-review-count
                        })
                    (ok true)
                )
            )
            (err u5)
        )
    )
)

(define-read-only (get-work-rating (work-hash (buff 32)) (rater principal))
    (map-get? work-ratings {work-hash: work-hash, rater: rater})
)

(define-read-only (get-work-reputation (work-hash (buff 32)))
    (map-get? work-reputation {work-hash: work-hash})
)

(define-read-only (get-user-reputation (user principal))
    (map-get? user-reputation {user: user})
)

(define-read-only (get-average-rating (work-hash (buff 32)))
    (let ((reputation (map-get? work-reputation {work-hash: work-hash})))
        (if (is-some reputation)
            (ok (get average-rating (unwrap-panic reputation)))
            (ok u0)
        )
    )
)

(define-read-only (get-total-reviews (work-hash (buff 32)))
    (let ((reputation (map-get? work-reputation {work-hash: work-hash})))
        (if (is-some reputation)
            (ok (get review-count (unwrap-panic reputation)))
            (ok u0)
        )
    )
)

(define-read-only (has-user-rated (work-hash (buff 32)) (user principal))
    (is-some (map-get? work-ratings {work-hash: work-hash, rater: user}))
)

(define-read-only (get-review-helpfulness (work-hash (buff 32)) (rater principal) (voter principal))
    (map-get? review-helpfulness {work-hash: work-hash, rater: rater, voter: voter})
)
