;; error codes
(define-constant ERR_UNAUTHORIZED (err u0))
(define-constant ERR_INVALID_SIGNATURE (err u1))
(define-constant ERR_STREAM_STILL_ACTIVE (err u2))
(define-constant ERR_INVALID_STREAM_ID (err u3))
(define-constant ERR_INVALID_AMOUNT (err u4))

;; data vars
(define-data-var latest-stream-id uint u0)

;; streams mapping
(define-map streams
  ;; define streams mapping with key-types and value-types
  uint ;; stream-id
  {
    sender: principal,
    recipient: principal,
    balance: uint,
    withdrawn-balance: uint,
    payment-per-block: uint,
    timeframe: { start-block: uint, stop-block: uint }
    ;; timeframe: (tuple (start-block uint) (stop-block uint)) - tuple shorthand
  }
)

;; Create a new stream
(define-public (stream-to
    (recipient principal)
    (initial-balance uint)
    (timeframe (tuple (start-block uint) (stop-block uint)))
    (payment-per-block uint)
  )

  ;; create new stream using function arguments
  (let (
    (stream {
      sender: contract-caller,
      recipient: recipient,
      balance: initial-balance,
      withdrawn-balance: u0,
      payment-per-block: payment-per-block,
      timeframe: timeframe
    })
    (current-stream-id (var-get latest-stream-id))
  )
    
    ;; assert that initial stream balance is > 0
    (asserts! (> initial-balance u0) ERR_INVALID_AMOUNT)

    ;; `as-contract` switches the `tx-sender` variable to be the contract principal inside its scope
    ;; so doing `as-contract tx-sender` gives us the contract address itself like address(this) in Solidity
    (try! (stx-transfer? initial-balance contract-caller (as-contract tx-sender)))

    ;; set stream in streams mapping using current-stream-id variable value
    (map-set streams current-stream-id stream)
    
    ;; update latest-stream-id variable
    (var-set latest-stream-id (+ current-stream-id u1))
    (ok current-stream-id)
  )
)

;; Increase the locked STX balance for a stream
(define-public (refuel
    (stream-id uint)
    (amount uint)
  )

  ;; get stream from streams mapping using stream id
  (let (
    (stream (unwrap! (map-get? streams stream-id) ERR_INVALID_STREAM_ID))
    )

    ;; assert amount > 0 and contract caller initialized the stream
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (is-eq contract-caller (get sender stream)) ERR_UNAUTHORIZED)

    ;; try to transfer initial balance from contract caller (sender) to contract (recipient)
    (try! (stx-transfer? amount contract-caller (as-contract tx-sender)))

    ;; update stream in streams mapping 
    (map-set streams stream-id
      ;; merge old stream with updated balance goten from adding amount to current balance
      (merge stream {balance: (+ (get balance stream) amount)})
    )
    (ok amount)
  )
)


;; Calculate the number of blocks a stream has been active
(define-read-only (calculate-block-delta
    (timeframe (tuple (start-block uint) (stop-block uint)))
  )

  ;; declare block delta variables
  (let (
    (start-block (get start-block timeframe))
    (stop-block (get stop-block timeframe))

    (delta 
      (if (<= stacks-block-height start-block)
        ;; then
        u0
        ;; else
        (if (< stacks-block-height stop-block)
          ;; then
          (- stacks-block-height start-block)
          ;; else
          (- stop-block start-block)
        ) 
      )
    )
  )
    delta
  )
)

;; Check balance for a party involved in a stream
(define-read-only (balance-of
    (stream-id uint)
    (who principal)
  )

  (let (
    (stream (unwrap! (map-get? streams stream-id) u0))
    (block-delta (calculate-block-delta (get timeframe stream)))
    (recipient-balance (* block-delta (get payment-per-block stream)))
  )

    ;; think of this as a ternary conditional structure not a nested if block
    ;; if who == stream recipient
    (if (is-eq who (get recipient stream))
      ;; return recipient balance as of current block: max recipient-balance - withdrawn-balance
      (- recipient-balance (get withdrawn-balance stream))
      ;; elif who == stream sender
      (if (is-eq who (get sender stream))
        ;; return balance left: total stream-balance - recipient-balance
        (- (get balance stream) recipient-balance)
        ;; else return 0
        u0
      )
    )
  )
)

;; Withdraw received tokens
(define-public (withdraw
    (stream-id uint)
  )

  (let (
    (stream (unwrap! (map-get? streams stream-id) ERR_INVALID_STREAM_ID))
    (balance (balance-of stream-id contract-caller))
  )

    ;; ensure contract-caller (NOT TX-SENDER) is stream recipient 
    (asserts! (is-eq contract-caller (get recipient stream)) ERR_UNAUTHORIZED)

    ;; update streams mapping with new stream
    (map-set streams stream-id 
      ;; merge old stream at stream-id with new total withdrawn-balance
      (merge stream {withdrawn-balance: (+ (get withdrawn-balance stream) balance)})
    )

    ;; transfer withdrawable balance from contract to recipient
    (try! (as-contract (stx-transfer? balance tx-sender (get recipient stream))))

    (ok balance)
  )
)

;; Withdraw excess locked tokens
(define-public (refund
    (stream-id uint)
  )

  (let (
    (stream (unwrap! (map-get? streams stream-id) ERR_INVALID_STREAM_ID))
    (balance (balance-of stream-id (get sender stream)))
  )

    ;; assert caller is stream creator and stream is not active before refund
    (asserts! (is-eq contract-caller (get sender stream)) ERR_UNAUTHORIZED)
    (asserts! (< (get stop-block (get timeframe stream)) stacks-block-height) ERR_STREAM_STILL_ACTIVE)

    ;; update streams mapping with new stream (merge of old stream with { balance: leftover balance })
    (map-set streams stream-id (merge stream {
        balance: (- (get balance stream) balance),
      }
    ))

    ;; transfer leftover balance from contract address to stream creator principal
    (try! (as-contract (stx-transfer? balance tx-sender (get sender stream))))

    (ok balance)
  )
)

;; Get hash of stream
(define-read-only (hash-stream
    (stream-id uint)
    (new-payment-per-block uint)
    (new-timeframe (tuple (start-block uint) (stop-block uint)))
  )

  (let
    (
      ;; unwrap stream response from streams mapping and store in local var
      (stream (unwrap! (map-get? streams stream-id) (sha256 0)))

      ;; convert func args to buffers, unwrap results, concatentate sequentially, and store in msg var
      (msg 
        ;; concatenate both values
        (concat
          ;; concatenate both values
          (concat
            ;; convert tuple to buffer (32 bytes) and unwrap result
            (unwrap-panic (to-consensus-buff? new-payment-per-block))
            (unwrap-panic (to-consensus-buff? new-timeframe))
          )
          ;; convert tuple to buffer (32 bytes) and unwrap result
          (unwrap-panic (to-consensus-buff? stream))
        )
      )
    )

    ;; get a deterministic SHA-256 hash of msg and return
    (sha256 msg)
  )
)

;; Signature verification
(define-read-only (validate-signature (hash (buff 32)) (signature (buff 65)) (signer principal))
        ;; compare the principal and signer values:
        (is-eq
          ;; 1. use the secp function to recover the pub key used to sign the hash with the signature
          ;; 2. unwrap that response to carry o with comparisonn (ok) or throw error (err)
          ;; 3. use the principal-of function to get the principal derived from the provided public key
          (principal-of? (unwrap! (secp256k1-recover? hash signature) false)) 
          (ok signer)
        )
)

;; Update stream configuration
(define-public (update-details
    (stream-id uint)
    (payment-per-block uint)
    (timeframe (tuple (start-block uint) (stop-block uint)))
    (signer principal)
    (signature (buff 65))
  )

  (let (
    (stream (unwrap! (map-get? streams stream-id) ERR_INVALID_STREAM_ID))  
  )

    ;; assert that the validate-signature function returns true or throw an error
    (asserts! (validate-signature (hash-stream stream-id payment-per-block timeframe) signature signer) ERR_INVALID_SIGNATURE)

    ;; assert that either 
    (asserts!
      ;; one of these is the case
      (or
        ;; the contract-caller is the stream owner and the signer is the stream recipient
        (and (is-eq (get sender stream) contract-caller) (is-eq (get recipient stream) signer))
        ;; the stream recipient is the contract-caller and the stream owner is the signer
        (and (is-eq (get sender stream) signer) (is-eq (get recipient stream) contract-caller))
      )
      ;; or throw an unauthorized error
      ERR_UNAUTHORIZED
    )

    ;; merge old stream with new values (payment-per-block, and block timeframe) and update streams mapping
    (map-set streams stream-id (merge stream {
        payment-per-block: payment-per-block,
        timeframe: timeframe
    }))

    ;; return ok response
    (ok true)
  )
)
