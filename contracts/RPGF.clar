;; rpgf-core.clar

(define-constant ERR_INVALID_INPUT u400)
(define-constant ERR_NOT_AUTHORIZED u401)
(define-constant ERR_INSUFFICIENT_POOL u402)
(define-constant ERR_TARGET_UNMET u403)
(define-constant ERR_NOT_FOUND u404)
(define-constant ERR_ALREADY_CLAIMED u409)
(define-constant ERR_TOKEN_UNSET u410)
(define-constant ERR_TOKEN_MISMATCH u411)
(define-constant ERR_TARGET_MISMATCH u412)
(define-constant ERR_BAD_CONTRACT u500)

(define-trait sip010-ft
    (
        (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    )
)

(define-trait interaction-count-trait
    (
        (get-interaction-count () (response uint uint))
    )
)

(define-data-var admin principal tx-sender)
(define-data-var next-id uint u0)
(define-data-var sbtc-token (optional principal) none)
(define-data-var pool-balance uint u0)

(define-map milestones
    { id: uint }
    {
        description: (string-ascii 64),
        target-calls: uint,
        payout: uint,
        claimant: principal,
        target-contract: principal,
        claimed: bool
    }
)

(define-private (is-admin (sender principal))
    (is-eq sender (var-get admin))
)

(define-read-only (get-admin)
    (var-get admin)
)

(define-read-only (get-sbtc-token)
    (var-get sbtc-token)
)

(define-read-only (get-pool-balance)
    (var-get pool-balance)
)

(define-read-only (get-milestone (id uint))
    (map-get? milestones { id: id })
)

(define-public (set-admin (new-admin principal))
    (begin
        (asserts! (is-admin tx-sender) (err ERR_NOT_AUTHORIZED))
        (var-set admin new-admin)
        (ok true)
    )
)

(define-public (set-sbtc-token (token <sip010-ft>))
    (begin
        (asserts! (is-admin tx-sender) (err ERR_NOT_AUTHORIZED))
        (var-set sbtc-token (some (contract-of token)))
        (ok true)
    )
)

(define-public (deposit-sbtc (token <sip010-ft>) (amount uint))
    (let ((token-opt (var-get sbtc-token)))
        (match token-opt token-principal
            (begin
                (asserts! (> amount u0) (err ERR_INVALID_INPUT))
                (asserts! (is-eq (contract-of token) token-principal) (err ERR_TOKEN_MISMATCH))
                (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender) none))
                (var-set pool-balance (+ (var-get pool-balance) amount))
                (ok true)
            )
            (err ERR_TOKEN_UNSET)
        )
    )
)

(define-public (withdraw-sbtc (token <sip010-ft>) (amount uint) (recipient principal))
    (let ((token-opt (var-get sbtc-token)))
        (match token-opt token-principal
            (begin
                (asserts! (is-admin tx-sender) (err ERR_NOT_AUTHORIZED))
                (asserts! (> amount u0) (err ERR_INVALID_INPUT))
                (asserts! (>= (var-get pool-balance) amount) (err ERR_INSUFFICIENT_POOL))
                (asserts! (is-eq (contract-of token) token-principal) (err ERR_TOKEN_MISMATCH))
                (try! (as-contract (contract-call? token transfer amount tx-sender recipient none)))
                (var-set pool-balance (- (var-get pool-balance) amount))
                (ok true)
            )
            (err ERR_TOKEN_UNSET)
        )
    )
)

(define-public (register-milestone
    (description (string-ascii 64))
    (target-calls uint)
    (payout uint)
    (claimant principal)
    (target-contract <interaction-count-trait>)
)
    (let ((id (var-get next-id)))
        (begin
            (asserts! (is-admin tx-sender) (err ERR_NOT_AUTHORIZED))
            (asserts! (> payout u0) (err ERR_INVALID_INPUT))
            (map-set milestones
                { id: id }
                {
                    description: description,
                    target-calls: target-calls,
                    payout: payout,
                    claimant: claimant,
                    target-contract: (contract-of target-contract),
                    claimed: false
                }
            )
            (var-set next-id (+ id u1))
            (ok id)
        )
    )
)

(define-public (claim-milestone (id uint) (target-contract <interaction-count-trait>) (token <sip010-ft>))
    (let ((milestone (unwrap! (map-get? milestones { id: id }) (err ERR_NOT_FOUND))))
        (let ((token-opt (var-get sbtc-token)))
            (match token-opt token-principal
                (begin
                    (asserts! (not (get claimed milestone)) (err ERR_ALREADY_CLAIMED))
                    (asserts! (>= (var-get pool-balance) (get payout milestone)) (err ERR_INSUFFICIENT_POOL))
                    (asserts! (is-eq (contract-of token) token-principal) (err ERR_TOKEN_MISMATCH))
                    (asserts! (is-eq (contract-of target-contract) (get target-contract milestone)) (err ERR_TARGET_MISMATCH))
                    ;; Check if the target contract has received enough interaction.
                    ;; This requires the target contract to expose `get-interaction-count`.
                    (let ((interaction-count (unwrap! (contract-call? target-contract get-interaction-count) (err ERR_BAD_CONTRACT))))
                        (begin
                            (asserts! (>= interaction-count (get target-calls milestone)) (err ERR_TARGET_UNMET))
                            (try! (as-contract (contract-call? token transfer (get payout milestone) tx-sender (get claimant milestone) none)))
                            (var-set pool-balance (- (var-get pool-balance) (get payout milestone)))
                            (map-set milestones
                                { id: id }
                                {
                                    description: (get description milestone),
                                    target-calls: (get target-calls milestone),
                                    payout: (get payout milestone),
                                    claimant: (get claimant milestone),
                                    target-contract: (get target-contract milestone),
                                    claimed: true
                                }
                            )
                            (ok true)
                        )
                    )
                )
                (err ERR_TOKEN_UNSET)
            )
        )
    )
)
