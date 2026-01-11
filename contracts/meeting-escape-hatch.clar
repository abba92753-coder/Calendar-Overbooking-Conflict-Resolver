;; title: meeting-escape-hatch
;; version: 1.0.0
;; summary: Records polite, cryptographically-plausible excuses for meetings.
;; description: Allows participants to declare and later trigger an escape hatch
;;              for a specific meeting. Each excuse is timestamped by
;;              block-height to provide an auditable trail.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; error codes
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-constant ERR-ESCAPE-ALREADY-REGISTERED u200)
(define-constant ERR-ESCAPE-NOT-FOUND u201)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; data maps
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; escape-hatches
;; - key: (meeting-id, participant)
;; - reason: human-readable explanation supplied by the participant
;; - declared-at: block-height when the excuse was first registered
;; - triggered: whether the escape hatch has been used
;; - triggered-at: optional block-height when the hatch was triggered
(define-map escape-hatches
  {meeting-id: uint, participant: principal}
  {reason: (string-utf8 128),
   declared-at: uint,
   triggered: bool,
   triggered-at: (optional uint)})


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; read-only helpers
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-read-only (get-escape (meeting-id uint) (who principal))
  ;; Returns the stored escape hatch record for the given meeting and
  ;; participant, if any.
  (map-get? escape-hatches {meeting-id: meeting-id, participant: who}))

(define-read-only (has-active-escape? (meeting-id uint) (who principal))
  ;; Returns true if a participant has declared an escape hatch that has not
  ;; yet been triggered.
  (match (map-get? escape-hatches {meeting-id: meeting-id, participant: who})
    record (and (not (get triggered record)) true)
    false))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; private helpers
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-private (assert-escape-exists (meeting-id uint) (who principal))
  ;; Ensures that an escape hatch exists for the given meeting and participant.
  (if (is-none (map-get? escape-hatches {meeting-id: meeting-id, participant: who}))
      (err ERR-ESCAPE-NOT-FOUND)
      (ok true)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; public functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-public (declare-escape
    (meeting-id uint)
    (reason (string-utf8 128)))
  ;; Registers a new escape hatch for the sender for a particular meeting.
  ;; Fails if an escape hatch already exists for this key.
  (if (is-some (map-get? escape-hatches {meeting-id: meeting-id, participant: tx-sender}))
      (err ERR-ESCAPE-ALREADY-REGISTERED)
      (begin
        (map-set escape-hatches
          {meeting-id: meeting-id, participant: tx-sender}
          {reason: reason,
           declared-at: u0,
           triggered: false,
           triggered-at: none})
        (ok true))))

(define-public (trigger-escape (meeting-id uint))
  ;; Marks an existing escape hatch as used. If it was already triggered,
  ;; the call succeeds but returns false to signal that no state changed.
  (begin
    (try! (assert-escape-exists meeting-id tx-sender))
    (match (map-get? escape-hatches {meeting-id: meeting-id, participant: tx-sender})
      record
        (if (get triggered record)
            (ok false)
            (begin
              (map-set escape-hatches
                {meeting-id: meeting-id, participant: tx-sender}
                {reason: (get reason record),
                 declared-at: (get declared-at record),
                 triggered: true,
                 triggered-at: (some u0)})
              (ok true)))
      (err ERR-ESCAPE-NOT-FOUND))))

(define-public (clear-escape (meeting-id uint))
  ;; Allows a participant to remove an escape hatch entirely, e.g. when a
  ;; conflict has been resolved and they no longer need the excuse.
  (begin
    (try! (assert-escape-exists meeting-id tx-sender))
    (map-delete escape-hatches {meeting-id: meeting-id, participant: tx-sender})
    (ok true)))
