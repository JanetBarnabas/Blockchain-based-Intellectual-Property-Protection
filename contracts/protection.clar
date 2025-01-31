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
    (let
        ((existing-registration (map-get? ip-registry {hash: hash})))
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
