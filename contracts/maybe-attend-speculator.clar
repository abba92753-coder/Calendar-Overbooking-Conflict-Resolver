;; title: maybe-attend-speculator
;; version: 1.0.0
;; summary: Manages probabilistic RSVP options for events.
;; description: Allows organizers to register events and participants to submit
;;              "maybe" RSVPs with explicit confidence scores, as well as
;;              definitive yes/no responses. No cross-contract calls.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; error codes
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-constant ERR-EVENT-EXISTS u100)
(define-constant ERR-EVENT-NOT-FOUND u101)
(define-constant ERR-CONFIDENCE-OUT-OF-RANGE u102)
(define-constant ERR-INVALID-WINDOW u103)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; status constants
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-constant STATUS-MAYBE "maybe")
(define-constant STATUS-YES "yes")
(define-constant STATUS-NO "no")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; data maps
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; events
;; - event-id: application-specific identifier for the calendar item
;; - organizer: principal that registered the event
;; - start-height / end-height: conceptual block window for the event
;; - title: short label for the meeting or event
(define-map events
  {event-id: uint}
  {organizer: principal,
   start-height: uint,
   end-height: uint,
   title: (string-ascii 64)})

;; rsvps
;; - (event-id, attendee) composite key
;; - status: one of STATUS-MAYBE, STATUS-YES, STATUS-NO
;; - confidence: 0-100 percentage, only meaningful for "maybe" but always stored
;; - updated-at: block-height when the RSVP was last changed
(define-map rsvps
  {event-id: uint, attendee: principal}
  {status: (string-ascii 8),
   confidence: uint,
   updated-at: uint})


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; read-only helpers
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-read-only (get-event (event-id uint))
  ;; Returns the full event record for the given identifier, if any.
  (map-get? events {event-id: event-id}))

(define-read-only (get-rsvp (event-id uint) (who principal))
  ;; Returns RSVP information for a particular attendee and event, if present.
  (map-get? rsvps {event-id: event-id, attendee: who}))

(define-read-only (get-confidence (event-id uint) (who principal))
  ;; Returns the stored confidence value for an attendee's RSVP.
  ;; If the RSVP does not exist, an error is returned.
  (match (map-get? rsvps {event-id: event-id, attendee: who})
    rsvp-record (ok (get confidence rsvp-record))
    (err ERR-EVENT-NOT-FOUND)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; private validation helpers
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-private (assert-event-exists (event-id uint))
  ;; Ensures that the event with the given identifier has been registered.
  (if (is-none (map-get? events {event-id: event-id}))
      (err ERR-EVENT-NOT-FOUND)
      (ok true)))

(define-private (assert-confidence (confidence uint))
  ;; Ensures that the confidence value is in the inclusive range [0, 100].
  (if (> confidence u100)
      (err ERR-CONFIDENCE-OUT-OF-RANGE)
      (ok true)))

(define-private (set-rsvp
    (event-id uint)
    (attendee principal)
    (status (string-ascii 8))
    (confidence uint))
  ;; Shared internal routine to upsert RSVP records.
  (begin
    (try! (assert-event-exists event-id))
    (try! (assert-confidence confidence))
    (map-set rsvps
      {event-id: event-id, attendee: attendee}
      {status: status, confidence: confidence, updated-at: u0})
    (ok true)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; public functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-public (register-event
    (event-id uint)
    (title (string-ascii 64))
    (start-height uint)
    (end-height uint))
  ;; Registers a new event. Fails if:
  ;; - an event with the same identifier already exists, or
  ;; - the start block-height is not strictly less than the end block-height.
  (begin
    (if (>= start-height end-height)
        (err ERR-INVALID-WINDOW)
        (if (is-some (map-get? events {event-id: event-id}))
            (err ERR-EVENT-EXISTS)
            (begin
              (map-set events {event-id: event-id}
                {organizer: tx-sender,
                 start-height: start-height,
                 end-height: end-height,
                 title: title})
              (ok event-id))))))

(define-public (rsvp-maybe (event-id uint) (confidence uint))
  ;; Submit or update a "maybe" RSVP with an explicit confidence value.
  (set-rsvp event-id tx-sender STATUS-MAYBE confidence))

(define-public (rsvp-yes (event-id uint))
  ;; Submit a definitive "yes" RSVP. Confidence is fixed to 100.
  (set-rsvp event-id tx-sender STATUS-YES u100))

(define-public (rsvp-no (event-id uint))
  ;; Submit a definitive "no" RSVP. Confidence is fixed to 0.
  (set-rsvp event-id tx-sender STATUS-NO u0))

(define-public (cancel-rsvp (event-id uint))
  ;; Removes any RSVP the sender has for the event, if present.
  (begin
    (try! (assert-event-exists event-id))
    (map-delete rsvps {event-id: event-id, attendee: tx-sender})
    (ok true)))
