;; IP Analytics Dashboard Smart Contract
;; Provides comprehensive analytics and insights for intellectual property works

;; Analytics data structures
(define-map work-analytics
    { work-hash: (buff 32) }
    {
        total-interactions: uint,
        unique-viewers: uint,
        engagement-score: uint,
        trending-score: uint,
        first-tracked: uint,
        last-updated: uint
    }
)

;; Time-based performance metrics  
(define-map performance-metrics
    { work-hash: (buff 32), period: (string-utf8 10) }
    {
        views-count: uint,
        licenses-granted: uint,
        revenue-generated: uint,
        collaborators-added: uint,
        ratings-received: uint,
        period-start: uint,
        period-end: uint
    }
)

;; Comparative analytics between works
(define-map work-comparisons
    { work-hash-a: (buff 32), work-hash-b: (buff 32) }
    {
        similarity-score: uint,
        performance-ratio: uint,
        category-match: bool,
        comparison-date: uint
    }
)

;; User analytics profile
(define-map creator-analytics
    { creator: principal }
    {
        total-works: uint,
        avg-engagement: uint,
        top-category: (string-utf8 50),
        total-revenue: uint,
        success-rate: uint,
        most-active-period: (string-utf8 20)
    }
)

;; Market trend data
(define-map market-trends
    { category: (string-utf8 50), period: (string-utf8 10) }
    {
        total-works: uint,
        avg-price: uint,
        demand-score: uint,
        growth-rate: uint,
        top-performer: (buff 32)
    }
)

;; Real-time activity feed
(define-map activity-feed
    { work-hash: (buff 32), activity-id: uint }
    {
        activity-type: (string-utf8 30),
        actor: principal,
        timestamp: uint,
        impact-score: uint,
        metadata: (string-utf8 100)
    }
)

;; Data variables for analytics
(define-data-var next-activity-id uint u1)
(define-data-var analytics-update-interval uint u144) ;; ~1 day in blocks
(define-data-var trending-threshold uint u50)
(define-data-var high-engagement-threshold uint u100)

;; Update work analytics with new interaction
(define-public (record-interaction 
    (work-hash (buff 32)) 
    (interaction-type (string-utf8 30))
    (impact-weight uint))
    (let (
        (current-analytics (default-to 
            {total-interactions: u0, unique-viewers: u0, engagement-score: u0, 
             trending-score: u0, first-tracked: stacks-block-height, last-updated: stacks-block-height}
            (map-get? work-analytics {work-hash: work-hash})))
        (activity-id (var-get next-activity-id))
    )
        (begin
            ;; Update main analytics
            (map-set work-analytics
                {work-hash: work-hash}
                {
                    total-interactions: (+ (get total-interactions current-analytics) u1),
                    unique-viewers: (get unique-viewers current-analytics),
                    engagement-score: (+ (get engagement-score current-analytics) impact-weight),
                    trending-score: (calculate-trending-score work-hash),
                    first-tracked: (get first-tracked current-analytics),
                    last-updated: stacks-block-height
                })
            
            ;; Record activity in feed
            (map-set activity-feed
                {work-hash: work-hash, activity-id: activity-id}
                {
                    activity-type: interaction-type,
                    actor: tx-sender,
                    timestamp: stacks-block-height,
                    impact-score: impact-weight,
                    metadata: u""
                })
            
            (var-set next-activity-id (+ activity-id u1))
            (ok true)
        )
    )
)

;; Calculate trending score based on recent activity
(define-private (calculate-trending-score (work-hash (buff 32)))
    (let (
        (current-analytics (map-get? work-analytics {work-hash: work-hash}))
        (recent-blocks u144) ;; Last day
    )
        (if (is-some current-analytics)
            (let (
                (time-diff (- stacks-block-height (get last-updated (unwrap-panic current-analytics))))
                (engagement (get engagement-score (unwrap-panic current-analytics)))
                (interactions (get total-interactions (unwrap-panic current-analytics)))
            )
                (if (<= time-diff recent-blocks)
                    (/ (* engagement u10) (+ time-diff u1)) ;; Higher score for recent activity
                    (/ engagement u2) ;; Lower score for older activity
                )
            )
            u0
        )
    )
)

;; Update performance metrics for specific time periods
(define-public (update-period-metrics 
    (work-hash (buff 32)) 
    (period (string-utf8 10))
    (views uint)
    (licenses uint)
    (revenue uint))
    (let (
        (current-period (default-to 
            {views-count: u0, licenses-granted: u0, revenue-generated: u0,
             collaborators-added: u0, ratings-received: u0, 
             period-start: stacks-block-height, period-end: stacks-block-height}
            (map-get? performance-metrics {work-hash: work-hash, period: period})))
    )
        (map-set performance-metrics
            {work-hash: work-hash, period: period}
            {
                views-count: (+ (get views-count current-period) views),
                licenses-granted: (+ (get licenses-granted current-period) licenses),
                revenue-generated: (+ (get revenue-generated current-period) revenue),
                collaborators-added: (get collaborators-added current-period),
                ratings-received: (get ratings-received current-period),
                period-start: (get period-start current-period),
                period-end: stacks-block-height
            })
        (ok true)
    )
)

;; Compare performance between two works
(define-public (compare-works (work-hash-a (buff 32)) (work-hash-b (buff 32)))
    (let (
        (analytics-a (map-get? work-analytics {work-hash: work-hash-a}))
        (analytics-b (map-get? work-analytics {work-hash: work-hash-b}))
    )
        (if (and (is-some analytics-a) (is-some analytics-b))
            (let (
                (engagement-a (get engagement-score (unwrap-panic analytics-a)))
                (engagement-b (get engagement-score (unwrap-panic analytics-b)))
                (ratio (if (> engagement-b u0) (/ (* engagement-a u100) engagement-b) u0))
                (similarity (calculate-similarity work-hash-a work-hash-b))
            )
                (begin
                    (map-set work-comparisons
                        {work-hash-a: work-hash-a, work-hash-b: work-hash-b}
                        {
                            similarity-score: similarity,
                            performance-ratio: ratio,
                            category-match: (> similarity u70),
                            comparison-date: stacks-block-height
                        })
                    (ok ratio)
                )
            )
            (err u1) ;; One or both works not found
        )
    )
)

;; Calculate similarity between works (simplified version)
(define-private (calculate-similarity (work-a (buff 32)) (work-b (buff 32)))
    ;; Simplified similarity calculation
    ;; In reality, would compare categories, tags, performance patterns, etc.
    u75
)

;; Update creator analytics profile
(define-public (update-creator-profile (creator principal))
    (let (
        (current-profile (default-to 
            {total-works: u0, avg-engagement: u0, top-category: u"", 
             total-revenue: u0, success-rate: u0, most-active-period: u""}
            (map-get? creator-analytics {creator: creator})))
        ;; Calculate stats from actual data would go here
        (works-count (+ (get total-works current-profile) u1))
        (avg-engagement (get avg-engagement current-profile))
    )
        (map-set creator-analytics
            {creator: creator}
            {
                total-works: works-count,
                avg-engagement: avg-engagement,
                top-category: (get top-category current-profile),
                total-revenue: (get total-revenue current-profile),
                success-rate: (if (> works-count u0) (/ (* u100 works-count) works-count) u0),
                most-active-period: u"current"
            })
        (ok true)
    )
)

;; Get comprehensive dashboard data for a work
(define-read-only (get-work-dashboard (work-hash (buff 32)))
    (let (
        (analytics (map-get? work-analytics {work-hash: work-hash}))
        (current-period (map-get? performance-metrics {work-hash: work-hash, period: u"current"}))
    )
        {
            analytics: analytics,
            current-metrics: current-period,
            is-trending: (match analytics some-analytics 
                (>= (get trending-score some-analytics) (var-get trending-threshold)) 
                false),
            engagement-level: (match analytics some-analytics
                (if (>= (get engagement-score some-analytics) (var-get high-engagement-threshold))
                    u"high"
                    (if (>= (get engagement-score some-analytics) u25) u"medium" u"low"))
                u"none")
        }
    )
)

;; Get trending works across the platform
(define-read-only (get-trending-works)
    (ok (var-get trending-threshold)) ;; Simplified - would return actual trending works
)

;; Get creator performance summary
(define-read-only (get-creator-summary (creator principal))
    (map-get? creator-analytics {creator: creator})
)

;; Get recent activity for a work
(define-read-only (get-recent-activity (work-hash (buff 32)) (limit uint))
    ;; Simplified - would return recent activity items
    (ok limit)
)

;; Calculate market insights for a category
(define-public (calculate-market-insights 
    (category (string-utf8 50)) 
    (period (string-utf8 10)))
    (let (
        (current-trends (default-to 
            {total-works: u0, avg-price: u0, demand-score: u0, 
             growth-rate: u0, top-performer: 0x}
            (map-get? market-trends {category: category, period: period})))
    )
        (map-set market-trends
            {category: category, period: period}
            {
                total-works: (+ (get total-works current-trends) u1),
                avg-price: (get avg-price current-trends),
                demand-score: (+ (get demand-score current-trends) u10),
                growth-rate: u15, ;; Simplified calculation
                top-performer: (get top-performer current-trends)
            })
        (ok true)
    )
)

;; Read-only functions for analytics data
(define-read-only (get-work-analytics (work-hash (buff 32)))
    (map-get? work-analytics {work-hash: work-hash})
)

(define-read-only (get-performance-metrics (work-hash (buff 32)) (period (string-utf8 10)))
    (map-get? performance-metrics {work-hash: work-hash, period: period})
)

(define-read-only (get-work-comparison (work-a (buff 32)) (work-b (buff 32)))
    (map-get? work-comparisons {work-hash-a: work-a, work-hash-b: work-b})
)

(define-read-only (get-market-trends (category (string-utf8 50)) (period (string-utf8 10)))
    (map-get? market-trends {category: category, period: period})
)

(define-read-only (get-activity-item (work-hash (buff 32)) (activity-id uint))
    (map-get? activity-feed {work-hash: work-hash, activity-id: activity-id})
)
