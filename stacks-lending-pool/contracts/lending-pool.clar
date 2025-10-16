;; Errors
(define-constant ERR_INVALID_WITHDRAW_AMOUNT (err u100))
(define-constant ERR_EXCEEDED_MAX_BORROW (err u101))
(define-constant ERR_CANNOT_BE_LIQUIDATED (err u102))
(define-constant ERR_MUST_WITHDRAW_BEFORE_NEW_DEPOSIT (err u103))

;; Constants
(define-constant LTV_PERCENTAGE u70)
(define-constant INTEREST_RATE_PERCENTAGE u10)
(define-constant LIQUIDATION_THRESHOLD_PERCENTAGE u100)
(define-constant ONE_YEAR_IN_SECS u31556952)

;; Storage

;; Total amount of sBTC we have as collateral for loans
(define-data-var total-sbtc-collateral uint u0)

;; Total amount of STX that lenders have deposited
(define-data-var total-stx-deposits uint u1)

;; Total amount of STX that borrowers have borrowed
(define-data-var total-stx-borrows uint u0)

;; Last time interest was accrued
(define-data-var last-interest-accrual uint (get-latest-timestamp))

;; Cumulative interest earned (yield) in bips per deposited STX token (interest * 10000)
(define-data-var cumulative-yield-bips uint u0)

;; Map of user principal to amount of sBTC they have as collateral
(define-map collateral
    { user: principal }
    { amount: uint }
)

;; Map of user principal to amount of STX they have deposited
(define-map deposits
    { user: principal }
    {
        amount: uint,
        yield-index: uint,
    }
)

;; Map of user principal to amount of STX they have borrowed
(define-map borrows
    { user: principal }
    {
        amount: uint,
        last-accrued: uint,
    }
)

;; ------------------------------------
;;               LENDING
;; ------------------------------------

;; @desc Deposits STX into the lending pool
;; @param amount: The amount of STX to deposit
;; @returns (response bool)
(define-public (deposit-stx (amount uint))
    (let (
            (user-deposit (map-get? deposits { user: tx-sender }))
            (deposited-stx (default-to u0 (get amount user-deposit)))
        )

        ;; assert lender has not deposited STX before
        (asserts! (is-eq deposited-stx u0) ERR_MUST_WITHDRAW_BEFORE_NEW_DEPOSIT)
        (unwrap-panic (accrue-interest))

        ;; transfer deposit amount from lender to contract
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

        ;; update deposit records in storage
        (map-set deposits { user: tx-sender } {
            amount: (+ deposited-stx amount),
            yield-index: (var-get cumulative-yield-bips),
        })
        (var-set total-stx-deposits (+ (var-get total-stx-deposits) amount))

        (ok true)
    )
)

;; @desc Withdraws STX from the lending pool
;; @param amount: The amount of STX to withdraw
;; @returns (response bool)
(define-public (withdraw-stx (amount uint))
    (let (
            (user tx-sender)
            (user-deposit (map-get? deposits { user: user }))
            (deposited-stx (default-to u0 (get amount user-deposit)))
            (yield-index (default-to u0 (get yield-index user-deposit)))
            (pending-yield (unwrap-panic (get-pending-yield)))
        )

        ;; verify that lender has deposited amount to be withdrawn
        (asserts! (>= deposited-stx amount) ERR_INVALID_WITHDRAW_AMOUNT)
        (unwrap-panic (accrue-interest))

        ;; update lender deposit storage variables
        (map-set deposits { user: user } {
            amount: (- deposited-stx amount),
            yield-index: (var-get cumulative-yield-bips),
        })
        (var-set total-stx-deposits (- (var-get total-stx-deposits) amount))

        ;; transfer lender's yield to their address
        (try! (as-contract (stx-transfer? (+ amount pending-yield) tx-sender user)))
        (ok true)
    )
)

;; @desc Gets the total amount of pending STX yield that the lender has earned
;; The user is the tx-sender 
(define-read-only (get-pending-yield)
    (let (
            (user-deposit (map-get? deposits { user: tx-sender }))
            (yield-index (default-to u0 (get yield-index user-deposit)))
            (amount-stx (default-to u0 (get amount user-deposit)))
            (delta (- (var-get cumulative-yield-bips) yield-index))
            (pending-yield (/ (* amount-stx delta) u10000))
        )
        (ok pending-yield)
    )
)

;; ------------------------------------
;;               BORROWING
;; ------------------------------------

;; @desc Borrows STX from the lending pool
;; @param collateral-amount: The amount of sBTC to use as collateral
;; @param amount-stx: The amount of STX to borrow
;; @returns (response bool)
(define-public (borrow-stx
        (collateral-amount uint)
        (amount-stx uint)
    )
    (let (
            (user tx-sender)
            (user-collateral (map-get? collateral { user: user }))
            (deposited-sbtc (default-to u0 (get amount user-collateral)))
            (new-collateral (+ deposited-sbtc collateral-amount))
            (price (unwrap-panic (get-sbtc-stx-price)))
            (max-borrow (/ (* (* new-collateral price) LTV_PERCENTAGE) u100))
            (user-borrow (map-get? borrows { user: user }))
            (borrowed-stx (default-to u0 (get amount user-borrow)))
            (user-debt (unwrap-panic (get-debt user)))
            (new-debt (+ user-debt amount-stx))
        )

        ;; assert new borrow amount is less than max borrowable amount
        (asserts! (<= new-debt max-borrow) ERR_EXCEEDED_MAX_BORROW)
        (unwrap-panic (accrue-interest))

        ;; update borrower mapping and variable
        (map-set borrows { user: user } {
            amount: new-debt,
            last-accrued: (get-latest-timestamp),
        })
        (var-set total-stx-borrows (+ (var-get total-stx-borrows) amount-stx))

        ;; update collateral mapping and variable
        (map-set collateral { user: user } { amount: new-collateral })
        (var-set total-sbtc-collateral
            (+ (var-get total-sbtc-collateral) collateral-amount)
        )

        ;; transfer collateral sBTC from borrower to contract and handle errors gracefully
        (try! (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
            transfer collateral-amount tx-sender (as-contract tx-sender)
            none
        ))

        ;; try to transfer borrowed STX amount to recipient
        (try! (as-contract (stx-transfer? amount-stx tx-sender user)))
        (ok true)
    )
)

;; @desc Repays the loan in full
;; @returns (response bool)
(define-public (repay)
    (let (
            (user-borrow (map-get? borrows { user: tx-sender }))
            (borrowed-stx (default-to u0 (get amount user-borrow)))
            (total-debt (+ u1 (unwrap-panic (get-debt tx-sender))))
            (user-collateral (map-get? collateral { user: tx-sender }))
            (deposited-sbtc (default-to u0 (get amount user-collateral)))
        )

        ;; accrue interest across all lenders
        (unwrap-panic (accrue-interest))

        ;; clear user's collateral from mapping; update total-sbtc-collateral variables
        (map-delete collateral { user: tx-sender })
        (var-set total-sbtc-collateral
            (- (var-get total-sbtc-collateral) deposited-sbtc)
        )

        ;; clear user's borrow record from mapping; update total-stx-borrow variables
        (map-delete borrows { user: tx-sender })
        (var-set total-stx-borrows (- (var-get total-stx-borrows) borrowed-stx))

        ;; transfer borrower's STX debt from their address to contract principal
        (try! (stx-transfer? total-debt tx-sender (as-contract tx-sender)))

        ;; transfer borrower's sBTC collateral from contract to their address
        (try! (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
            transfer deposited-sbtc (as-contract tx-sender) tx-sender none
        ))
        (ok true)
    )
)

;; @desc Gets the debt for a user
;; Includes the amount of STX they have borrowed + interest that has accumulated
;; @param user: The user to get the debt for
;; @returns (response uint)
(define-read-only (get-debt (user principal))
    (let (
            (user-borrow (map-get? borrows { user: user }))
            (borrowed-stx (default-to u0 (get amount user-borrow)))
            (last-accrued (default-to u0 (get last-accrued user-borrow)))
            (latest-timestamp (get-latest-timestamp))
            (dt (- latest-timestamp last-accrued))
            (interest-numerator (* borrowed-stx INTEREST_RATE_PERCENTAGE dt))
            (interest-denominator (* ONE_YEAR_IN_SECS u100))
            (interest (/ interest-numerator interest-denominator))
            (accrued-interest (+ borrowed-stx interest))
        )
        (ok accrued-interest)
    )
)

;; ------------------------------------
;;               LIQUIDATION
;; ------------------------------------

;; @desc Liquidates a borrower
;; @param user: The user to liquidate
;; @returns (response bool)
(define-public (liquidate (user principal))
    (let (
            ;; calculate user debt and amount of forfeitable borrows
            (user-debt (unwrap-panic (get-debt user)))
            (forfeited-borrows (if (> user-debt (var-get total-stx-borrows))
                (var-get total-stx-borrows)
                user-debt
            ))

            ;; calculated user deposited collateral
            (user-collateral (map-get? collateral { user: user }))
            (deposited-sbtc (default-to u0 (get amount user-collateral)))
            (price (unwrap-panic (get-sbtc-stx-price)))

            ;; calculate liquidator bounty, pool reward, and contract sBTC balance
            (collateral-value-in-stx (* deposited-sbtc price))
            (liquidator-bounty (/ (* deposited-sbtc u10) u100))
            (pool-reward (- deposited-sbtc liquidator-bounty))
            (sbtc-balance (unwrap-panic (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
                get-balance (as-contract tx-sender)
            )))

            ;; setup Bitflow DEX quote for swapping sBTC for STX
            (xyk-tokens {
                a: 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token,
                b: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2,
            })
            (xyk-pools { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-sbtc-stx-v-1-1 })
            (quote (try! (contract-call?
                'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-swap-helper-v-1-3
                get-quote-a pool-reward none xyk-tokens xyk-pools
            )))
        )

        ;; accrue interest
        (unwrap-panic (accrue-interest))

        ;; ensure user has debt and liquidation threshold has been met
        (asserts! (> user-debt u0) ERR_CANNOT_BE_LIQUIDATED)
        (asserts!
            (<= (* collateral-value-in-stx u100)
                (* user-debt LIQUIDATION_THRESHOLD_PERCENTAGE)
            )
            ERR_CANNOT_BE_LIQUIDATED
        )

        ;; update total collateral and total borrowed amounts in mappings
        (var-set total-sbtc-collateral
            (- (var-get total-sbtc-collateral) deposited-sbtc)
        )
        (var-set total-stx-borrows
            (- (var-get total-stx-borrows) forfeited-borrows)
        )

        ;; delete user records from borrow and collateral mappings
        (map-delete borrows { user: user })
        (map-delete collateral { user: user })

        ;; send 10% of the sBTC collateral to the liquidator
        (try! (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
            transfer (+ pool-reward liquidator-bounty)
            (as-contract tx-sender) tx-sender none
        ))

        (let 
            ;; trigger a swap on Bitflow's DEX to sell the sBTC collateral to liquidator
            ((received-stx (try! (contract-call?
                'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-swap-helper-v-1-3
                swap-helper-a pool-reward u0 none xyk-tokens xyk-pools
            ))))

            ;; transfer STX tokens from the Bitflow swap back into contract
            (try! (stx-transfer? received-stx tx-sender (as-contract tx-sender)))

            ;; adjust the cumulative-yield-bips value to include the amount of STX we got from selling sBTC
            ;; minus the amount of STX we lost from the forfeited loan, split amongst all existing depositors
            (var-set cumulative-yield-bips
                (+ (var-get cumulative-yield-bips)
                    (/ (* (- received-stx forfeited-borrows) u10000)
                        (var-get total-stx-deposits)
                    ))
            )
        )

        (ok true)
    )
)

;; ------------------------------------
;;               HELPERS
;; ------------------------------------

;; @desc Gets the price of sBTC in STX from the oracle
;; @returns (response uint)
(define-public (get-sbtc-stx-price)
    (contract-call? .mock-oracle get-price)
)

;; @desc Gets the latest timestamp
;; @returns (response uint)
(define-private (get-latest-timestamp)
    (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1)))
)

;; @desc Accrues interest for all lenders based on total borrowed STX
;; @returns (response bool)
(define-private (accrue-interest)
    (let (
            ;; calculate how much time has passed since interest was last accrued
            (dt (- (get-latest-timestamp) (var-get last-interest-accrual)))

            ;; calculate total amount of borrowed STX, and adjust it for the
            ;; 10% interest rate annually to the amount of time that has actually passed
            (interest-numerator (* u10000
                (* (* (var-get total-stx-borrows) INTEREST_RATE_PERCENTAGE) dt)
            ))
            (interest-denominator (* ONE_YEAR_IN_SECS u100))
            (interest (/ interest-numerator interest-denominator))

            ;; calculate how much new yield in bips per STX token have we accumulated
            (new-yield (/ interest (var-get total-stx-deposits)))
        )

        ;; update last-interest-accrual timestamp and cumulative-yield-bips
        (var-set last-interest-accrual (get-latest-timestamp))
        (var-set cumulative-yield-bips
            (+ (var-get cumulative-yield-bips) new-yield)
        )

        (ok true)
    )
)