(define-fungible-token recycle-token)

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))
(define-constant ERR_ALREADY_EXISTS (err u103))
(define-constant ERR_INSUFFICIENT_FUNDS (err u104))
(define-constant ERR_PROPOSAL_NOT_ACTIVE (err u105))
(define-constant ERR_ALREADY_VOTED (err u106))
(define-constant ERR_INSUFFICIENT_STAKE (err u107))
(define-constant ERR_COOLDOWN_ACTIVE (err u108))

(define-data-var next-center-id uint u1)
(define-data-var next-proposal-id uint u1)
(define-data-var total-recycled uint u0)
(define-data-var dao-treasury uint u0)
(define-data-var total-staked uint u0)
(define-data-var staking-rewards-pool uint u0)

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

(define-map staking-positions
  { staker: principal }
  {
    amount: uint,
    start-block: uint,
    last-claim-block: uint,
    cooldown-end: uint
  }
)

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
    (var-set staking-rewards-pool (+ (var-get staking-rewards-pool) (/ reward-amount u10)))
    
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
    (base-weight (ft-get-balance recycle-token tx-sender))
    (staking-position (map-get? staking-positions { staker: tx-sender }))
    (staked-amount (default-to u0 (get amount staking-position)))
    (voter-weight (+ base-weight (* staked-amount u2)))
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

(define-public (stake-tokens (amount uint))
  (let (
    (current-balance (ft-get-balance recycle-token tx-sender))
    (existing-stake (map-get? staking-positions { staker: tx-sender }))
    (current-staked (default-to u0 (get amount existing-stake)))
  )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= current-balance amount) ERR_INSUFFICIENT_FUNDS)
    
    (try! (ft-transfer? recycle-token amount tx-sender (as-contract tx-sender)))
    
    (map-set staking-positions
      { staker: tx-sender }
      {
        amount: (+ current-staked amount),
        start-block: stacks-block-height,
        last-claim-block: stacks-block-height,
        cooldown-end: u0
      }
    )
    
    (var-set total-staked (+ (var-get total-staked) amount))
    (ok amount)
  )
)

(define-public (initiate-unstake)
  (let ((stake (unwrap! (map-get? staking-positions { staker: tx-sender }) ERR_NOT_FOUND)))
    (asserts! (> (get amount stake) u0) ERR_INSUFFICIENT_STAKE)
    (asserts! (is-eq (get cooldown-end stake) u0) ERR_COOLDOWN_ACTIVE)
    
    (map-set staking-positions
      { staker: tx-sender }
      (merge stake { cooldown-end: (+ stacks-block-height u144) })
    )
    (ok true)
  )
)

(define-public (complete-unstake)
  (let ((stake (unwrap! (map-get? staking-positions { staker: tx-sender }) ERR_NOT_FOUND)))
    (asserts! (> (get amount stake) u0) ERR_INSUFFICIENT_STAKE)
    (asserts! (> (get cooldown-end stake) u0) ERR_COOLDOWN_ACTIVE)
    (asserts! (>= stacks-block-height (get cooldown-end stake)) ERR_COOLDOWN_ACTIVE)
    
    (let ((stake-amount (get amount stake)))
      (try! (as-contract (ft-transfer? recycle-token stake-amount tx-sender tx-sender)))
      
      (map-delete staking-positions { staker: tx-sender })
      (var-set total-staked (- (var-get total-staked) stake-amount))
      (ok stake-amount)
    )
  )
)

(define-public (claim-staking-rewards)
  (let (
    (stake (unwrap! (map-get? staking-positions { staker: tx-sender }) ERR_NOT_FOUND))
    (blocks-elapsed (- stacks-block-height (get last-claim-block stake)))
    (stake-amount (get amount stake))
    (total-staked-amount (var-get total-staked))
    (rewards-pool (var-get staking-rewards-pool))
    (reward-amount (if (> total-staked-amount u0)
      (/ (* (* stake-amount blocks-elapsed) rewards-pool) (* total-staked-amount u1000))
      u0
    ))
  )
    (asserts! (> stake-amount u0) ERR_INSUFFICIENT_STAKE)
    (asserts! (> reward-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= rewards-pool reward-amount) ERR_INSUFFICIENT_FUNDS)
    
    (try! (ft-mint? recycle-token reward-amount tx-sender))
    (var-set staking-rewards-pool (- rewards-pool reward-amount))
    
    (map-set staking-positions
      { staker: tx-sender }
      (merge stake { last-claim-block: stacks-block-height })
    )
    
    (ok reward-amount)
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

(define-read-only (get-staking-position (staker principal))
  (map-get? staking-positions { staker: staker })
)

(define-read-only (get-total-staked)
  (var-get total-staked)
)

(define-read-only (get-staking-rewards-pool)
  (var-get staking-rewards-pool)
)

(define-read-only (calculate-staking-rewards (staker principal))
  (let (
    (stake (map-get? staking-positions { staker: staker }))
    (stake-amount (default-to u0 (get amount stake)))
    (last-claim (default-to u0 (get last-claim-block stake)))
    (blocks-elapsed (- stacks-block-height last-claim))
    (total-staked-amount (var-get total-staked))
    (rewards-pool (var-get staking-rewards-pool))
  )
    (if (and (> stake-amount u0) (> total-staked-amount u0))
      (/ (* (* stake-amount blocks-elapsed) rewards-pool) (* total-staked-amount u1000))
      u0
    )
  )
)

(define-map material-multipliers
  { material: (string-ascii 32) }
  { multiplier: uint }
)

(define-map referral-codes
  { code: (string-ascii 43) }
  { referrer: principal, used: bool }
)

(define-data-var next-referral-id uint u1)

(define-data-var emergency-fund uint u0)

(define-public (generate-referral-code)
  (let ((referral-id (var-get next-referral-id)))
    (var-set next-referral-id (+ referral-id u1))
    (let ((code (concat "REF" (int-to-ascii referral-id))))
      (map-set referral-codes
        { code: code }
        { referrer: tx-sender, used: false }
      )
      (ok code)
    )
  )
)

(define-public (use-referral-code (code (string-ascii 16)))
  (let (
    (referral-data (unwrap! (map-get? referral-codes { code: code }) ERR_NOT_FOUND))
    (referrer (get referrer referral-data))
  )
    (asserts! (not (get used referral-data)) ERR_ALREADY_EXISTS)
    (asserts! (not (is-eq referrer tx-sender)) ERR_UNAUTHORIZED)
    (map-set referral-codes
      { code: code }
      (merge referral-data { used: true })
    )
    (try! (ft-mint? recycle-token u50 referrer))
    (try! (ft-mint? recycle-token u25 tx-sender))
    (ok true)
  )
)

(define-read-only (get-referral-code (code (string-ascii 16)))
  (map-get? referral-codes { code: code })
)

(define-public (contribute-emergency-fund (amount uint))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set emergency-fund (+ (var-get emergency-fund) amount))
    (ok true)
  )
)

(define-public (request-emergency-aid (reason (string-ascii 128)))
  (let (
    (recycler-data (unwrap! (map-get? recycler-profiles { recycler: tx-sender }) ERR_NOT_FOUND))
    (aid-amount (if (>= (get reputation-score recycler-data) u20) u1000 u500))
  )
    (asserts! (>= (var-get emergency-fund) aid-amount) ERR_INSUFFICIENT_FUNDS)
    (asserts! (>= (get reputation-score recycler-data) u5) ERR_UNAUTHORIZED)
    (try! (as-contract (stx-transfer? aid-amount tx-sender tx-sender)))
    (var-set emergency-fund (- (var-get emergency-fund) aid-amount))
    (ok aid-amount)
  )
)

(define-read-only (get-emergency-fund-balance)
  (var-get emergency-fund)
)

(define-public (transfer-tokens (amount uint) (recipient principal))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (not (is-eq tx-sender recipient)) ERR_UNAUTHORIZED)
    (try! (ft-transfer? recycle-token amount tx-sender recipient))
    (ok true)
  )
)
