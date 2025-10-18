;; Commercial Vehicle Performance Monitor Contract
;; Monitors vehicle performance, fuel consumption, and driver behavior
;; Provides analytics and optimization recommendations for fleet management

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_INVALID_INPUT (err u400))
(define-constant ERR_ALREADY_EXISTS (err u409))
(define-constant MIN_FUEL_EFFICIENCY u10) ;; Minimum fuel efficiency threshold
(define-constant MAX_SPEED_LIMIT u120) ;; Maximum speed limit in km/h
(define-constant PERFORMANCE_SCORE_MULTIPLIER u100)

;; Data Variables
(define-data-var total-vehicles uint u0)
(define-data-var total-trips uint u0)
(define-data-var contract-active bool true)

;; Vehicle Registration Map
(define-map vehicles
    { vehicle-id: (string-ascii 20) }
    {
        fleet-manager: principal,
        driver-id: (string-ascii 20),
        make-model: (string-ascii 50),
        registration-date: uint,
        is-active: bool,
        total-distance: uint,
        total-fuel-consumed: uint,
        maintenance-due: uint
    }
)

;; Trip Records Map
(define-map trip-records
    { trip-id: (string-ascii 30) }
    {
        vehicle-id: (string-ascii 20),
        driver-id: (string-ascii 20),
        start-time: uint,
        end-time: uint,
        distance: uint,
        fuel-consumed: uint,
        avg-speed: uint,
        max-speed: uint,
        harsh-braking: uint,
        harsh-acceleration: uint,
        idle-time: uint,
        performance-score: uint
    }
)

;; Driver Performance Map
(define-map driver-performance
    { driver-id: (string-ascii 20) }
    {
        total-trips: uint,
        total-distance: uint,
        total-fuel-consumed: uint,
        avg-performance-score: uint,
        safety-violations: uint,
        last-updated: uint,
        certification-status: bool
    }
)

;; Fleet Manager Access Map
(define-map fleet-managers
    { manager: principal }
    {
        company-name: (string-ascii 50),
        registration-date: uint,
        is-authorized: bool,
        vehicle-count: uint
    }
)

;; Vehicle Alerts Map
(define-map vehicle-alerts
    { alert-id: (string-ascii 25) }
    {
        vehicle-id: (string-ascii 20),
        alert-type: (string-ascii 20),
        severity: (string-ascii 10),
        description: (string-ascii 100),
        timestamp: uint,
        resolved: bool
    }
)

;; Public Functions

;; Register Fleet Manager
(define-public (register-fleet-manager (company-name (string-ascii 50)))
    (let (
        (caller tx-sender)
    )
        (asserts! (var-get contract-active) ERR_UNAUTHORIZED)
        (asserts! (is-none (map-get? fleet-managers {manager: caller})) ERR_ALREADY_EXISTS)
        (ok (map-set fleet-managers
            {manager: caller}
            {
                company-name: company-name,
                registration-date: stacks-block-height,
                is-authorized: true,
                vehicle-count: u0
            }
        ))
    )
)

;; Register Vehicle
(define-public (register-vehicle 
    (vehicle-id (string-ascii 20))
    (driver-id (string-ascii 20))
    (make-model (string-ascii 50))
)
    (let (
        (caller tx-sender)
        (manager-info (map-get? fleet-managers {manager: caller}))
    )
        (asserts! (is-some manager-info) ERR_UNAUTHORIZED)
        (asserts! (get is-authorized (unwrap! manager-info ERR_UNAUTHORIZED)) ERR_UNAUTHORIZED)
        (asserts! (is-none (map-get? vehicles {vehicle-id: vehicle-id})) ERR_ALREADY_EXISTS)
        
        (map-set vehicles
            {vehicle-id: vehicle-id}
            {
                fleet-manager: caller,
                driver-id: driver-id,
                make-model: make-model,
                registration-date: stacks-block-height,
                is-active: true,
                total-distance: u0,
                total-fuel-consumed: u0,
                maintenance-due: (+ stacks-block-height u1000) ;; Maintenance due in 1000 blocks
            }
        )
        
        ;; Update manager's vehicle count
        (map-set fleet-managers
            {manager: caller}
            (merge (unwrap! manager-info ERR_NOT_FOUND)
                   {vehicle-count: (+ (get vehicle-count (unwrap! manager-info ERR_NOT_FOUND)) u1)}
            )
        )
        
        (var-set total-vehicles (+ (var-get total-vehicles) u1))
        (ok vehicle-id)
    )
)

;; Record Trip Data
(define-public (record-trip
    (trip-id (string-ascii 30))
    (vehicle-id (string-ascii 20))
    (driver-id (string-ascii 20))
    (start-time uint)
    (end-time uint)
    (distance uint)
    (fuel-consumed uint)
    (avg-speed uint)
    (max-speed uint)
    (harsh-braking uint)
    (harsh-acceleration uint)
    (idle-time uint)
)
    (let (
        (caller tx-sender)
        (vehicle-info (map-get? vehicles {vehicle-id: vehicle-id}))
        (trip-duration (- end-time start-time))
        (fuel-efficiency (if (> fuel-consumed u0) (/ (* distance u100) fuel-consumed) u0))
        (speed-score (if (<= max-speed MAX_SPEED_LIMIT) u100 u50))
        (safety-score (- u100 (+ harsh-braking harsh-acceleration)))
        (efficiency-score (if (>= fuel-efficiency MIN_FUEL_EFFICIENCY) u100 u60))
        (performance-score (/ (+ speed-score safety-score efficiency-score) u3))
    )
        (asserts! (is-some vehicle-info) ERR_NOT_FOUND)
        (asserts! (is-eq caller (get fleet-manager (unwrap! vehicle-info ERR_NOT_FOUND))) ERR_UNAUTHORIZED)
        (asserts! (> end-time start-time) ERR_INVALID_INPUT)
        (asserts! (is-none (map-get? trip-records {trip-id: trip-id})) ERR_ALREADY_EXISTS)
        
        ;; Record trip
        (map-set trip-records
            {trip-id: trip-id}
            {
                vehicle-id: vehicle-id,
                driver-id: driver-id,
                start-time: start-time,
                end-time: end-time,
                distance: distance,
                fuel-consumed: fuel-consumed,
                avg-speed: avg-speed,
                max-speed: max-speed,
                harsh-braking: harsh-braking,
                harsh-acceleration: harsh-acceleration,
                idle-time: idle-time,
                performance-score: performance-score
            }
        )
        
        ;; Update vehicle totals
        (map-set vehicles
            {vehicle-id: vehicle-id}
            (merge (unwrap! vehicle-info ERR_NOT_FOUND)
                   {
                       total-distance: (+ (get total-distance (unwrap! vehicle-info ERR_NOT_FOUND)) distance),
                       total-fuel-consumed: (+ (get total-fuel-consumed (unwrap! vehicle-info ERR_NOT_FOUND)) fuel-consumed)
                   }
            )
        )
        
        ;; Update driver performance and generate alerts
        (begin
            (unwrap! (update-driver-performance driver-id distance fuel-consumed performance-score) ERR_INVALID_INPUT)
            (unwrap! (check-and-generate-alerts vehicle-id max-speed harsh-braking harsh-acceleration) ERR_INVALID_INPUT)
            (var-set total-trips (+ (var-get total-trips) u1))
            (ok trip-id)
        )
    )
)

;; Generate Performance Alert
(define-public (create-alert
    (alert-id (string-ascii 25))
    (vehicle-id (string-ascii 20))
    (alert-type (string-ascii 20))
    (severity (string-ascii 10))
    (description (string-ascii 100))
)
    (let (
        (caller tx-sender)
        (vehicle-info (map-get? vehicles {vehicle-id: vehicle-id}))
    )
        (asserts! (is-some vehicle-info) ERR_NOT_FOUND)
        (asserts! (is-eq caller (get fleet-manager (unwrap! vehicle-info ERR_NOT_FOUND))) ERR_UNAUTHORIZED)
        (asserts! (is-none (map-get? vehicle-alerts {alert-id: alert-id})) ERR_ALREADY_EXISTS)
        
        (ok (map-set vehicle-alerts
            {alert-id: alert-id}
            {
                vehicle-id: vehicle-id,
                alert-type: alert-type,
                severity: severity,
                description: description,
                timestamp: stacks-block-height,
                resolved: false
            }
        ))
    )
)

;; Read-Only Functions

;; Get Vehicle Information
(define-read-only (get-vehicle-info (vehicle-id (string-ascii 20)))
    (map-get? vehicles {vehicle-id: vehicle-id})
)

;; Get Trip Record
(define-read-only (get-trip-record (trip-id (string-ascii 30)))
    (map-get? trip-records {trip-id: trip-id})
)

;; Get Driver Performance
(define-read-only (get-driver-performance (driver-id (string-ascii 20)))
    (map-get? driver-performance {driver-id: driver-id})
)

;; Get Fleet Manager Info
(define-read-only (get-fleet-manager-info (manager principal))
    (map-get? fleet-managers {manager: manager})
)

;; Get Vehicle Alerts
(define-read-only (get-vehicle-alert (alert-id (string-ascii 25)))
    (map-get? vehicle-alerts {alert-id: alert-id})
)

;; Calculate Vehicle Efficiency
(define-read-only (calculate-vehicle-efficiency (vehicle-id (string-ascii 20)))
    (match (map-get? vehicles {vehicle-id: vehicle-id})
        vehicle-info
        (let (
            (total-distance (get total-distance vehicle-info))
            (total-fuel (get total-fuel-consumed vehicle-info))
        )
            (if (> total-fuel u0)
                (some (/ (* total-distance u100) total-fuel))
                (some u0)
            )
        )
        none
    )
)

;; Get Contract Statistics
(define-read-only (get-contract-stats)
    {
        total-vehicles: (var-get total-vehicles),
        total-trips: (var-get total-trips),
        contract-active: (var-get contract-active)
    }
)

;; Private Functions

;; Update Driver Performance
(define-private (update-driver-performance 
    (driver-id (string-ascii 20))
    (distance uint)
    (fuel-consumed uint)
    (performance-score uint)
)
    (let (
        (current-perf (default-to
            {
                total-trips: u0,
                total-distance: u0,
                total-fuel-consumed: u0,
                avg-performance-score: u0,
                safety-violations: u0,
                last-updated: u0,
                certification-status: true
            }
            (map-get? driver-performance {driver-id: driver-id})
        ))
        (new-trip-count (+ (get total-trips current-perf) u1))
        (new-total-distance (+ (get total-distance current-perf) distance))
        (new-total-fuel (+ (get total-fuel-consumed current-perf) fuel-consumed))
        (new-avg-score (/ (+ (* (get avg-performance-score current-perf) (get total-trips current-perf)) performance-score) new-trip-count))
    )
        (ok (map-set driver-performance
            {driver-id: driver-id}
            {
                total-trips: new-trip-count,
                total-distance: new-total-distance,
                total-fuel-consumed: new-total-fuel,
                avg-performance-score: new-avg-score,
                safety-violations: (get safety-violations current-perf),
                last-updated: stacks-block-height,
                certification-status: (>= new-avg-score u70)
            }
        ))
    )
)

;; Check and Generate Alerts
(define-private (check-and-generate-alerts
    (vehicle-id (string-ascii 20))
    (max-speed uint)
    (harsh-braking uint)
    (harsh-acceleration uint)
)
    (begin
        ;; Speed alert generation
        (if (> max-speed MAX_SPEED_LIMIT)
            (unwrap! (auto-generate-alert vehicle-id "SPEED" "HIGH" "Speed limit exceeded") ERR_INVALID_INPUT)
            true
        )
        
        ;; Safety alert generation  
        (if (> (+ harsh-braking harsh-acceleration) u10)
            (unwrap! (auto-generate-alert vehicle-id "SAFETY" "MEDIUM" "Harsh driving detected") ERR_INVALID_INPUT)
            true
        )
        
        (ok true)
    )
)

;; Auto Generate Alert
(define-private (auto-generate-alert
    (vehicle-id (string-ascii 20))
    (alert-type (string-ascii 20))
    (severity (string-ascii 10))
    (description (string-ascii 100))
)
    (let (
        (alert-id (concat vehicle-id "-ALERT"))
    )
        (ok (map-set vehicle-alerts
            {alert-id: (unwrap-panic (as-max-len? alert-id u25))}
            {
                vehicle-id: vehicle-id,
                alert-type: alert-type,
                severity: severity,
                description: description,
                timestamp: stacks-block-height,
                resolved: false
            }
        ))
    )
)

