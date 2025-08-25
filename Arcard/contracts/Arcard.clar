;; Define the Trading Card NFT
(define-non-fungible-token card-id uint)

;; Define the card marketplace map
(define-map card-marketplace
  {card-id: uint}
  {trader: principal, trade-value: uint, posted-at: uint})

;; Define the creator royalties map
(define-map creator-royalties
  {card-id: uint}
  {card-creator: principal, royalty-percent: uint})

;; Define the game master
(define-data-var game-master principal tx-sender)

;; Define game state (for tournament mode)
(define-data-var tournament-mode bool false)

;; Define constants
(define-constant CARD_MIN_VALUE u1)
(define-constant CARD_MAX_VALUE u1000000000) ;; 1 billion microSTX
(define-constant MAX_CREATOR_ROYALTY u22) ;; 22%
(define-constant TRADE_UPDATE_INTERVAL u86400) ;; 24 hours in seconds
(define-constant GAME_CREATOR tx-sender)
(define-constant MAX_CARD_NUMBER u1000000) ;; Maximum allowed card ID

;; Error codes
(define-constant ERR_CARD_NOT_TRADEABLE (err u101))
(define-constant ERR_INSUFFICIENT_TOKENS (err u102))
(define-constant ERR_COLLECTION_FAILED (err u103))
(define-constant ERR_INVALID_CREATOR_ROYALTY (err u104))
(define-constant ERR_PERMISSION_DENIED (err u105))
(define-constant ERR_CANNOT_TRADE_WITH_SELF (err u106))
(define-constant ERR_INVALID_TRADE_VALUE (err u107))
(define-constant ERR_TRADE_UPDATE_BLOCKED (err u108))
(define-constant ERR_TOURNAMENT_ACTIVE (err u109))
(define-constant ERR_CARD_ALREADY_TRADING (err u110))
(define-constant ERR_INVALID_CARD_NUMBER (err u111))
(define-constant ERR_INVALID_GAMEMASTER (err u112))

;; Helper function to validate card ID
(define-private (validate-card-number (card-num uint))
  (and 
    (>= card-num u0)
    (<= card-num MAX_CARD_NUMBER)))

;; Helper function to validate game master
(define-private (validate-gamemaster-change (new-master principal))
  (and 
    (not (is-eq new-master GAME_CREATOR))
    (not (is-eq new-master (var-get game-master)))))

;; Administrative Functions

(define-public (assign-game-master (new-master principal))
  (begin
    (asserts! (is-eq tx-sender GAME_CREATOR) ERR_PERMISSION_DENIED)
    (asserts! (validate-gamemaster-change new-master) ERR_INVALID_GAMEMASTER)
    (var-set game-master new-master)
    (print {event: "game-master-assigned", new-master: new-master})
    (ok true)))

(define-public (toggle-tournament-mode)
  (begin
    (asserts! (is-eq tx-sender (var-get game-master)) ERR_PERMISSION_DENIED)
    (ok (var-set tournament-mode (not (var-get tournament-mode))))))

;; Helper Functions

(define-read-only (is-card-trading (card-num uint))
  (is-some (map-get? card-marketplace {card-id: card-num})))

(define-read-only (get-card-trade-info (card-num uint))
  (map-get? card-marketplace {card-id: card-num}))

(define-read-only (calculate-creator-cut (value uint) (percent uint))
  (/ (* value percent) u100))

(define-read-only (get-creator-royalty-data (card-num uint))
  (default-to {card-creator: tx-sender, royalty-percent: u0}
    (map-get? creator-royalties {card-id: card-num})))

;; Core Functions

(define-public (card-mint (card-num uint) (royalty-percent uint))
  (begin
    (asserts! (not (var-get tournament-mode)) ERR_TOURNAMENT_ACTIVE)
    (asserts! (validate-card-number card-num) ERR_INVALID_CARD_NUMBER)
    (asserts! (is-none (nft-get-owner? card-id card-num)) (err u200))
    (asserts! (<= royalty-percent MAX_CREATOR_ROYALTY) ERR_INVALID_CREATOR_ROYALTY)
    (try! (nft-mint? card-id card-num tx-sender))
    (map-set creator-royalties
      {card-id: card-num}
      {card-creator: tx-sender, royalty-percent: royalty-percent})
    (print {event: "card-created", card-num: card-num, creator: tx-sender})
    (ok true)))

(define-public (card-trade (card-num uint) (trade-value uint))
  (let ((owner (nft-get-owner? card-id card-num)))
    (begin
      (asserts! (not (var-get tournament-mode)) ERR_TOURNAMENT_ACTIVE)
      (asserts! (validate-card-number card-num) ERR_INVALID_CARD_NUMBER)
      (asserts! (is-some owner) (err u205))
      (asserts! (is-eq (some tx-sender) owner) (err u201))
      (asserts! (and (>= trade-value CARD_MIN_VALUE) (<= trade-value CARD_MAX_VALUE)) ERR_INVALID_TRADE_VALUE)
      (asserts! (not (is-card-trading card-num)) ERR_CARD_ALREADY_TRADING)
      (map-set card-marketplace
        {card-id: card-num}
        {trader: tx-sender, trade-value: trade-value, posted-at: stacks-block-height})
      (print {event: "card-posted-for-trade", card-num: card-num, value: trade-value, trader: tx-sender})
      (ok true))))

(define-public (update-trade-value (card-num uint) (new-value uint))
  (let (
    (trade-info (unwrap! (map-get? card-marketplace {card-id: card-num}) ERR_CARD_NOT_TRADEABLE))
    (current-height stacks-block-height)
  )
    (begin
      (asserts! (not (var-get tournament-mode)) ERR_TOURNAMENT_ACTIVE)
      (asserts! (validate-card-number card-num) ERR_INVALID_CARD_NUMBER)
      (asserts! (is-eq tx-sender (get trader trade-info)) ERR_PERMISSION_DENIED)
      (asserts! (and (>= new-value CARD_MIN_VALUE) (<= new-value CARD_MAX_VALUE)) ERR_INVALID_TRADE_VALUE)
      (asserts! (>= (- current-height (get posted-at trade-info)) TRADE_UPDATE_INTERVAL) ERR_TRADE_UPDATE_BLOCKED)
      (map-set card-marketplace
        {card-id: card-num}
        {trader: tx-sender, trade-value: new-value, posted-at: current-height})
      (print {event: "trade-value-updated", card-num: card-num, new-value: new-value})
      (ok true))))

(define-public (withdraw-from-trade (card-num uint))
  (let ((trade-info (unwrap! (map-get? card-marketplace {card-id: card-num}) ERR_CARD_NOT_TRADEABLE)))
    (begin
      (asserts! (not (var-get tournament-mode)) ERR_TOURNAMENT_ACTIVE)
      (asserts! (validate-card-number card-num) ERR_INVALID_CARD_NUMBER)
      (asserts! (is-eq tx-sender (get trader trade-info)) ERR_PERMISSION_DENIED)
      (map-delete card-marketplace {card-id: card-num})
      (print {event: "card-withdrawn-from-trade", card-num: card-num})
      (ok true))))

(define-public (card-collect (card-num uint))
  (let (
    (trade-info (unwrap! (map-get? card-marketplace {card-id: card-num}) ERR_CARD_NOT_TRADEABLE))
    (royalty-data (default-to {card-creator: tx-sender, royalty-percent: u0} 
      (map-get? creator-royalties {card-id: card-num})))
    (collector tx-sender)
    (current-trader (get trader trade-info))
  )
    (begin
      (asserts! (not (var-get tournament-mode)) ERR_TOURNAMENT_ACTIVE)
      (asserts! (validate-card-number card-num) ERR_INVALID_CARD_NUMBER)
      (asserts! (not (is-eq collector current-trader)) ERR_CANNOT_TRADE_WITH_SELF)
      (asserts! (is-some (nft-get-owner? card-id card-num)) (err u209))
      (let (
        (value (get trade-value trade-info))
        (creator-cut (calculate-creator-cut value (get royalty-percent royalty-data)))
        (trader-payment (- value creator-cut))
      )
        (asserts! (>= (stx-get-balance collector) value) ERR_INSUFFICIENT_TOKENS)
        ;; Transfer creator royalty if applicable
        (if (> creator-cut u0)
          (try! (stx-transfer? creator-cut collector (get card-creator royalty-data)))
          true)
        ;; Transfer remaining amount to trader
        (try! (stx-transfer? trader-payment collector current-trader))
        ;; Transfer NFT to collector
        (match (nft-transfer? card-id card-num current-trader collector)
          success (begin
            (map-delete card-marketplace {card-id: card-num})
            (print {
              event: "card-collected",
              card-num: card-num,
              collector: collector,
              trader: current-trader,
              value: value,
              creator-cut: creator-cut
            })
            (ok true))
          error (begin
            (try! (stx-transfer? value current-trader collector))
            ERR_COLLECTION_FAILED))))))

(define-public (gift-card (card-num uint) (recipient principal))
  (let ((owner (nft-get-owner? card-id card-num)))
    (begin
      (asserts! (not (var-get tournament-mode)) ERR_TOURNAMENT_ACTIVE)
      (asserts! (validate-card-number card-num) ERR_INVALID_CARD_NUMBER)
      (asserts! (is-some owner) (err u206))
      (asserts! (is-eq (some tx-sender) owner) (err u204))
      (asserts! (not (is-eq recipient tx-sender)) ERR_CANNOT_TRADE_WITH_SELF)
      (try! (nft-transfer? card-id card-num tx-sender recipient))
      (print {event: "card-gifted", card-num: card-num, from: tx-sender, to: recipient})
      (ok true))))