;; BugBounty Hunter DAO Contract
;; Description: A decentralized bug bounty platform where security researchers stake tokens and vote on vulnerability rewards

;; Contract constants
(define-constant PLATFORM_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u1))
(define-constant ERR_STAKE_REQUIRED (err u2))
(define-constant ERR_BOUNTY_INVALID (err u3))
(define-constant ERR_DUPLICATE_REVIEW (err u4))
(define-constant ERR_REVIEW_EXPIRED (err u5))
(define-constant ERR_COOLDOWN_ACTIVE (err u6))
(define-constant ERR_INPUT_ERROR (err u7))
(define-constant ERR_MINIMUM_NOT_MET (err u8))
(define-constant ERR_BOUNTY_UNKNOWN (err u9))

;; Manual Block Height Tracking
(define-data-var epoch_counter uint u0)
(define-data-var previous_actor principal tx-sender)

;; Epoch Progression Function
(define-public (progress_epoch)
    (begin
        ;; Prevent consecutive updates by same user
        (asserts! 
            (not (is-eq (var-get previous_actor) tx-sender)) 
            ERR_COOLDOWN_ACTIVE
        )

        ;; Advance epoch
        (var-set epoch_counter 
            (+ (var-get epoch_counter) u1)
        )

        ;; Track actor
        (var-set previous_actor tx-sender)

        (ok (var-get epoch_counter))
    )
)

;; Storage for security researcher stakes
(define-map researcher_registry 
    {researcher: principal} 
    {
        staked_tokens: uint,
        status_active: bool,
        registration_epoch: uint
    }
)

;; Storage for bug bounty submissions
(define-map vulnerability_reports
    {report_id: uint}
    {
        reporter_address: principal,
        bounty_payout: uint,
        review_count: uint,
        approval_tally: uint,
        payout_processed: bool,
        report_epoch: uint,
        review_cutoff: uint
    }
)

;; Track researcher reviews on bounties
(define-map review_ledger
    {researcher: principal, report_id: uint}
    {review_submitted: bool}
)

;; Track total bounty pool and next report ID
(define-data-var bounty_treasury uint u0)
(define-data-var report_sequence uint u1)

;; Review period constants
(define-constant REVIEW_WINDOW u144) ;; Approximately 24 hours 
(define-constant ACTIVE_PERIOD u1440) ;; Approximately 10 days
(define-constant MAXIMUM_BOUNTY u1000000000) ;; Maximum bounty payout

;; Validation helper functions
(define-read-only (report_exists (id uint))
    (is-some (map-get? vulnerability_reports {report_id: id}))
)

(define-read-only (valid_reporter (reporter principal))
    (and 
        (not (is-eq reporter (as-contract tx-sender)))
        (not (is-eq reporter 'SP000000000000000000002Q6VF78))
    )
)

(define-read-only (valid_bounty (amount uint))
    (and (> amount u0) (<= amount MAXIMUM_BOUNTY))
)

;; Researcher stake function
(define-public (stake_as_researcher (stake_amount uint))
    (let 
        (
            (epoch (var-get epoch_counter))
        )
        (begin
            ;; Validate input
            (asserts! (valid_bounty stake_amount) ERR_INPUT_ERROR)
            
            ;; Ensure minimum stake
            (asserts! (> stake_amount u0) ERR_STAKE_REQUIRED)

            ;; Transfer STX to contract
            (try! (stx-transfer? stake_amount tx-sender (as-contract tx-sender)))

            ;; Register researcher
            (map-set researcher_registry 
                {researcher: tx-sender} 
                {
                    staked_tokens: stake_amount,
                    status_active: true,
                    registration_epoch: epoch
                }
            )

            ;; Add to treasury
            (var-set bounty_treasury 
                (+ (var-get bounty_treasury) stake_amount)
            )

            (ok true)
        )
    )
)

;; Submit bug bounty claim
(define-public (file_vulnerability_report 
    (reporter_address principal) 
    (bounty_payout uint)
)
    (let 
        (
            (report_id (var-get report_sequence))
            (epoch (var-get epoch_counter))
            (researcher_data 
                (unwrap! 
                    (map-get? researcher_registry {researcher: tx-sender}) 
                    ERR_NOT_AUTHORIZED
                )
            )
            (cutoff (+ epoch REVIEW_WINDOW))
        )
        ;; Validate inputs
        (asserts! (valid_reporter reporter_address) ERR_INPUT_ERROR)
        (asserts! (valid_bounty bounty_payout) ERR_MINIMUM_NOT_MET)

        ;; Ensure researcher is active
        (asserts! (get status_active researcher_data) ERR_NOT_AUTHORIZED)

        ;; Ensure within active period
        (asserts! 
            (<= 
                (- epoch (get registration_epoch researcher_data)) 
                ACTIVE_PERIOD
            ) 
            ERR_REVIEW_EXPIRED
        )

        ;; Create bounty report
        (map-set vulnerability_reports 
            {report_id: report_id}
            {
                reporter_address: reporter_address,
                bounty_payout: bounty_payout,
                review_count: u0,
                approval_tally: u0,
                payout_processed: false,
                report_epoch: epoch,
                review_cutoff: cutoff
            }
        )

        ;; Increment report counter
        (var-set report_sequence (+ report_id u1))

        (ok report_id)
    )
)

;; Review bounty submission
(define-public (submit_review 
    (report_id uint) 
    (approve_bounty bool)
)
    (let 
        (
            (epoch (var-get epoch_counter))
            (validated_id (asserts! (report_exists report_id) ERR_BOUNTY_UNKNOWN))
            (report_data 
                (unwrap! 
                    (map-get? vulnerability_reports {report_id: report_id}) 
                    ERR_BOUNTY_INVALID
                )
            )
            (researcher_data 
                (unwrap! 
                    (map-get? researcher_registry {researcher: tx-sender}) 
                    ERR_NOT_AUTHORIZED
                )
            )
        )

        ;; Ensure review window is open
        (asserts! (< epoch (get review_cutoff report_data)) ERR_REVIEW_EXPIRED)

        ;; Prevent duplicate reviews
        (asserts! 
            (not (default-to false 
                (get review_submitted (map-get? review_ledger {researcher: tx-sender, report_id: report_id}))
            )) 
            ERR_DUPLICATE_REVIEW
        )

        ;; Update review counts
        (map-set vulnerability_reports 
            {report_id: report_id}
            (merge report_data 
                {
                    review_count: (+ (get review_count report_data) u1),
                    approval_tally: (if approve_bounty 
                        (+ (get approval_tally report_data) u1)
                        (get approval_tally report_data)
                    )
                }
            )
        )

        ;; Record review
        (map-set review_ledger 
            {researcher: tx-sender, report_id: report_id}
            {review_submitted: true}
        )

        (ok true)
    )
)

;; Read-only function to get current epoch
(define-read-only (get_epoch)
  (var-get epoch_counter)
)