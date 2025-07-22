;; Smart City Data Governance Contract
;; Manages citizen data privacy in connected urban environments

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-DATA-SOURCE-EXISTS (err u201))
(define-constant ERR-DATA-SOURCE-NOT-FOUND (err u202))
(define-constant ERR-INVALID-PERMISSION (err u203))
(define-constant ERR-ACCESS-DENIED (err u204))
(define-constant ERR-INVALID-INPUT (err u205))

;; Data Variables
(define-data-var next-source-id uint u1)
(define-data-var privacy-officer principal CONTRACT-OWNER)

;; Data Maps
(define-map data-sources uint {
    name: (string-ascii 100),
    description: (string-ascii 300),
    data-type: (string-ascii 50),
    owner: principal,
    created-at: uint,
    privacy-level: uint,
    status: (string-ascii 20)
})

(define-map data-permissions {source-id: uint, accessor: principal} {
    permission-level: uint,
    granted-by: principal,
    granted-at: uint,
    expires-at: (optional uint),
    purpose: (string-ascii 200)
})

(define-map citizen-consents {citizen: principal, source-id: uint} {
    consented: bool,
    consent-date: uint,
    consent-type: (string-ascii 50),
    can-revoke: bool
})

(define-map data-access-logs {source-id: uint, accessor: principal, timestamp: uint} {
    access-type: (string-ascii 50),
    purpose: (string-ascii 200),
    data-hash: (string-ascii 64)
})

;; Public Functions

;; Register a new data source
(define-public (register-data-source (name (string-ascii 100)) (description (string-ascii 300)) (data-type (string-ascii 50)) (privacy-level uint))
    (let (
        (source-id (var-get next-source-id))
        (caller tx-sender)
    )
        (asserts! (> (len name) u0) ERR-INVALID-INPUT)
        (asserts! (<= privacy-level u5) ERR-INVALID-INPUT)

        (map-set data-sources source-id {
            name: name,
            description: description,
            data-type: data-type,
            owner: caller,
            created-at: block-height,
            privacy-level: privacy-level,
            status: "active"
        })

        (var-set next-source-id (+ source-id u1))
        (ok source-id)
    )
)

;; Grant data access permission
(define-public (grant-permission (source-id uint) (accessor principal) (permission-level uint) (expires-at (optional uint)) (purpose (string-ascii 200)))
    (let (
        (source (unwrap! (map-get? data-sources source-id) ERR-DATA-SOURCE-NOT-FOUND))
        (caller tx-sender)
    )
        (asserts! (or (is-eq caller (get owner source)) (is-eq caller (var-get privacy-officer))) ERR-NOT-AUTHORIZED)
        (asserts! (<= permission-level u3) ERR-INVALID-PERMISSION)

        (map-set data-permissions {source-id: source-id, accessor: accessor} {
            permission-level: permission-level,
            granted-by: caller,
            granted-at: block-height,
            expires-at: expires-at,
            purpose: purpose
        })
        (ok true)
    )
)

;; Citizen consent management
(define-public (give-consent (source-id uint) (consent-type (string-ascii 50)))
    (let (
        (caller tx-sender)
        (source (unwrap! (map-get? data-sources source-id) ERR-DATA-SOURCE-NOT-FOUND))
    )
        (map-set citizen-consents {citizen: caller, source-id: source-id} {
            consented: true,
            consent-date: block-height,
            consent-type: consent-type,
            can-revoke: true
        })
        (ok true)
    )
)

;; Revoke consent
(define-public (revoke-consent (source-id uint))
    (let (
        (caller tx-sender)
        (consent-key {citizen: caller, source-id: source-id})
        (consent (unwrap! (map-get? citizen-consents consent-key) ERR-DATA-SOURCE-NOT-FOUND))
    )
        (asserts! (get can-revoke consent) ERR-NOT-AUTHORIZED)

        (map-set citizen-consents consent-key (merge consent {
            consented: false,
            consent-date: block-height
        }))
        (ok true)
    )
)

;; Log data access
(define-public (log-data-access (source-id uint) (access-type (string-ascii 50)) (purpose (string-ascii 200)) (data-hash (string-ascii 64)))
    (let (
        (caller tx-sender)
        (source (unwrap! (map-get? data-sources source-id) ERR-DATA-SOURCE-NOT-FOUND))
        (permission (map-get? data-permissions {source-id: source-id, accessor: caller}))
    )
        (asserts! (is-some permission) ERR-ACCESS-DENIED)

        (let ((perm-data (unwrap-panic permission)))
            (asserts! (> (get permission-level perm-data) u0) ERR-ACCESS-DENIED)
            (asserts! (match (get expires-at perm-data)
                exp-time (< block-height exp-time)
                true
            ) ERR-ACCESS-DENIED)
        )

        (map-set data-access-logs {source-id: source-id, accessor: caller, timestamp: block-height} {
            access-type: access-type,
            purpose: purpose,
            data-hash: data-hash
        })
        (ok true)
    )
)

;; Update privacy officer
(define-public (set-privacy-officer (new-officer principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set privacy-officer new-officer)
        (ok true)
    )
)

;; Deactivate data source
(define-public (deactivate-data-source (source-id uint))
    (let (
        (source (unwrap! (map-get? data-sources source-id) ERR-DATA-SOURCE-NOT-FOUND))
        (caller tx-sender)
    )
        (asserts! (or (is-eq caller (get owner source)) (is-eq caller (var-get privacy-officer))) ERR-NOT-AUTHORIZED)

        (map-set data-sources source-id (merge source {status: "inactive"}))
        (ok true)
    )
)

;; Read-only Functions

;; Get data source information
(define-read-only (get-data-source (source-id uint))
    (map-get? data-sources source-id)
)

;; Get permission details
(define-read-only (get-permission (source-id uint) (accessor principal))
    (map-get? data-permissions {source-id: source-id, accessor: accessor})
)

;; Get citizen consent
(define-read-only (get-consent (citizen principal) (source-id uint))
    (map-get? citizen-consents {citizen: citizen, source-id: source-id})
)

;; Check if access is allowed
(define-read-only (is-access-allowed (source-id uint) (accessor principal))
    (match (map-get? data-permissions {source-id: source-id, accessor: accessor})
        permission (and
            (> (get permission-level permission) u0)
            (match (get expires-at permission)
                exp-time (< block-height exp-time)
                true
            )
        )
        false
    )
)

;; Get privacy officer
(define-read-only (get-privacy-officer)
    (var-get privacy-officer)
)

;; Get next source ID
(define-read-only (get-next-source-id)
    (var-get next-source-id)
)
