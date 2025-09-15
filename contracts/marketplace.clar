;; IP Marketplace & Discovery System

;; Data structures for marketplace listings
(define-map marketplace-listings
    { work-hash: (buff 32) }
    {
        seller: principal,
        listing-type: (string-utf8 20), ;; "SALE", "LICENSE", "AUCTION"
        price: uint,
        currency: (string-utf8 10),
        description: (string-utf8 300),
        active: bool,
        listed-at: uint,
        expires-at: uint,
        featured: bool
    }
)

;; Track marketplace statistics
(define-map marketplace-stats
    { work-hash: (buff 32) }
    {
        total-views: uint,
        total-sales: uint,
        last-sale-price: uint,
        average-price: uint,
        bookmark-count: uint
    }
)

;; User marketplace preferences and activity
(define-map user-marketplace-profile
    { user: principal }
    {
        total-listings: uint,
        total-purchases: uint,
        preferred-categories: (list 5 (string-utf8 30)),
        seller-rating: uint,
        buyer-rating: uint,
        verified-seller: bool
    }
)

;; Search and discovery indexes
(define-map category-index
    { category: (string-utf8 30), work-hash: (buff 32) }
    {
        listing-score: uint,
        last-updated: uint
    }
)

;; Featured collections system
(define-map featured-collections
    { collection-id: uint }
    {
        curator: principal,
        title: (string-utf8 100),
        description: (string-utf8 300),
        works: (list 20 (buff 32)),
        active: bool,
        created-at: uint
    }
)

;; User bookmarks and watchlists
(define-map user-bookmarks
    { user: principal, work-hash: (buff 32) }
    {
        bookmarked-at: uint,
        notes: (string-utf8 200)
    }
)

;; Price history tracking
(define-map price-history
    { work-hash: (buff 32), sale-id: uint }
    {
        buyer: principal,
        seller: principal,
        price: uint,
        sale-type: (string-utf8 20),
        timestamp: uint
    }
)

;; Data variables
(define-data-var next-collection-id uint u1)
(define-data-var next-sale-id uint u1)
(define-data-var marketplace-fee-percentage uint u250) ;; 2.5%
(define-data-var featured-collection-fee uint u1000000) ;; 1 STX
(define-data-var max-listing-duration uint u52560) ;; ~1 year in blocks

;; Create marketplace listing
(define-public (create-listing 
    (work-hash (buff 32)) 
    (listing-type (string-utf8 20))
    (price uint)
    (currency (string-utf8 10))
    (description (string-utf8 300))
    (duration uint))
    (let (
        (existing-listing (map-get? marketplace-listings {work-hash: work-hash}))
        (user-profile (default-to 
            {total-listings: u0, total-purchases: u0, preferred-categories: (list), 
             seller-rating: u0, buyer-rating: u0, verified-seller: false}
            (map-get? user-marketplace-profile {user: tx-sender})))
        (safe-duration (if (<= duration (var-get max-listing-duration)) duration (var-get max-listing-duration)))
    )
        (if (is-none existing-listing)
            (begin
                (map-set marketplace-listings
                    {work-hash: work-hash}
                    {
                        seller: tx-sender,
                        listing-type: listing-type,
                        price: price,
                        currency: currency,
                        description: description,
                        active: true,
                        listed-at: stacks-block-height,
                        expires-at: (+ stacks-block-height safe-duration),
                        featured: false
                    })
                (map-set user-marketplace-profile
                    {user: tx-sender}
                    (merge user-profile {total-listings: (+ (get total-listings user-profile) u1)}))
                (unwrap-panic (update-marketplace-stats work-hash u0 u0))
                (ok true))
            (err u1) ;; Already listed
        )
    )
)

;; Update marketplace statistics
(define-private (update-marketplace-stats (work-hash (buff 32)) (sale-price uint) (increment-sales uint))
    (let (
        (current-stats (default-to 
            {total-views: u0, total-sales: u0, last-sale-price: u0, average-price: u0, bookmark-count: u0}
            (map-get? marketplace-stats {work-hash: work-hash})))
        (new-total-sales (+ (get total-sales current-stats) increment-sales))
        (new-average (if (> new-total-sales u0) 
            (/ (+ (* (get average-price current-stats) (get total-sales current-stats)) sale-price) new-total-sales)
            u0))
    )
        (map-set marketplace-stats
            {work-hash: work-hash}
            {
                total-views: (get total-views current-stats),
                total-sales: new-total-sales,
                last-sale-price: (if (> sale-price u0) sale-price (get last-sale-price current-stats)),
                average-price: new-average,
                bookmark-count: (get bookmark-count current-stats)
            })
        (ok true)
    )
)

;; Purchase from marketplace
(define-public (purchase-listing (work-hash (buff 32)))
    (let (
        (listing (map-get? marketplace-listings {work-hash: work-hash}))
        (buyer-profile (default-to 
            {total-listings: u0, total-purchases: u0, preferred-categories: (list), 
             seller-rating: u0, buyer-rating: u0, verified-seller: false}
            (map-get? user-marketplace-profile {user: tx-sender})))
        (sale-id (var-get next-sale-id))
    )
        (if (and (is-some listing) (get active (unwrap-panic listing)))
            (let (
                (seller (get seller (unwrap-panic listing)))
                (price (get price (unwrap-panic listing)))
                (marketplace-fee (/ (* price (var-get marketplace-fee-percentage)) u10000))
                (seller-amount (- price marketplace-fee))
            )
                (if (> stacks-block-height (get expires-at (unwrap-panic listing)))
                    (err u3) ;; Listing expired
                    (begin
                        (try! (stx-transfer? price tx-sender seller))
                        (map-set marketplace-listings
                            {work-hash: work-hash}
                            (merge (unwrap-panic listing) {active: false}))
                        (map-set user-marketplace-profile
                            {user: tx-sender}
                            (merge buyer-profile {total-purchases: (+ (get total-purchases buyer-profile) u1)}))
                        (map-set price-history
                            {work-hash: work-hash, sale-id: sale-id}
                            {
                                buyer: tx-sender,
                                seller: seller,
                                price: price,
                                sale-type: (get listing-type (unwrap-panic listing)),
                                timestamp: stacks-block-height
                            })
                        (var-set next-sale-id (+ sale-id u1))
                        (unwrap-panic (update-marketplace-stats work-hash price u1))
                        (ok sale-id)
                    )
                )
            )
            (err u2) ;; Listing not found or inactive
        )
    )
)

;; Add work to featured collection
(define-public (create-featured-collection 
    (title (string-utf8 100))
    (description (string-utf8 300))
    (works (list 20 (buff 32))))
    (let (
        (collection-id (var-get next-collection-id))
        (fee (var-get featured-collection-fee))
    )
        (begin
            (try! (stx-transfer? fee tx-sender (as-contract tx-sender)))
            (map-set featured-collections
                {collection-id: collection-id}
                {
                    curator: tx-sender,
                    title: title,
                    description: description,
                    works: works,
                    active: true,
                    created-at: stacks-block-height
                })
            (var-set next-collection-id (+ collection-id u1))
            (ok collection-id)
        )
    )
)

;; Bookmark system
(define-public (bookmark-work (work-hash (buff 32)) (notes (string-utf8 200)))
    (let (
        (existing-bookmark (map-get? user-bookmarks {user: tx-sender, work-hash: work-hash}))
        (current-stats (default-to 
            {total-views: u0, total-sales: u0, last-sale-price: u0, average-price: u0, bookmark-count: u0}
            (map-get? marketplace-stats {work-hash: work-hash})))
    )
        (if (is-none existing-bookmark)
            (begin
                (map-set user-bookmarks
                    {user: tx-sender, work-hash: work-hash}
                    {
                        bookmarked-at: stacks-block-height,
                        notes: notes
                    })
                (map-set marketplace-stats
                    {work-hash: work-hash}
                    (merge current-stats {bookmark-count: (+ (get bookmark-count current-stats) u1)}))
                (ok true))
            (err u4) ;; Already bookmarked
        )
    )
)

;; Remove bookmark
(define-public (remove-bookmark (work-hash (buff 32)))
    (let (
        (existing-bookmark (map-get? user-bookmarks {user: tx-sender, work-hash: work-hash}))
        (current-stats (default-to 
            {total-views: u0, total-sales: u0, last-sale-price: u0, average-price: u0, bookmark-count: u0}
            (map-get? marketplace-stats {work-hash: work-hash})))
    )
        (if (is-some existing-bookmark)
            (begin
                (map-delete user-bookmarks {user: tx-sender, work-hash: work-hash})
                (map-set marketplace-stats
                    {work-hash: work-hash}
                    (merge current-stats 
                        {bookmark-count: (if (> (get bookmark-count current-stats) u0) 
                                          (- (get bookmark-count current-stats) u1) u0)}))
                (ok true))
            (err u5) ;; Bookmark not found
        )
    )
)

;; Track marketplace views
(define-public (record-view (work-hash (buff 32)))
    (let (
        (current-stats (default-to 
            {total-views: u0, total-sales: u0, last-sale-price: u0, average-price: u0, bookmark-count: u0}
            (map-get? marketplace-stats {work-hash: work-hash})))
    )
        (map-set marketplace-stats
            {work-hash: work-hash}
            (merge current-stats {total-views: (+ (get total-views current-stats) u1)}))
        (ok true)
    )
)

;; Update listing price
(define-public (update-listing-price (work-hash (buff 32)) (new-price uint))
    (let ((listing (map-get? marketplace-listings {work-hash: work-hash})))
        (if (and 
                (is-some listing) 
                (is-eq (get seller (unwrap-panic listing)) tx-sender)
                (get active (unwrap-panic listing)))
            (begin
                (map-set marketplace-listings
                    {work-hash: work-hash}
                    (merge (unwrap-panic listing) {price: new-price}))
                (ok true))
            (err u6) ;; Not authorized or listing not found
        )
    )
)

;; Deactivate listing
(define-public (deactivate-listing (work-hash (buff 32)))
    (let ((listing (map-get? marketplace-listings {work-hash: work-hash})))
        (if (and 
                (is-some listing) 
                (is-eq (get seller (unwrap-panic listing)) tx-sender))
            (begin
                (map-set marketplace-listings
                    {work-hash: work-hash}
                    (merge (unwrap-panic listing) {active: false}))
                (ok true))
            (err u7) ;; Not authorized or listing not found
        )
    )
)

;; Set user marketplace preferences
(define-public (set-marketplace-preferences (categories (list 5 (string-utf8 30))))
    (let (
        (current-profile (default-to 
            {total-listings: u0, total-purchases: u0, preferred-categories: (list), 
             seller-rating: u0, buyer-rating: u0, verified-seller: false}
            (map-get? user-marketplace-profile {user: tx-sender})))
    )
        (map-set user-marketplace-profile
            {user: tx-sender}
            (merge current-profile {preferred-categories: categories}))
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-listing (work-hash (buff 32)))
    (map-get? marketplace-listings {work-hash: work-hash})
)

(define-read-only (get-marketplace-stats (work-hash (buff 32)))
    (map-get? marketplace-stats {work-hash: work-hash})
)

(define-read-only (get-user-profile (user principal))
    (map-get? user-marketplace-profile {user: user})
)

(define-read-only (get-featured-collection (collection-id uint))
    (map-get? featured-collections {collection-id: collection-id})
)

(define-read-only (get-user-bookmark (user principal) (work-hash (buff 32)))
    (map-get? user-bookmarks {user: user, work-hash: work-hash})
)

(define-read-only (get-price-history (work-hash (buff 32)) (sale-id uint))
    (map-get? price-history {work-hash: work-hash, sale-id: sale-id})
)

(define-read-only (is-listing-active (work-hash (buff 32)))
    (let ((listing (map-get? marketplace-listings {work-hash: work-hash})))
        (if (is-some listing)
            (and 
                (get active (unwrap-panic listing))
                (<= stacks-block-height (get expires-at (unwrap-panic listing))))
            false
        )
    )
)

(define-read-only (get-marketplace-fee-percentage)
    (var-get marketplace-fee-percentage)
)

(define-read-only (calculate-marketplace-fee (price uint))
    (/ (* price (var-get marketplace-fee-percentage)) u10000)
)

(define-read-only (get-next-collection-id)
    (var-get next-collection-id)
)

(define-read-only (get-listing-count-by-seller (seller principal))
    (let ((profile (map-get? user-marketplace-profile {user: seller})))
        (if (is-some profile)
            (get total-listings (unwrap-panic profile))
            u0
        )
    )
)

