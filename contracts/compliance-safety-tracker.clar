;; Compliance Safety Tracker Contract
;; Tracks regulatory compliance, safety violations, hours of service compliance,
;; vehicle inspections, driver certifications, and safety performance metrics

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u800))
(define-constant ERR_COMPLIANCE_RECORD_NOT_FOUND (err u801))
(define-constant ERR_INSPECTION_NOT_FOUND (err u802))
(define-constant ERR_VIOLATION_NOT_FOUND (err u803))
(define-constant ERR_INVALID_PARAMETERS (err u804))
(define-constant ERR_CERTIFICATION_EXPIRED (err u805))
(define-constant ERR_HOS_VIOLATION (err u806))
(define-constant ERR_VEHICLE_OUT_OF_SERVICE (err u807))
(define-constant ERR_DRIVER_SUSPENDED (err u808))

;; Data Variables
(define-data-var next-compliance-id uint u1)
(define-data-var next-inspection-id uint u1)
(define-data-var next-violation-id uint u1)
(define-data-var next-certification-id uint u1)
(define-data-var next-incident-id uint u1)
(define-data-var contract-paused bool false)
(define-data-var max-driving-hours uint u11) ;; 11 hours maximum driving per day
(define-data-var max-duty-hours uint u14) ;; 14 hours maximum duty per day
(define-data-var required-rest-hours uint u10) ;; 10 hours rest required
(define-data-var inspection-validity-period uint u7776000) ;; 90 days
(define-data-var safety-score-threshold uint u75) ;; 75% minimum safety score

;; Data Maps

;; Hours of Service compliance tracking
(define-map hos-compliance
  { driver-id: uint, date: uint }
  {
    driver-id: uint,
    date: uint,
    start-time: uint,
    end-time: (optional uint),
    total-driving-time: uint,
    total-duty-time: uint,
    break-time: uint,
    rest-time: uint,
    violations: (list 10 (string-ascii 64)),
    status: (string-ascii 16),
    supervisor: principal,
    last-updated: uint
  }
)

;; Vehicle inspection records
(define-map vehicle-inspections
  { inspection-id: uint }
  {
    vehicle-id: uint,
    inspection-type: (string-ascii 32),
    inspection-date: uint,
    inspector-name: (string-ascii 128),
    inspector-license: (string-ascii 32),
    odometer-reading: uint,
    defects-found: (list 20 (string-ascii 128)),
    repairs-needed: (list 20 (string-ascii 128)),
    pass-status: bool,
    next-inspection-due: uint,
    certificate-number: (string-ascii 32),
    inspection-location: (string-ascii 128),
    cost: uint,
    status: (string-ascii 16)
  }
)

;; Safety violations and incidents
(define-map safety-violations
  { violation-id: uint }
  {
    driver-id: uint,
    vehicle-id: uint,
    violation-type: (string-ascii 64),
    violation-date: uint,
    location: (string-ascii 128),
    description: (string-ascii 256),
    severity: (string-ascii 16),
    fine-amount: uint,
    points: uint,
    officer-name: (string-ascii 128),
    ticket-number: (string-ascii 32),
    court-date: (optional uint),
    resolution-status: (string-ascii 16),
    resolution-date: (optional uint)
  }
)

;; Driver certifications and qualifications
(define-map driver-certifications
  { certification-id: uint }
  {
    driver-id: uint,
    certification-type: (string-ascii 64),
    issuing-authority: (string-ascii 128),
    certificate-number: (string-ascii 32),
    issue-date: uint,
    expiry-date: uint,
    renewal-date: (optional uint),
    status: (string-ascii 16),
    restrictions: (string-ascii 256),
    endorsements: (list 10 (string-ascii 32))
  }
)

;; Regulatory compliance records
(define-map regulatory-compliance
  { compliance-id: uint }
  {
    entity-id: uint,
    entity-type: (string-ascii 16), ;; "driver" or "vehicle" or "fleet"
    regulation-type: (string-ascii 64),
    compliance-date: uint,
    compliance-status: (string-ascii 16),
    expiry-date: uint,
    renewal-required: bool,
    documentation: (string-ascii 256),
    responsible-party: principal,
    next-audit-date: uint,
    compliance-score: uint
  }
)

;; Safety incidents and accidents
(define-map safety-incidents
  { incident-id: uint }
  {
    driver-id: uint,
    vehicle-id: uint,
    incident-date: uint,
    incident-time: uint,
    location: (string-ascii 128),
    incident-type: (string-ascii 64),
    severity: (string-ascii 16),
    injuries: uint,
    fatalities: uint,
    property-damage: uint,
    weather-conditions: (string-ascii 64),
    road-conditions: (string-ascii 64),
    description: (string-ascii 512),
    police-report-number: (string-ascii 32),
    insurance-claim: (string-ascii 32),
    investigation-status: (string-ascii 16)
  }
)

;; Vehicle maintenance compliance
(define-map maintenance-compliance
  { vehicle-id: uint, maintenance-type: (string-ascii 32) }
  {
    last-service-date: uint,
    next-service-due: uint,
    service-interval: uint,
    compliance-status: (string-ascii 16),
    overdue-days: uint,
    service-provider: (string-ascii 128),
    certification-required: bool,
    parts-warranty: uint
  }
)

;; Driver training and safety records
(define-map driver-training
  { driver-id: uint, training-type: (string-ascii 64) }
  {
    training-date: uint,
    trainer-name: (string-ascii 128),
    training-duration: uint,
    completion-status: bool,
    certification-earned: (string-ascii 64),
    expiry-date: uint,
    refresher-required: bool,
    next-training-due: uint,
    training-location: (string-ascii 128),
    cost: uint
  }
)

;; Fleet safety performance metrics
(define-map fleet-safety-metrics
  { fleet-id: (string-ascii 32), period: uint }
  {
    total-miles: uint,
    accidents-per-mile: uint,
    violations-count: uint,
    safety-score: uint,
    compliance-rate: uint,
    training-completion-rate: uint,
    inspection-pass-rate: uint,
    hos-compliance-rate: uint,
    period-start: uint,
    period-end: uint
  }
)

;; Admin Functions

;; Set maximum driving hours
(define-public (set-max-driving-hours (hours uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (and (> hours u0) (<= hours u24)) ERR_INVALID_PARAMETERS)
    (var-set max-driving-hours hours)
    (ok true)
  )
)

;; Set safety score threshold
(define-public (set-safety-threshold (threshold uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= threshold u100) ERR_INVALID_PARAMETERS)
    (var-set safety-score-threshold threshold)
    (ok true)
  )
)

;; Pause/unpause contract
(define-public (toggle-contract-pause)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set contract-paused (not (var-get contract-paused)))
    (ok (var-get contract-paused))
  )
)

;; Hours of Service Functions

;; Record hours of service
(define-public (record-hos
                (driver-id uint)
                (date uint)
                (start-time uint)
                (total-driving-time uint)
                (total-duty-time uint)
                (break-time uint)
                (rest-time uint))
  (let
    (
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
      (empty-violations (list))
      (has-driving-violation (> total-driving-time (* (var-get max-driving-hours) u3600)))
      (has-duty-violation (> total-duty-time (* (var-get max-duty-hours) u3600)))
      (has-rest-violation (< rest-time (* (var-get required-rest-hours) u3600)))
      (final-violations (if has-driving-violation 
                          (list "driving-time-exceeded")
                          (if has-duty-violation
                            (list "duty-time-exceeded")
                            (if has-rest-violation
                              (list "insufficient-rest")
                              empty-violations
                            )
                          )
                        ))
    )
    (asserts! (not (var-get contract-paused)) (err u999))
    (asserts! (> total-driving-time u0) ERR_INVALID_PARAMETERS)
    (asserts! (>= total-duty-time total-driving-time) ERR_INVALID_PARAMETERS)
    
    (map-set hos-compliance
      { driver-id: driver-id, date: date }
      {
        driver-id: driver-id,
        date: date,
        start-time: start-time,
        end-time: (some (+ start-time total-duty-time)),
        total-driving-time: total-driving-time,
        total-duty-time: total-duty-time,
        break-time: break-time,
        rest-time: rest-time,
        violations: final-violations,
        status: (if (or has-driving-violation has-duty-violation has-rest-violation) "violation" "compliant"),
        supervisor: tx-sender,
        last-updated: current-time
      }
    )
    
    (if (or has-driving-violation has-duty-violation has-rest-violation)
      ERR_HOS_VIOLATION
      (ok true)
    )
  )
)

;; Vehicle Inspection Functions

;; Record vehicle inspection
(define-public (record-inspection
                (vehicle-id uint)
                (inspection-type (string-ascii 32))
                (inspector-name (string-ascii 128))
                (inspector-license (string-ascii 32))
                (odometer-reading uint)
                (defects (list 20 (string-ascii 128)))
                (repairs-needed (list 20 (string-ascii 128)))
                (pass-status bool)
                (certificate-number (string-ascii 32))
                (inspection-location (string-ascii 128))
                (cost uint))
  (let
    (
      (inspection-id (var-get next-inspection-id))
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
      (next-due (+ current-time (var-get inspection-validity-period)))
    )
    (asserts! (not (var-get contract-paused)) (err u999))
    (asserts! (> (len inspector-name) u0) ERR_INVALID_PARAMETERS)
    (asserts! (> odometer-reading u0) ERR_INVALID_PARAMETERS)
    
    (map-set vehicle-inspections
      { inspection-id: inspection-id }
      {
        vehicle-id: vehicle-id,
        inspection-type: inspection-type,
        inspection-date: current-time,
        inspector-name: inspector-name,
        inspector-license: inspector-license,
        odometer-reading: odometer-reading,
        defects-found: defects,
        repairs-needed: repairs-needed,
        pass-status: pass-status,
        next-inspection-due: next-due,
        certificate-number: certificate-number,
        inspection-location: inspection-location,
        cost: cost,
        status: (if pass-status "passed" "failed")
      }
    )
    
    (var-set next-inspection-id (+ inspection-id u1))
    (if pass-status
      (ok inspection-id)
      ERR_VEHICLE_OUT_OF_SERVICE
    )
  )
)

;; Safety Violation Functions

;; Record safety violation
(define-public (record-violation
                (driver-id uint)
                (vehicle-id uint)
                (violation-type (string-ascii 64))
                (location (string-ascii 128))
                (description (string-ascii 256))
                (severity (string-ascii 16))
                (fine-amount uint)
                (points uint)
                (officer-name (string-ascii 128))
                (ticket-number (string-ascii 32)))
  (let
    (
      (violation-id (var-get next-violation-id))
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
    )
    (asserts! (not (var-get contract-paused)) (err u999))
    (asserts! (> (len violation-type) u0) ERR_INVALID_PARAMETERS)
    (asserts! (> (len description) u0) ERR_INVALID_PARAMETERS)
    
    (map-set safety-violations
      { violation-id: violation-id }
      {
        driver-id: driver-id,
        vehicle-id: vehicle-id,
        violation-type: violation-type,
        violation-date: current-time,
        location: location,
        description: description,
        severity: severity,
        fine-amount: fine-amount,
        points: points,
        officer-name: officer-name,
        ticket-number: ticket-number,
        court-date: none,
        resolution-status: "pending",
        resolution-date: none
      }
    )
    
    (var-set next-violation-id (+ violation-id u1))
    (ok violation-id)
  )
)

;; Update violation resolution
(define-public (resolve-violation (violation-id uint) (resolution-status (string-ascii 16)))
  (let
    (
      (violation (unwrap! (map-get? safety-violations { violation-id: violation-id }) ERR_VIOLATION_NOT_FOUND))
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
    )
    (asserts! (not (var-get contract-paused)) (err u999))
    (asserts! (is-eq (get resolution-status violation) "pending") ERR_INVALID_PARAMETERS)
    
    (map-set safety-violations
      { violation-id: violation-id }
      (merge violation {
        resolution-status: resolution-status,
        resolution-date: (some current-time)
      })
    )
    (ok true)
  )
)

;; Driver Certification Functions

;; Add driver certification
(define-public (add-certification
                (driver-id uint)
                (certification-type (string-ascii 64))
                (issuing-authority (string-ascii 128))
                (certificate-number (string-ascii 32))
                (issue-date uint)
                (expiry-date uint)
                (restrictions (string-ascii 256))
                (endorsements (list 10 (string-ascii 32))))
  (let
    (
      (certification-id (var-get next-certification-id))
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
    )
    (asserts! (not (var-get contract-paused)) (err u999))
    (asserts! (> expiry-date current-time) ERR_INVALID_PARAMETERS)
    (asserts! (> (len certification-type) u0) ERR_INVALID_PARAMETERS)
    
    (map-set driver-certifications
      { certification-id: certification-id }
      {
        driver-id: driver-id,
        certification-type: certification-type,
        issuing-authority: issuing-authority,
        certificate-number: certificate-number,
        issue-date: issue-date,
        expiry-date: expiry-date,
        renewal-date: none,
        status: "active",
        restrictions: restrictions,
        endorsements: endorsements
      }
    )
    
    (var-set next-certification-id (+ certification-id u1))
    (ok certification-id)
  )
)

;; Safety Incident Functions

;; Record safety incident
(define-public (record-incident
                (driver-id uint)
                (vehicle-id uint)
                (incident-time uint)
                (location (string-ascii 128))
                (incident-type (string-ascii 64))
                (severity (string-ascii 16))
                (injuries uint)
                (fatalities uint)
                (property-damage uint)
                (weather-conditions (string-ascii 64))
                (road-conditions (string-ascii 64))
                (description (string-ascii 512))
                (police-report-number (string-ascii 32))
                (insurance-claim (string-ascii 32)))
  (let
    (
      (incident-id (var-get next-incident-id))
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
    )
    (asserts! (not (var-get contract-paused)) (err u999))
    (asserts! (> (len incident-type) u0) ERR_INVALID_PARAMETERS)
    (asserts! (> (len description) u0) ERR_INVALID_PARAMETERS)
    
    (map-set safety-incidents
      { incident-id: incident-id }
      {
        driver-id: driver-id,
        vehicle-id: vehicle-id,
        incident-date: current-time,
        incident-time: incident-time,
        location: location,
        incident-type: incident-type,
        severity: severity,
        injuries: injuries,
        fatalities: fatalities,
        property-damage: property-damage,
        weather-conditions: weather-conditions,
        road-conditions: road-conditions,
        description: description,
        police-report-number: police-report-number,
        insurance-claim: insurance-claim,
        investigation-status: "pending"
      }
    )
    
    (var-set next-incident-id (+ incident-id u1))
    (ok incident-id)
  )
)

;; Read Functions

;; Get HOS compliance record
(define-read-only (get-hos-record (driver-id uint) (date uint))
  (ok (map-get? hos-compliance { driver-id: driver-id, date: date }))
)

;; Get vehicle inspection
(define-read-only (get-inspection (inspection-id uint))
  (ok (map-get? vehicle-inspections { inspection-id: inspection-id }))
)

;; Get safety violation
(define-read-only (get-violation (violation-id uint))
  (ok (map-get? safety-violations { violation-id: violation-id }))
)

;; Get driver certification
(define-read-only (get-certification (certification-id uint))
  (ok (map-get? driver-certifications { certification-id: certification-id }))
)

;; Get safety incident
(define-read-only (get-incident (incident-id uint))
  (ok (map-get? safety-incidents { incident-id: incident-id }))
)

;; Check compliance status
(define-read-only (check-compliance-status (entity-id uint) (entity-type (string-ascii 16)))
  (let
    (
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
    )
    ;; Simplified compliance check - would aggregate multiple compliance records
    (ok {
      entity-id: entity-id,
      entity-type: entity-type,
      overall-status: "compliant",
      expiring-soon: false,
      violations-count: u0,
      last-check: current-time
    })
  )
)

;; Calculate safety score
(define-read-only (calculate-safety-score (driver-id uint) (period-start uint) (period-end uint))
  ;; Simplified calculation - would consider violations, incidents, training completion
  (let
    (
      (base-score u100)
    )
    (ok {
      driver-id: driver-id,
      period-start: period-start,
      period-end: period-end,
      safety-score: base-score,
      violations-count: u0,
      incidents-count: u0,
      training-up-to-date: true
    })
  )
)

;; Check certification validity
(define-read-only (check-certification-validity (certification-id uint))
  (match (map-get? driver-certifications { certification-id: certification-id })
    certification
    (let
      (
        (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
        (is-valid (> (get expiry-date certification) current-time))
        (expires-soon (< (- (get expiry-date certification) current-time) u2592000)) ;; 30 days
      )
      (ok {
        certification-id: certification-id,
        is-valid: is-valid,
        expires-soon: expires-soon,
        days-until-expiry: (if is-valid (/ (- (get expiry-date certification) current-time) u86400) u0),
        status: (get status certification)
      })
    )
    ERR_CERTIFICATION_EXPIRED
  )
)

;; Generate compliance report
(define-read-only (generate-compliance-report (fleet-id (string-ascii 32)) (period uint))
  ;; Simplified report - would aggregate all compliance data for fleet
  (ok {
    fleet-id: fleet-id,
    period: period,
    overall-compliance-rate: u95,
    hos-compliance-rate: u98,
    inspection-pass-rate: u92,
    violation-count: u3,
    incident-count: u1,
    safety-score: u88
  })
)

;; title: compliance-safety-tracker
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
;;

;; public functions
;;

;; read only functions
;;

;; private functions
;;

