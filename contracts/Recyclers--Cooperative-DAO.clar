(define-fungible-token recycle-token)

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))
(define-constant ERR_ALREADY_EXISTS (err u103))
(define-constant ERR_INSUFFICIENT_FUNDS (err u104))
(define-constant ERR_PROPOSAL_NOT_ACTIVE (err u105))
(define-constant ERR_ALREADY_VOTED (err u106))

(define-data-var next-center-id uint u1)
(define-data-var next-proposal-id uint u1)
(define-data-var total-recycled uint u0)
(define-data-var dao-treasury uint u0)

(define-map collection-centers
  { center-id: uint }
  {
    owner: principal,
    name: (string-ascii 64),
    location: (string-ascii 128),
    verified: bool,
    total-processed: uint
  }
)

(define-map recycler-profiles
  { recycler: principal }
  {
    total-recycled: uint,
    tokens-earned: uint,
    loan-balance: uint,
    reputation-score: uint
  }
)

(define-map proposals
  { proposal-id: uint }
  {
    proposer: principal,
    title: (string-ascii 64),
    description: (string-ascii 256),
    amount: uint,
    recipient: principal,
    votes-for: uint,
    votes-against: uint,
    end-block: uint,
    executed: bool,
    proposal-type: (string-ascii 16)
  }
)

(define-map proposal-votes
  { proposal-id: uint, voter: principal }
  { voted: bool }
)

(define-map esg-data
  { data-id: uint }
  {
    funder: principal,
    recycler: principal,
    co2-saved: uint,
    waste-processed: uint,
    timestamp: uint
  }
)

(define-data-var next-esg-id uint u1)

(define-public (register-collection-center (name (string-ascii 64)) (location (string-ascii 128)))
  (let ((center-id (var-get next-center-id)))
    (asserts! (is-none (map-get? collection-centers { center-id: center-id })) ERR_ALREADY_EXISTS)
    (map-set collection-centers
      { center-id: center-id }
      {
        owner: tx-sender,
        name: name,
        location: location,
        verified: false,
        total-processed: u0
      }
    )
    (var-set next-center-id (+ center-id u1))
    (ok center-id)
  )
)

(define-public (verify-collection-center (center-id uint))
  (let ((center (unwrap! (map-get? collection-centers { center-id: center-id }) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set collection-centers
      { center-id: center-id }
      (merge center { verified: true })
    )
    (ok true)
  )
)

(define-public (submit-recycling (center-id uint) (amount uint) (material-type (string-ascii 32)))
  (let (
    (center (unwrap! (map-get? collection-centers { center-id: center-id }) ERR_NOT_FOUND))
    (recycler-data (default-to 
      { total-recycled: u0, tokens-earned: u0, loan-balance: u0, reputation-score: u0 }
      (map-get? recycler-profiles { recycler: tx-sender })
    ))
    (reward-amount (* amount u10))
  )
    (asserts! (get verified center) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    (try! (ft-mint? recycle-token reward-amount tx-sender))
    
    (map-set collection-centers
      { center-id: center-id }
      (merge center { total-processed: (+ (get total-processed center) amount) })
    )
    
    (map-set recycler-profiles
      { recycler: tx-sender }
      {
        total-recycled: (+ (get total-recycled recycler-data) amount),
        tokens-earned: (+ (get tokens-earned recycler-data) reward-amount),
        loan-balance: (get loan-balance recycler-data),
        reputation-score: (+ (get reputation-score recycler-data) u1)
      }
    )
    
    (var-set total-recycled (+ (var-get total-recycled) amount))
    
    (ok reward-amount)
  )
)

(define-public (create-proposal (title (string-ascii 64)) (description (string-ascii 256)) (amount uint) (recipient principal) (proposal-type (string-ascii 16)))
  (let ((proposal-id (var-get next-proposal-id)))
    (asserts! (>= (ft-get-balance recycle-token tx-sender) u100) ERR_UNAUTHORIZED)
    (map-set proposals
      { proposal-id: proposal-id }
      {
        proposer: tx-sender,
        title: title,
        description: description,
        amount: amount,
        recipient: recipient,
        votes-for: u0,
        votes-against: u0,
        end-block: (+ stacks-block-height u144),
        executed: false,
        proposal-type: proposal-type
      }
    )
    (var-set next-proposal-id (+ proposal-id u1))
    (ok proposal-id)
  )
)

(define-public (vote-proposal (proposal-id uint) (vote-for bool))
  (let (
    (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR_NOT_FOUND))
    (voter-weight (ft-get-balance recycle-token tx-sender))
  )
    (asserts! (< stacks-block-height (get end-block proposal)) ERR_PROPOSAL_NOT_ACTIVE)
    (asserts! (is-none (map-get? proposal-votes { proposal-id: proposal-id, voter: tx-sender })) ERR_ALREADY_VOTED)
    (asserts! (> voter-weight u0) ERR_UNAUTHORIZED)
    
    (map-set proposal-votes
      { proposal-id: proposal-id, voter: tx-sender }
      { voted: true }
    )
    
    (if vote-for
      (map-set proposals
        { proposal-id: proposal-id }
        (merge proposal { votes-for: (+ (get votes-for proposal) voter-weight) })
      )
      (map-set proposals
        { proposal-id: proposal-id }
        (merge proposal { votes-against: (+ (get votes-against proposal) voter-weight) })
      )
    )
    (ok true)
  )
)

(define-public (execute-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR_NOT_FOUND)))
    (asserts! (>= stacks-block-height (get end-block proposal)) ERR_PROPOSAL_NOT_ACTIVE)
    (asserts! (not (get executed proposal)) ERR_ALREADY_EXISTS)
    (asserts! (> (get votes-for proposal) (get votes-against proposal)) ERR_UNAUTHORIZED)
    
    (if (is-eq (get proposal-type proposal) "loan")
      (try! (provide-loan (get recipient proposal) (get amount proposal)))
      (try! (transfer-from-treasury (get recipient proposal) (get amount proposal)))
    )
    
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal { executed: true })
    )
    (ok true)
  )
)

(define-private (provide-loan (borrower principal) (amount uint))
  (let (
    (recycler-data (default-to 
      { total-recycled: u0, tokens-earned: u0, loan-balance: u0, reputation-score: u0 }
      (map-get? recycler-profiles { recycler: borrower })
    ))
  )
    (asserts! (>= (var-get dao-treasury) amount) ERR_INSUFFICIENT_FUNDS)
    (asserts! (>= (get reputation-score recycler-data) u10) ERR_UNAUTHORIZED)
    
    (map-set recycler-profiles
      { recycler: borrower }
      (merge recycler-data { loan-balance: (+ (get loan-balance recycler-data) amount) })
    )
    
    (var-set dao-treasury (- (var-get dao-treasury) amount))
    (ok true)
  )
)

(define-private (transfer-from-treasury (recipient principal) (amount uint))
  (begin
    (asserts! (>= (var-get dao-treasury) amount) ERR_INSUFFICIENT_FUNDS)
    (var-set dao-treasury (- (var-get dao-treasury) amount))
    (ok true)
  )
)

(define-public (fund-dao (amount uint))
  (begin
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set dao-treasury (+ (var-get dao-treasury) amount))
    (ok true)
  )
)

(define-public (repay-loan (amount uint))
  (let (
    (recycler-data (unwrap! (map-get? recycler-profiles { recycler: tx-sender }) ERR_NOT_FOUND))
    (current-balance (get loan-balance recycler-data))
  )
    (asserts! (>= current-balance amount) ERR_INVALID_AMOUNT)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    (map-set recycler-profiles
      { recycler: tx-sender }
      (merge recycler-data { loan-balance: (- current-balance amount) })
    )
    
    (var-set dao-treasury (+ (var-get dao-treasury) amount))
    (ok true)
  )
)

(define-public (record-esg-data (recycler principal) (co2-saved uint) (waste-processed uint))
  (let ((esg-id (var-get next-esg-id)))
    (map-set esg-data
      { data-id: esg-id }
      {
        funder: tx-sender,
        recycler: recycler,
        co2-saved: co2-saved,
        waste-processed: waste-processed,
        timestamp: stacks-block-height
      }
    )
    (var-set next-esg-id (+ esg-id u1))
    (ok esg-id)
  )
)

(define-read-only (get-collection-center (center-id uint))
  (map-get? collection-centers { center-id: center-id })
)

(define-read-only (get-recycler-profile (recycler principal))
  (map-get? recycler-profiles { recycler: recycler })
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id })
)

(define-read-only (get-esg-data (data-id uint))
  (map-get? esg-data { data-id: data-id })
)

(define-read-only (get-total-recycled)
  (var-get total-recycled)
)

(define-read-only (get-dao-treasury)
  (var-get dao-treasury)
)

(define-read-only (get-token-balance (user principal))
  (ft-get-balance recycle-token user)
)
