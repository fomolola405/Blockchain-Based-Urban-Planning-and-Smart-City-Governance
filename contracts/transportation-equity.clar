;; Transportation Equity Planning Contract
;; Ensures public transit serves all communities fairly

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-ROUTE-NOT-FOUND (err u501))
(define-constant ERR-COMMUNITY-NOT-FOUND (err u502))
(define-constant ERR-INVALID-SCORE (err u503))
(define-constant ERR-ALREADY-EXISTS (err u504))
(define-constant ERR-INVALID-INPUT (err u505))

;; Data Variables
(define-data-var next-route-id uint u1)
(define-data-var next-community-id uint u1)
(define-data-var transit-authority principal CONTRACT-OWNER)
(define-data-var equity-threshold uint u70) ;; Minimum equity score

;; Data Maps
(define-map communities uint {
    name: (string-ascii 100),
    population: uint,
    median-income: uint,
    accessibility-score: uint,
    transit-routes: uint,
    created-at: uint,
    priority-level: uint
})

(define-map transit-routes uint {
    name: (string-ascii 100),
    route-type: (string-ascii 50),
    communities-served: uint,
    frequency: uint,
    accessibility-features: uint,
    operational-status: (string-ascii 20),
    created-at: uint,
    last-updated: uint
})

(define-map community-transit-access {community-id: uint, route-id: uint} {
    access-quality: uint,
    travel-time-to-center: uint,
    service-frequency: uint,
    accessibility-rating: uint,
    last-assessed: uint
})

(define-map equity-assessments {community-id: uint, assessment-date: uint} {
    overall-score: uint,
    access-score: uint,
    affordability-score: uint,
    reliability-score: uint,
    assessor: principal,
    recommendations: (string-ascii 500)
})

(define-map improvement-projects uint {
    title: (string-ascii 100),
    description: (string-ascii 300),
    target-communities: uint,
    budget: uint,
    timeline: uint,
    status: (string-ascii 20),
    equity-impact: uint
})

;; Public Functions

;; Register a community
(define-public (register-community (name (string-ascii 100)) (population uint) (median-income uint) (priority-level uint))
    (let (
        (community-id (var-get next-community-id))
        (caller tx-sender)
    )
        (asserts! (is-eq caller (var-get transit-authority)) ERR-NOT-AUTHORIZED)
        (asserts! (> (len name) u0) ERR-INVALID-INPUT)
        (asserts! (> population u0) ERR-INVALID-INPUT)
        (asserts! (<= priority-level u5) ERR-INVALID-INPUT)

        (map-set communities community-id {
            name: name,
            population: population,
            median-income: median-income,
            accessibility-score: u0,
            transit-routes: u0,
            created-at: block-height,
            priority-level: priority-level
        })

        (var-set next-community-id (+ community-id u1))
        (ok community-id)
    )
)

;; Create transit route
(define-public (create-transit-route (name (string-ascii 100)) (route-type (string-ascii 50)) (frequency uint) (accessibility-features uint))
    (let (
        (route-id (var-get next-route-id))
        (caller tx-sender)
    )
        (asserts! (is-eq caller (var-get transit-authority)) ERR-NOT-AUTHORIZED)
        (asserts! (> (len name) u0) ERR-INVALID-INPUT)
        (asserts! (> frequency u0) ERR-INVALID-INPUT)

        (map-set transit-routes route-id {
            name: name,
            route-type: route-type,
            communities-served: u0,
            frequency: frequency,
            accessibility-features: accessibility-features,
            operational-status: "planning",
            created-at: block-height,
            last-updated: block-height
        })

        (var-set next-route-id (+ route-id u1))
        (ok route-id)
    )
)

;; Assess community transit access
(define-public (assess-transit-access (community-id uint) (route-id uint) (access-quality uint) (travel-time uint) (service-frequency uint) (accessibility-rating uint))
    (let (
        (community (unwrap! (map-get? communities community-id) ERR-COMMUNITY-NOT-FOUND))
        (route (unwrap! (map-get? transit-routes route-id) ERR-ROUTE-NOT-FOUND))
        (caller tx-sender)
    )
        (asserts! (is-eq caller (var-get transit-authority)) ERR-NOT-AUTHORIZED)
        (asserts! (and (<= access-quality u100) (<= accessibility-rating u100)) ERR-INVALID-SCORE)

        (map-set community-transit-access {community-id: community-id, route-id: route-id} {
            access-quality: access-quality,
            travel-time-to-center: travel-time,
            service-frequency: service-frequency,
            accessibility-rating: accessibility-rating,
            last-assessed: block-height
        })

        ;; Update community accessibility score
        (let ((new-score (calculate-community-accessibility community-id)))
            (map-set communities community-id (merge community {
                accessibility-score: new-score,
                transit-routes: (+ (get transit-routes community) u1)
            }))
        )
        (ok true)
    )
)

;; Conduct equity assessment
(define-public (conduct-equity-assessment (community-id uint) (access-score uint) (affordability-score uint) (reliability-score uint) (recommendations (string-ascii 500)))
    (let (
        (community (unwrap! (map-get? communities community-id) ERR-COMMUNITY-NOT-FOUND))
        (caller tx-sender)
        (overall-score (calculate-overall-equity-score access-score affordability-score reliability-score))
    )
        (asserts! (is-eq caller (var-get transit-authority)) ERR-NOT-AUTHORIZED)
        (asserts! (and (<= access-score u100) (<= affordability-score u100) (<= reliability-score u100)) ERR-INVALID-SCORE)

        (map-set equity-assessments {community-id: community-id, assessment-date: block-height} {
            overall-score: overall-score,
            access-score: access-score,
            affordability-score: affordability-score,
            reliability-score: reliability-score,
            assessor: caller,
            recommendations: recommendations
        })
        (ok overall-score)
    )
)

;; Create improvement project
(define-public (create-improvement-project (title (string-ascii 100)) (description (string-ascii 300)) (target-communities uint) (budget uint) (timeline uint) (equity-impact uint))
    (let (
        (project-id (var-get next-route-id)) ;; Reusing counter for simplicity
        (caller tx-sender)
    )
        (asserts! (is-eq caller (var-get transit-authority)) ERR-NOT-AUTHORIZED)
        (asserts! (> (len title) u0) ERR-INVALID-INPUT)
        (asserts! (> budget u0) ERR-INVALID-INPUT)
        (asserts! (<= equity-impact u100) ERR-INVALID-SCORE)

        (map-set improvement-projects project-id {
            title: title,
            description: description,
            target-communities: target-communities,
            budget: budget,
            timeline: timeline,
            status: "proposed",
            equity-impact: equity-impact
        })
        (ok project-id)
    )
)

;; Update route operational status
(define-public (update-route-status (route-id uint) (new-status (string-ascii 20)))
    (let (
        (route (unwrap! (map-get? transit-routes route-id) ERR-ROUTE-NOT-FOUND))
        (caller tx-sender)
    )
        (asserts! (is-eq caller (var-get transit-authority)) ERR-NOT-AUTHORIZED)

        (map-set transit-routes route-id (merge route {
            operational-status: new-status,
            last-updated: block-height
        }))
        (ok true)
    )
)

;; Set transit authority
(define-public (set-transit-authority (new-authority principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set transit-authority new-authority)
        (ok true)
    )
)

;; Set equity threshold
(define-public (set-equity-threshold (threshold uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (<= threshold u100) ERR-INVALID-SCORE)

        (var-set equity-threshold threshold)
        (ok true)
    )
)

;; Private Functions

;; Calculate community accessibility score
(define-private (calculate-community-accessibility (community-id uint))
    u75  ;; Simplified calculation - would aggregate all route access scores
)

;; Calculate overall equity score
(define-private (calculate-overall-equity-score (access uint) (affordability uint) (reliability uint))
    (/ (+ (+ access affordability) reliability) u3)
)

;; Read-only Functions

;; Get community information
(define-read-only (get-community (community-id uint))
    (map-get? communities community-id)
)

;; Get transit route details
(define-read-only (get-transit-route (route-id uint))
    (map-get? transit-routes route-id)
)

;; Get transit access information
(define-read-only (get-transit-access (community-id uint) (route-id uint))
    (map-get? community-transit-access {community-id: community-id, route-id: route-id})
)

;; Get equity assessment
(define-read-only (get-equity-assessment (community-id uint) (assessment-date uint))
    (map-get? equity-assessments {community-id: community-id, assessment-date: assessment-date})
)

;; Get improvement project
(define-read-only (get-improvement-project (project-id uint))
    (map-get? improvement-projects project-id)
)

;; Get transit authority
(define-read-only (get-transit-authority)
    (var-get transit-authority)
)

;; Get equity threshold
(define-read-only (get-equity-threshold)
    (var-get equity-threshold)
)

;; Check if community meets equity standards
(define-read-only (meets-equity-standards (community-id uint))
    (match (map-get? communities community-id)
        community (>= (get accessibility-score community) (var-get equity-threshold))
        false
    )
)

;; Get communities needing improvement
(define-read-only (needs-improvement (community-id uint))
    (match (map-get? communities community-id)
        community (< (get accessibility-score community) (var-get equity-threshold))
        false
    )
)

;; Calculate equity gap
(define-read-only (get-equity-gap (community-id uint))
    (match (map-get? communities community-id)
        community (let ((current-score (get accessibility-score community)))
            (if (< current-score (var-get equity-threshold))
                (- (var-get equity-threshold) current-score)
                u0
            )
        )
        u0
    )
)
