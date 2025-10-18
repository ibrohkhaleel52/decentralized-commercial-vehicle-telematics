;; Compliance Safety Tracker Contract
;; Tracks commercial vehicle compliance and safety regulations
;; Manages driver certifications, hours of service, and regulatory adherence

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_INVALID_INPUT (err u400))
(define-constant ERR_ALREADY_EXISTS (err u409))
(define-constant ERR_COMPLIANCE_VIOLATION (err u422))
(define-constant MAX_DAILY_DRIVE_TIME u660) ;; 11 hours in minutes
(define-constant MAX_WEEKLY_DRIVE_TIME u4200) ;; 70 hours in minutes
(define-constant REQUIRED_REST_PERIOD u600) ;; 10 hours in minutes
(define-constant CERTIFICATION_VALIDITY_PERIOD u52560) ;; ~1 year in blocks

;; Data Variables
(define-data-var total-drivers uint u0)
(define-data-var total-violations uint u0)
(define-data-var contract-active bool true)
(define-data-var regulatory-authority principal tx-sender)

;; Driver Registration Map
(define-map drivers
    { driver-id: (string-ascii 20) }
    {
        driver-name: (string-ascii 50),
        license-number: (string-ascii 30),
        fleet-manager: principal,
        registration-date: uint,
        is-active: bool,
        total-violations: uint,
        last-medical-exam: uint,
        medical-cert-expiry: uint,
        last-training-date: uint
    }
)

;; Hours of Service Records Map
(define-map hos-records
    { record-id: (string-ascii 30) }
    {
        driver-id: (string-ascii 20),
        duty-start-time: uint,
        duty-end-time: uint,
        drive-time: uint,
        on-duty-time: uint,
        off-duty-time: uint,
        sleeper-berth-time: uint,
        vehicle-id: (string-ascii 20),
        violation-flags: (list 5 (string-ascii 20)),
        status: (string-ascii 15)
    }
)

;; Driver Certifications Map
(define-map driver-certifications
    { cert-id: (string-ascii 25) }
    {
        driver-id: (string-ascii 20),
        cert-type: (string-ascii 30),
        cert-authority: (string-ascii 50),
        issue-date: uint,
        expiry-date: uint,
        is-valid: bool,
        renewal-required: bool
    }
)

;; Safety Incidents Map
(define-map safety-incidents
    { incident-id: (string-ascii 25) }
    {
        driver-id: (string-ascii 20),
        vehicle-id: (string-ascii 20),
        incident-type: (string-ascii 20),
        severity: (string-ascii 10),
        description: (string-ascii 150),
        timestamp: uint,
        location: (string-ascii 100),
        reported-by: principal,
        investigation-status: (string-ascii 20),
        resolved: bool
    }
)

;; Compliance Violations Map
(define-map compliance-violations
    { violation-id: (string-ascii 25) }
    {
        driver-id: (string-ascii 20),
        violation-type: (string-ascii 30),
        regulation-code: (string-ascii 15),
        description: (string-ascii 150),
        timestamp: uint,
        fine-amount: uint,
        is-resolved: bool,
        resolution-date: uint,
        reported-by: principal
    }
)

;; Fleet Manager Access Map
(define-map authorized-managers
    { manager: principal }
    {
        company-name: (string-ascii 50),
        authorization-date: uint,
        is-authorized: bool,
        managed-drivers: uint
    }
)

;; Regulatory Inspections Map
(define-map regulatory-inspections
    { inspection-id: (string-ascii 25) }
    {
        inspector: principal,
        driver-id: (string-ascii 20),
        vehicle-id: (string-ascii 20),
        inspection-type: (string-ascii 30),
        inspection-date: uint,
        findings: (list 10 (string-ascii 50)),
        compliance-score: uint,
        follow-up-required: bool,
        next-inspection-due: uint
    }
)

;; Public Functions

;; Register Fleet Manager
(define-public (register-fleet-manager (company-name (string-ascii 50)))
    (let (
        (caller tx-sender)
    )
        (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
        (asserts! (is-none (map-get? authorized-managers {manager: caller})) ERR_ALREADY_EXISTS)
        (ok (map-set authorized-managers
            {manager: caller}
            {
                company-name: company-name,
                authorization-date: stacks-block-height,
                is-authorized: true,
                managed-drivers: u0
            }
        ))
    )
)

;; Register Driver
(define-public (register-driver
    (driver-id (string-ascii 20))
    (driver-name (string-ascii 50))
    (license-number (string-ascii 30))
    (medical-cert-expiry uint)
)
    (let (
        (caller tx-sender)
        (manager-info (map-get? authorized-managers {manager: caller}))
    )
        (asserts! (is-some manager-info) ERR_UNAUTHORIZED)
        (asserts! (get is-authorized (unwrap! manager-info ERR_UNAUTHORIZED)) ERR_UNAUTHORIZED)
        (asserts! (is-none (map-get? drivers {driver-id: driver-id})) ERR_ALREADY_EXISTS)
        (asserts! (> medical-cert-expiry stacks-block-height) ERR_INVALID_INPUT)
        
        (map-set drivers
            {driver-id: driver-id}
            {
                driver-name: driver-name,
                license-number: license-number,
                fleet-manager: caller,
                registration-date: stacks-block-height,
                is-active: true,
                total-violations: u0,
                last-medical-exam: stacks-block-height,
                medical-cert-expiry: medical-cert-expiry,
                last-training-date: stacks-block-height
            }
        )
        
        ;; Update manager's driver count
        (map-set authorized-managers
            {manager: caller}
            (merge (unwrap! manager-info ERR_NOT_FOUND)
                   {managed-drivers: (+ (get managed-drivers (unwrap! manager-info ERR_NOT_FOUND)) u1)}
            )
        )
        
        (var-set total-drivers (+ (var-get total-drivers) u1))
        (ok driver-id)
    )
)

;; Record Hours of Service
(define-public (record-hos-duty
    (record-id (string-ascii 30))
    (driver-id (string-ascii 20))
    (duty-start-time uint)
    (duty-end-time uint)
    (drive-time uint)
    (on-duty-time uint)
    (off-duty-time uint)
    (sleeper-berth-time uint)
    (vehicle-id (string-ascii 20))
)
    (let (
        (caller tx-sender)
        (driver-info (map-get? drivers {driver-id: driver-id}))
        (duty-duration (- duty-end-time duty-start-time))
        (violation-flags (check-hos-violations driver-id drive-time on-duty-time))
        (has-violations (> (len violation-flags) u0))
        (status (if has-violations "VIOLATION" "COMPLIANT"))
    )
        (asserts! (is-some driver-info) ERR_NOT_FOUND)
        (asserts! (is-eq caller (get fleet-manager (unwrap! driver-info ERR_NOT_FOUND))) ERR_UNAUTHORIZED)
        (asserts! (> duty-end-time duty-start-time) ERR_INVALID_INPUT)
        (asserts! (is-none (map-get? hos-records {record-id: record-id})) ERR_ALREADY_EXISTS)
        
        ;; Record HOS data
        (map-set hos-records
            {record-id: record-id}
            {
                driver-id: driver-id,
                duty-start-time: duty-start-time,
                duty-end-time: duty-end-time,
                drive-time: drive-time,
                on-duty-time: on-duty-time,
                off-duty-time: off-duty-time,
                sleeper-berth-time: sleeper-berth-time,
                vehicle-id: vehicle-id,
                violation-flags: violation-flags,
                status: status
            }
        )
        
        ;; Create violations if any and return result
        (begin
            (if has-violations
                (unwrap! (create-hos-violations driver-id violation-flags) ERR_INVALID_INPUT)
                true
            )
            (ok record-id)
        )
    )
)

;; Add Driver Certification
(define-public (add-certification
    (cert-id (string-ascii 25))
    (driver-id (string-ascii 20))
    (cert-type (string-ascii 30))
    (cert-authority (string-ascii 50))
    (expiry-date uint)
)
    (let (
        (caller tx-sender)
        (driver-info (map-get? drivers {driver-id: driver-id}))
    )
        (asserts! (is-some driver-info) ERR_NOT_FOUND)
        (asserts! (is-eq caller (get fleet-manager (unwrap! driver-info ERR_NOT_FOUND))) ERR_UNAUTHORIZED)
        (asserts! (> expiry-date stacks-block-height) ERR_INVALID_INPUT)
        (asserts! (is-none (map-get? driver-certifications {cert-id: cert-id})) ERR_ALREADY_EXISTS)
        
        (ok (map-set driver-certifications
            {cert-id: cert-id}
            {
                driver-id: driver-id,
                cert-type: cert-type,
                cert-authority: cert-authority,
                issue-date: stacks-block-height,
                expiry-date: expiry-date,
                is-valid: true,
                renewal-required: false
            }
        ))
    )
)

;; Report Safety Incident
(define-public (report-safety-incident
    (incident-id (string-ascii 25))
    (driver-id (string-ascii 20))
    (vehicle-id (string-ascii 20))
    (incident-type (string-ascii 20))
    (severity (string-ascii 10))
    (description (string-ascii 150))
    (location (string-ascii 100))
)
    (let (
        (caller tx-sender)
        (driver-info (map-get? drivers {driver-id: driver-id}))
    )
        (asserts! (is-some driver-info) ERR_NOT_FOUND)
        (asserts! (is-none (map-get? safety-incidents {incident-id: incident-id})) ERR_ALREADY_EXISTS)
        
        (map-set safety-incidents
            {incident-id: incident-id}
            {
                driver-id: driver-id,
                vehicle-id: vehicle-id,
                incident-type: incident-type,
                severity: severity,
                description: description,
                timestamp: stacks-block-height,
                location: location,
                reported-by: caller,
                investigation-status: "PENDING",
                resolved: false
            }
        )
        
        ;; Update driver violation count for serious incidents and return result
        (begin
            (if (or (is-eq severity "HIGH") (is-eq severity "CRITICAL"))
                (unwrap! (increment-driver-violations driver-id) ERR_NOT_FOUND)
                true
            )
            (ok incident-id)
        )
    )
)

;; Record Regulatory Inspection
(define-public (record-inspection
    (inspection-id (string-ascii 25))
    (driver-id (string-ascii 20))
    (vehicle-id (string-ascii 20))
    (inspection-type (string-ascii 30))
    (findings (list 10 (string-ascii 50)))
    (compliance-score uint)
    (follow-up-required bool)
    (next-inspection-due uint)
)
    (let (
        (caller tx-sender)
    )
        (asserts! (is-eq caller (var-get regulatory-authority)) ERR_UNAUTHORIZED)
        (asserts! (is-none (map-get? regulatory-inspections {inspection-id: inspection-id})) ERR_ALREADY_EXISTS)
        (asserts! (<= compliance-score u100) ERR_INVALID_INPUT)
        
        (ok (map-set regulatory-inspections
            {inspection-id: inspection-id}
            {
                inspector: caller,
                driver-id: driver-id,
                vehicle-id: vehicle-id,
                inspection-type: inspection-type,
                inspection-date: stacks-block-height,
                findings: findings,
                compliance-score: compliance-score,
                follow-up-required: follow-up-required,
                next-inspection-due: next-inspection-due
            }
        ))
    )
)

;; Read-Only Functions

;; Get Driver Information
(define-read-only (get-driver-info (driver-id (string-ascii 20)))
    (map-get? drivers {driver-id: driver-id})
)

;; Get HOS Record
(define-read-only (get-hos-record (record-id (string-ascii 30)))
    (map-get? hos-records {record-id: record-id})
)

;; Get Driver Certification
(define-read-only (get-certification (cert-id (string-ascii 25)))
    (map-get? driver-certifications {cert-id: cert-id})
)

;; Get Safety Incident
(define-read-only (get-safety-incident (incident-id (string-ascii 25)))
    (map-get? safety-incidents {incident-id: incident-id})
)

;; Get Compliance Violation
(define-read-only (get-violation (violation-id (string-ascii 25)))
    (map-get? compliance-violations {violation-id: violation-id})
)

;; Get Regulatory Inspection
(define-read-only (get-inspection (inspection-id (string-ascii 25)))
    (map-get? regulatory-inspections {inspection-id: inspection-id})
)

;; Check Driver Compliance Status
(define-read-only (get-driver-compliance-status (driver-id (string-ascii 20)))
    (match (map-get? drivers {driver-id: driver-id})
        driver-info
        (let (
            (medical-valid (> (get medical-cert-expiry driver-info) stacks-block-height))
            (violation-count (get total-violations driver-info))
            (compliance-score (if medical-valid
                                (if (< violation-count u5) u90 u70)
                                u40))
        )
            (some {
                medical-cert-valid: medical-valid,
                total-violations: violation-count,
                compliance-score: compliance-score,
                status: (if (and medical-valid (< violation-count u10)) "COMPLIANT" "NON-COMPLIANT")
            })
        )
        none
    )
)

;; Get Contract Statistics
(define-read-only (get-contract-stats)
    {
        total-drivers: (var-get total-drivers),
        total-violations: (var-get total-violations),
        contract-active: (var-get contract-active),
        regulatory-authority: (var-get regulatory-authority)
    }
)

;; Private Functions

;; Check HOS Violations
(define-private (check-hos-violations (driver-id (string-ascii 20)) (drive-time uint) (on-duty-time uint))
    (let (
        (violations (list))
    )
        ;; Check daily drive time limit
        (if (> drive-time MAX_DAILY_DRIVE_TIME)
            (unwrap-panic (as-max-len? (append violations "DAILY_DRIVE_LIMIT") u5))
            violations
        )
        ;; Additional violation checks would go here
    )
)

;; Create HOS Violations
(define-private (create-hos-violations (driver-id (string-ascii 20)) (violation-types (list 5 (string-ascii 20))))
    (let (
        (violation-id (concat driver-id "-HOS-VIOLATION"))
    )
        (map-set compliance-violations
            {violation-id: (unwrap-panic (as-max-len? violation-id u25))}
            {
                driver-id: driver-id,
                violation-type: "HOS_VIOLATION",
                regulation-code: "395.8",
                description: "Hours of Service violation detected",
                timestamp: stacks-block-height,
                fine-amount: u500,
                is-resolved: false,
                resolution-date: u0,
                reported-by: tx-sender
            }
        )
        (var-set total-violations (+ (var-get total-violations) u1))
        (ok true)
    )
)

;; Increment Driver Violations
(define-private (increment-driver-violations (driver-id (string-ascii 20)))
    (match (map-get? drivers {driver-id: driver-id})
        driver-info
        (begin
            (map-set drivers
                {driver-id: driver-id}
                (merge driver-info
                       {total-violations: (+ (get total-violations driver-info) u1)}
                )
            )
            (ok true)
        )
        (err ERR_NOT_FOUND)
    )
)

