;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-found (err u404))
(define-constant err-already-exists (err u409))
(define-constant err-unauthorized (err u401))
(define-constant err-invalid-input (err u400))
(define-constant err-already-voted (err u403))

;; Data structures
(define-map trends
  { trend-id: uint }
  {
    author: principal,
    title: (string-utf8 280),
    description: (string-utf8 1000),
    tags: (list 5 (string-utf8 50)),
    upvotes: uint,
    downvotes: uint,
    created-at: uint
  }
)

(define-map user-stats
  { user: principal }
  {
    trends-created: uint,
    reputation: int,
    following: (list 100 principal)
  }
)

(define-map user-votes
  { user: principal, trend-id: uint }
  { voted: bool, is-upvote: bool }
)

(define-data-var next-trend-id uint u0)

;; Private functions
(define-private (is-valid-string (value (string-utf8 280)))
  (not (is-eq value ""))
)

;; Public functions
(define-public (create-trend (title (string-utf8 280)) (description (string-utf8 1000)) (tags (list 5 (string-utf8 50))))
  (begin
    (asserts! (is-valid-string title) err-invalid-input)
    (asserts! (is-valid-string description) err-invalid-input)
    (let
      (
        (trend-id (var-get next-trend-id))
        (user-stat (default-to { trends-created: u0, reputation: 0, following: (list) } (map-get? user-stats { user: tx-sender })))
      )
      (map-set trends
        { trend-id: trend-id }
        {
          author: tx-sender,
          title: title,
          description: description,
          tags: tags,
          upvotes: u0,
          downvotes: u0,
          created-at: block-height
        }
      )
      (map-set user-stats
        { user: tx-sender }
        (merge user-stat { trends-created: (+ (get trends-created user-stat) u1) })
      )
      (var-set next-trend-id (+ trend-id u1))
      (ok trend-id)
    )
  )
)

(define-public (vote (trend-id uint) (is-upvote bool))
  (let
    (
      (trend (unwrap! (map-get? trends { trend-id: trend-id }) err-not-found))
      (author (get author trend))
      (previous-vote (map-get? user-votes { user: tx-sender, trend-id: trend-id }))
    )
    (asserts! (not (is-eq tx-sender author)) err-unauthorized)
    (asserts! (is-none previous-vote) err-already-voted)
    (let
      (
        (author-stats (default-to { trends-created: u0, reputation: 0, following: (list) } (map-get? user-stats { user: author })))
      )
      (map-set user-votes
        { user: tx-sender, trend-id: trend-id }
        { voted: true, is-upvote: is-upvote }
      )
      (if is-upvote
        (begin
          (map-set trends { trend-id: trend-id } (merge trend { upvotes: (+ (get upvotes trend) u1) }))
          (map-set user-stats { user: author } (merge author-stats { reputation: (+ (get reputation author-stats) 1) }))
        )
        (begin
          (map-set trends { trend-id: trend-id } (merge trend { downvotes: (+ (get downvotes trend) u1) }))
          (map-set user-stats { user: author } (merge author-stats { reputation: (- (get reputation author-stats) 1) }))
        )
      )
      (ok true)
    )
  )
)

(define-public (follow (user principal))
  (begin
    (asserts! (not (is-eq tx-sender user)) err-unauthorized)
    (let
      (
        (current-stats (default-to { trends-created: u0, reputation: 0, following: (list) } (map-get? user-stats { user: tx-sender })))
      )
      (map-set user-stats
        { user: tx-sender }
        (merge current-stats { following: (unwrap! (as-max-len? (append (get following current-stats) user) u100) err-unauthorized) })
      )
      (ok true)
    )
  )
)

;; Read only functions
(define-read-only (get-trend (trend-id uint))
  (ok (map-get? trends { trend-id: trend-id }))
)

(define-read-only (get-user-stats (user principal))
  (ok (map-get? user-stats { user: user }))
)

(define-read-only (get-user-vote (user principal) (trend-id uint))
  (ok (map-get? user-votes { user: user, trend-id: trend-id }))
)
