;; IP Protection Smart Contract

;; Data Maps
(define-map ip-registry 
    { hash: (buff 32) }  ;; SHA256 hash of the work
    { 
        owner: principal,
        timestamp: uint,
        title: (string-utf8 100),
        description: (string-utf8 500)
    }
)

;; Public Functions
(define-public (register-work (hash (buff 32)) (title (string-utf8 100)) (description (string-utf8 500)))
    (let ((existing-registration (map-get? ip-registry {hash: hash})))
        (if (is-some existing-registration)
            (err u1) ;; Work already registered
            (begin
                (map-set ip-registry 
                    {hash: hash}
                    {
                        owner: tx-sender,
                        timestamp: stacks-block-height,
                        title: title,
                        description: description
                    }
                )
                (ok true)
            )
        )
    )
)

;; Read Only Functions
(define-read-only (get-work-details (hash (buff 32)))
    (map-get? ip-registry {hash: hash})
)

(define-read-only (verify-ownership (hash (buff 32)) (owner principal))
    (let ((registration (map-get? ip-registry {hash: hash})))
        (if (and
                (is-some registration)
                (is-eq (get owner (unwrap-panic registration)) owner)
            )
            (ok true)
            (err u2)
        )
    )
)

(define-public (transfer-ownership (hash (buff 32)) (new-owner principal))
    (let ((registration (map-get? ip-registry {hash: hash})))
        (if (and 
                (is-some registration)
                (is-eq (get owner (unwrap-panic registration)) tx-sender))
            (begin 
                (map-set ip-registry 
                    {hash: hash}
                    (merge (unwrap-panic registration) {owner: new-owner}))
                (ok true))
            (err u3)
        )
    )
)

(define-map version-registry
    { hash: (buff 32), version: uint }
    { 
        updated-hash: (buff 32),
        update-notes: (string-utf8 200),
        timestamp: uint
    }
)

(define-public (register-new-version 
    (original-hash (buff 32)) 
    (new-hash (buff 32)) 
    (version uint)
    (notes (string-utf8 200)))
    (let ((original-work (map-get? ip-registry {hash: original-hash})))
        (if (and 
                (is-some original-work)
                (is-eq (get owner (unwrap-panic original-work)) tx-sender))
            (begin
                (map-set version-registry
                    {hash: original-hash, version: version}
                    {
                        updated-hash: new-hash,
                        update-notes: notes,
                        timestamp: stacks-block-height
                    })
                (ok true))
            (err u4)
        )
    )
)

(define-map licenses
    { work-hash: (buff 32), licensee: principal }
    {
        expiry: uint,
        terms: (string-utf8 200),
        active: bool
    }
)

(define-public (grant-license 
    (hash (buff 32)) 
    (licensee principal)
    (duration uint)
    (terms (string-utf8 200)))
    (let ((work (map-get? ip-registry {hash: hash})))
        (if (and
                (is-some work)
                (is-eq (get owner (unwrap-panic work)) tx-sender))
            (begin
                (map-set licenses
                    {work-hash: hash, licensee: licensee}
                    {
                        expiry: (+ stacks-block-height duration),
                        terms: terms,
                        active: true
                    })
                (ok true))
            (err u5)
        )
    )
)

(define-map work-categories
    { hash: (buff 32) }
    { 
        category: (string-utf8 50),
        tags: (list 10 (string-utf8 20))
    }
)

(define-public (add-work-category
    (hash (buff 32))
    (category (string-utf8 50))
    (tags (list 10 (string-utf8 20))))
    (let ((work (map-get? ip-registry {hash: hash})))
        (if (and
                (is-some work)
                (is-eq (get owner (unwrap-panic work)) tx-sender))
            (begin
                (map-set work-categories
                    {hash: hash}
                    {category: category, tags: tags})
                (ok true))
            (err u6)
        )
    )
)

(define-map collaborators
    { hash: (buff 32), collaborator: principal }
    {
        role: (string-utf8 50),
        permissions: (list 5 (string-utf8 20)),
        added-at: uint
    }
)

(define-public (add-collaborator
    (hash (buff 32))
    (collaborator principal)
    (role (string-utf8 50))
    (permissions (list 5 (string-utf8 20))))
    (let ((work (map-get? ip-registry {hash: hash})))
        (if (and
                (is-some work)
                (is-eq (get owner (unwrap-panic work)) tx-sender))
            (begin
                (map-set collaborators
                    {hash: hash, collaborator: collaborator}
                    {
                        role: role,
                        permissions: permissions,
                        added-at: stacks-block-height
                    })
                (ok true))
            (err u7)
        )
    )
)

(define-map work-status
    { hash: (buff 32) }
    {
        status: (string-utf8 20),
        visibility: bool,
        last-updated: uint
    }
)

(define-public (update-work-status
    (hash (buff 32))
    (status (string-utf8 20))
    (visibility bool))
    (let ((work (map-get? ip-registry {hash: hash})))
        (if (and
                (is-some work)
                (is-eq (get owner (unwrap-panic work)) tx-sender))
            (begin
                (map-set work-status
                    {hash: hash}
                    {
                        status: status,
                        visibility: visibility,
                        last-updated: stacks-block-height
                    })
                (ok true))
            (err u8)
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

(define-public (set-revenue-share
    (hash (buff 32))
    (participant principal)
    (share-percentage uint))
    (let ((work (map-get? ip-registry {hash: hash})))
        (if (and
                (is-some work)
                (is-eq (get owner (unwrap-panic work)) tx-sender)
                (<= share-percentage u100))
            (begin
                (map-set revenue-shares
                    {hash: hash, participant: participant}
                    {
                        percentage: share-percentage,
                        total-received: u0
                    })
                (ok true))
            (err u9)
        )
    )
)



(define-public (update-work-metadata (hash (buff 32)) (new-title (string-utf8 100)) (new-description (string-utf8 500)))
    (let ((reg (map-get? ip-registry {hash: hash})))
      (if (and 
            (is-some reg)
            (is-eq (get owner (unwrap-panic reg)) tx-sender))
          (begin
             (map-set ip-registry 
                {hash: hash}
                {
                  owner: (get owner (unwrap-panic reg)),
                  timestamp: (get timestamp (unwrap-panic reg)),
                  title: new-title,
                  description: new-description
                })
             (ok true))
          (err u11)
      )
    )
)

(define-public (remove-collaborator (hash (buff 32)) (collaborator principal))
    (let ((work (map-get? ip-registry {hash: hash})))
      (if (and 
            (is-some work)
            (is-eq (get owner (unwrap-panic work)) tx-sender))
          (begin
             (map-delete collaborators {hash: hash, collaborator: collaborator})
             (ok true))
          (err u12)
      )
    )
)

(define-public (extend-license (hash (buff 32)) (licensee principal) (additional-duration uint))
    (let (
          (work (map-get? ip-registry {hash: hash}))
          (license (map-get? licenses {work-hash: hash, licensee: licensee}))
         )
      (if (and 
            (is-some work)
            (is-eq (get owner (unwrap-panic work)) tx-sender)
            (is-some license))
          (begin
             (let ((old-expiry (get expiry (unwrap-panic license))))
                  (map-set licenses 
                    {work-hash: hash, licensee: licensee}
                    {
                      expiry: (+ old-expiry additional-duration),
                      terms: (get terms (unwrap-panic license)),
                      active: true
                    }
                  )
             )
             (ok true))
          (err u13)
      )
    )
)

(define-public (cancel-revenue-share (hash (buff 32)) (participant principal))
    (let ((work (map-get? ip-registry {hash: hash})))
      (if (and
            (is-some work)
            (is-eq (get owner (unwrap-panic work)) tx-sender))
          (begin
             (map-delete revenue-shares {hash: hash, participant: participant})
             (ok true))
          (err u14)
      )
    )
)

(define-read-only (get-license-details (hash (buff 32)) (licensee principal))
    (map-get? licenses {work-hash: hash, licensee: licensee})
)

(define-read-only (get-collaborator-details (hash (buff 32)) (collaborator principal))
    (map-get? collaborators {hash: hash, collaborator: collaborator})
)

(define-read-only (get-version-details (hash (buff 32)) (version uint))
    (map-get? version-registry {hash: hash, version: version})
)
