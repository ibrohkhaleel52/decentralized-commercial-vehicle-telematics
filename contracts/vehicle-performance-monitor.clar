;; Vehicle Performance Monitor Contract
;; Monitors commercial vehicle performance and operational metrics, tracks fuel consumption,
;; analyzes driver behavior, identifies inefficiencies, and optimizes fleet operations

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u700))
(define-constant ERR_VEHICLE_NOT_FOUND (err u701))
(define-constant ERR_DRIVER_NOT_FOUND (err u702))
(define-constant ERR_INVALID_PARAMETERS (err u703))
(define-constant ERR_ROUTE_NOT_FOUND (err u704))
(define-constant ERR_MAINTENANCE_NOT_FOUND (err u705))
(define-constant ERR_TELEMETRY_NOT_FOUND (err u706))
(define-constant ERR_INVALID_SCORE (err u707))

;; Data Variables
(define-data-var next-vehicle-id uint u1)
(define-data-var next-driver-id uint u1)
(define-data-var next-route-id uint u1)
(define-data-var next-telemetry-id uint u1)
(define-data-var next-maintenance-id uint u1)
(define-data-var contract-paused bool false)
(define-data-var fuel-price-per-gallon uint u350) ;; $3.50 per gallon in cents
(define-data-var max-driving-hours uint u11) ;; 11 hours maximum driving
(define-data-var safety-score-threshold uint u80) ;; 80% minimum safety score
(define-data-var fuel-efficiency-target uint u7) ;; 7 MPG target

;; Data Maps

;; Commercial vehicle registry and specifications
(define-map commercial-vehicles
  { vehicle-id: uint }
  {
    vin: (string-ascii 17),
    make: (string-ascii 32),
    model: (string-ascii 32),
    year: uint,
    vehicle-type: (string-ascii 32),
    gross-weight: uint,
    engine-type: (string-ascii 32),
    fuel-capacity: uint,
    odometer: uint,
    license-plate: (string-ascii 16),
    dot-number: (string-ascii 16),
    fleet-id: (string-ascii 32),
    status: (string-ascii 16),
    owner: principal,
    last-updated: uint
  }
)

;; Driver profiles and qualifications
(define-map driver-profiles
  { driver-id: uint }
  {
    driver-name: (string-ascii 128),
    license-number: (string-ascii 32),
    license-class: (string-ascii 8),
    license-expiry: uint,
    medical-cert-expiry: uint,
    hire-date: uint,
    total-miles: uint,
    safety-score: uint,
    efficiency-score: uint,
    compliance-score: uint,
    assigned-vehicle: uint,
    status: (string-ascii 16),
    manager: principal,
    last-active: uint
  }
)

;; Real-time vehicle telemetry data
(define-map vehicle-telemetry
  { telemetry-id: uint }
  {
    vehicle-id: uint,
    driver-id: uint,
    timestamp: uint,
    latitude: (string-ascii 16),
    longitude: (string-ascii 16),
    speed: uint,
    engine-rpm: uint,
    fuel-level: uint,
    engine-temp: uint,
    oil-pressure: uint,
    battery-voltage: uint,
    odometer-reading: uint,
    harsh-braking: bool,
    harsh-acceleration: bool,
    speeding: bool,
    idling-time: uint
  }
)

;; Route planning and optimization
(define-map route-plans
  { route-id: uint }
  {
    vehicle-id: uint,
    driver-id: uint,
    origin: (string-ascii 128),
    destination: (string-ascii 128),
    planned-distance: uint,
    actual-distance: uint,
    estimated-time: uint,
    actual-time: uint,
    fuel-estimate: uint,
    actual-fuel-used: uint,
    route-status: (string-ascii 16),
    start-time: uint,
    end-time: (optional uint),
    waypoints: (string-ascii 512),
    traffic-delays: uint
  }
)

;; Fuel consumption and efficiency tracking
(define-map fuel-consumption
  { vehicle-id: uint, period: uint }
  {
    total-fuel-used: uint,
    total-miles: uint,
    fuel-efficiency: uint,
    cost: uint,
    fuel-ups: uint,
    idle-fuel-consumption: uint,
    highway-efficiency: uint,
    city-efficiency: uint,
    efficiency-ranking: uint,
    period-start: uint,
    period-end: uint
  }
)

;; Maintenance scheduling and tracking
(define-map maintenance-schedules
  { maintenance-id: uint }
  {
    vehicle-id: uint,
    maintenance-type: (string-ascii 64),
    scheduled-date: uint,
    completed-date: (optional uint),
    odometer-at-service: uint,
    cost: uint,
    service-provider: (string-ascii 128),
    description: (string-ascii 256),
    parts-replaced: (string-ascii 256),
    next-service-due: uint,
    status: (string-ascii 16),
    priority: (string-ascii 16)
  }
)

;; Driver behavior analytics
(define-map driver-behavior
  { driver-id: uint, period: uint }
  {
    total-driving-time: uint,
    harsh-braking-events: uint,
    harsh-acceleration-events: uint,
    speeding-events: uint,
    idling-time: uint,
    night-driving-time: uint,
    safety-violations: uint,
    fuel-efficiency: uint,
    on-time-deliveries: uint,
    customer-ratings: uint,
    period-start: uint,
    period-end: uint
  }
)

;; Fleet performance metrics
(define-map fleet-metrics
  { fleet-id: (string-ascii 32), period: uint }
  {
    total-vehicles: uint,
    active-vehicles: uint,
    total-miles: uint,
    total-fuel-cost: uint,
    average-efficiency: uint,
    maintenance-cost: uint,
    safety-incidents: uint,
    compliance-violations: uint,
    driver-count: uint,
    utilization-rate: uint,
    period-start: uint,
    period-end: uint
  }
)

;; Admin Functions

;; Set fuel price per gallon
(define-public (set-fuel-price (price-cents uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> price-cents u0) ERR_INVALID_PARAMETERS)
    (var-set fuel-price-per-gallon price-cents)
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

;; Vehicle Management Functions

;; Register commercial vehicle
(define-public (register-vehicle
                (vin (string-ascii 17))
                (make (string-ascii 32))
                (model (string-ascii 32))
                (year uint)
                (vehicle-type (string-ascii 32))
                (gross-weight uint)
                (engine-type (string-ascii 32))
                (fuel-capacity uint)
                (license-plate (string-ascii 16))
                (dot-number (string-ascii 16))
                (fleet-id (string-ascii 32)))
  (let
    (
      (vehicle-id (var-get next-vehicle-id))
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
    )
    (asserts! (not (var-get contract-paused)) (err u999))
    (asserts! (is-eq (len vin) u17) ERR_INVALID_PARAMETERS)
    (asserts! (> year u1990) ERR_INVALID_PARAMETERS)
    (asserts! (> fuel-capacity u0) ERR_INVALID_PARAMETERS)
    
    (map-set commercial-vehicles
      { vehicle-id: vehicle-id }
      {
        vin: vin,
        make: make,
        model: model,
        year: year,
        vehicle-type: vehicle-type,
        gross-weight: gross-weight,
        engine-type: engine-type,
        fuel-capacity: fuel-capacity,
        odometer: u0,
        license-plate: license-plate,
        dot-number: dot-number,
        fleet-id: fleet-id,
        status: "active",
        owner: tx-sender,
        last-updated: current-time
      }
    )
    
    (var-set next-vehicle-id (+ vehicle-id u1))
    (ok vehicle-id)
  )
)

;; Update vehicle status
(define-public (update-vehicle-status (vehicle-id uint) (status (string-ascii 16)) (odometer uint))
  (let
    (
      (vehicle (unwrap! (map-get? commercial-vehicles { vehicle-id: vehicle-id }) ERR_VEHICLE_NOT_FOUND))
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
    )
    (asserts! (not (var-get contract-paused)) (err u999))
    (asserts! (is-eq (get owner vehicle) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (>= odometer (get odometer vehicle)) ERR_INVALID_PARAMETERS)
    
    (map-set commercial-vehicles
      { vehicle-id: vehicle-id }
      (merge vehicle {
        status: status,
        odometer: odometer,
        last-updated: current-time
      })
    )
    (ok true)
  )
)

;; Driver Management Functions

;; Register driver
(define-public (register-driver
                (driver-name (string-ascii 128))
                (license-number (string-ascii 32))
                (license-class (string-ascii 8))
                (license-expiry uint)
                (medical-cert-expiry uint)
                (hire-date uint)
                (assigned-vehicle uint))
  (let
    (
      (driver-id (var-get next-driver-id))
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
    )
    (asserts! (not (var-get contract-paused)) (err u999))
    (asserts! (> (len driver-name) u0) ERR_INVALID_PARAMETERS)
    (asserts! (> license-expiry current-time) ERR_INVALID_PARAMETERS)
    (asserts! (> medical-cert-expiry current-time) ERR_INVALID_PARAMETERS)
    
    (map-set driver-profiles
      { driver-id: driver-id }
      {
        driver-name: driver-name,
        license-number: license-number,
        license-class: license-class,
        license-expiry: license-expiry,
        medical-cert-expiry: medical-cert-expiry,
        hire-date: hire-date,
        total-miles: u0,
        safety-score: u100,
        efficiency-score: u100,
        compliance-score: u100,
        assigned-vehicle: assigned-vehicle,
        status: "active",
        manager: tx-sender,
        last-active: current-time
      }
    )
    
    (var-set next-driver-id (+ driver-id u1))
    (ok driver-id)
  )
)

;; Update driver scores
(define-public (update-driver-scores (driver-id uint) (safety-score uint) (efficiency-score uint) (compliance-score uint))
  (let
    (
      (driver (unwrap! (map-get? driver-profiles { driver-id: driver-id }) ERR_DRIVER_NOT_FOUND))
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
    )
    (asserts! (not (var-get contract-paused)) (err u999))
    (asserts! (is-eq (get manager driver) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (and (<= safety-score u100) (<= efficiency-score u100) (<= compliance-score u100)) ERR_INVALID_SCORE)
    
    (map-set driver-profiles
      { driver-id: driver-id }
      (merge driver {
        safety-score: safety-score,
        efficiency-score: efficiency-score,
        compliance-score: compliance-score,
        last-active: current-time
      })
    )
    (ok true)
  )
)

;; Telemetry Data Functions

;; Record vehicle telemetry
(define-public (record-telemetry
                (vehicle-id uint)
                (driver-id uint)
                (latitude (string-ascii 16))
                (longitude (string-ascii 16))
                (speed uint)
                (engine-rpm uint)
                (fuel-level uint)
                (engine-temp uint)
                (oil-pressure uint)
                (battery-voltage uint)
                (odometer-reading uint)
                (harsh-braking bool)
                (harsh-acceleration bool)
                (speeding bool)
                (idling-time uint))
  (let
    (
      (telemetry-id (var-get next-telemetry-id))
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
      (vehicle (unwrap! (map-get? commercial-vehicles { vehicle-id: vehicle-id }) ERR_VEHICLE_NOT_FOUND))
    )
    (asserts! (not (var-get contract-paused)) (err u999))
    (asserts! (is-eq (get owner vehicle) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (<= speed u100) ERR_INVALID_PARAMETERS) ;; Speed limit check
    
    (map-set vehicle-telemetry
      { telemetry-id: telemetry-id }
      {
        vehicle-id: vehicle-id,
        driver-id: driver-id,
        timestamp: current-time,
        latitude: latitude,
        longitude: longitude,
        speed: speed,
        engine-rpm: engine-rpm,
        fuel-level: fuel-level,
        engine-temp: engine-temp,
        oil-pressure: oil-pressure,
        battery-voltage: battery-voltage,
        odometer-reading: odometer-reading,
        harsh-braking: harsh-braking,
        harsh-acceleration: harsh-acceleration,
        speeding: speeding,
        idling-time: idling-time
      }
    )
    
    (var-set next-telemetry-id (+ telemetry-id u1))
    (ok telemetry-id)
  )
)

;; Route Management Functions

;; Create route plan
(define-public (create-route
                (vehicle-id uint)
                (driver-id uint)
                (origin (string-ascii 128))
                (destination (string-ascii 128))
                (planned-distance uint)
                (estimated-time uint)
                (fuel-estimate uint)
                (waypoints (string-ascii 512)))
  (let
    (
      (route-id (var-get next-route-id))
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
      (vehicle (unwrap! (map-get? commercial-vehicles { vehicle-id: vehicle-id }) ERR_VEHICLE_NOT_FOUND))
    )
    (asserts! (not (var-get contract-paused)) (err u999))
    (asserts! (is-eq (get owner vehicle) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (> planned-distance u0) ERR_INVALID_PARAMETERS)
    
    (map-set route-plans
      { route-id: route-id }
      {
        vehicle-id: vehicle-id,
        driver-id: driver-id,
        origin: origin,
        destination: destination,
        planned-distance: planned-distance,
        actual-distance: u0,
        estimated-time: estimated-time,
        actual-time: u0,
        fuel-estimate: fuel-estimate,
        actual-fuel-used: u0,
        route-status: "planned",
        start-time: current-time,
        end-time: none,
        waypoints: waypoints,
        traffic-delays: u0
      }
    )
    
    (var-set next-route-id (+ route-id u1))
    (ok route-id)
  )
)

;; Complete route
(define-public (complete-route (route-id uint) (actual-distance uint) (actual-time uint) (actual-fuel-used uint))
  (let
    (
      (route (unwrap! (map-get? route-plans { route-id: route-id }) ERR_ROUTE_NOT_FOUND))
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
      (vehicle (unwrap! (map-get? commercial-vehicles { vehicle-id: (get vehicle-id route) }) ERR_VEHICLE_NOT_FOUND))
    )
    (asserts! (not (var-get contract-paused)) (err u999))
    (asserts! (is-eq (get owner vehicle) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get route-status route) "planned") ERR_INVALID_PARAMETERS)
    
    (map-set route-plans
      { route-id: route-id }
      (merge route {
        actual-distance: actual-distance,
        actual-time: actual-time,
        actual-fuel-used: actual-fuel-used,
        route-status: "completed",
        end-time: (some current-time)
      })
    )
    (ok true)
  )
)

;; Maintenance Functions

;; Schedule maintenance
(define-public (schedule-maintenance
                (vehicle-id uint)
                (maintenance-type (string-ascii 64))
                (scheduled-date uint)
                (service-provider (string-ascii 128))
                (description (string-ascii 256))
                (priority (string-ascii 16)))
  (let
    (
      (maintenance-id (var-get next-maintenance-id))
      (vehicle (unwrap! (map-get? commercial-vehicles { vehicle-id: vehicle-id }) ERR_VEHICLE_NOT_FOUND))
      (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
    )
    (asserts! (not (var-get contract-paused)) (err u999))
    (asserts! (is-eq (get owner vehicle) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (> scheduled-date current-time) ERR_INVALID_PARAMETERS)
    
    (map-set maintenance-schedules
      { maintenance-id: maintenance-id }
      {
        vehicle-id: vehicle-id,
        maintenance-type: maintenance-type,
        scheduled-date: scheduled-date,
        completed-date: none,
        odometer-at-service: (get odometer vehicle),
        cost: u0,
        service-provider: service-provider,
        description: description,
        parts-replaced: "",
        next-service-due: (+ scheduled-date u7776000), ;; 90 days later
        status: "scheduled",
        priority: priority
      }
    )
    
    (var-set next-maintenance-id (+ maintenance-id u1))
    (ok maintenance-id)
  )
)

;; Read Functions

;; Get vehicle information
(define-read-only (get-vehicle (vehicle-id uint))
  (ok (map-get? commercial-vehicles { vehicle-id: vehicle-id }))
)

;; Get driver profile
(define-read-only (get-driver (driver-id uint))
  (ok (map-get? driver-profiles { driver-id: driver-id }))
)

;; Get vehicle telemetry
(define-read-only (get-telemetry (telemetry-id uint))
  (ok (map-get? vehicle-telemetry { telemetry-id: telemetry-id }))
)

;; Get route plan
(define-read-only (get-route (route-id uint))
  (ok (map-get? route-plans { route-id: route-id }))
)

;; Get fuel consumption data
(define-read-only (get-fuel-consumption (vehicle-id uint) (period uint))
  (ok (map-get? fuel-consumption { vehicle-id: vehicle-id, period: period }))
)

;; Calculate vehicle efficiency
(define-read-only (calculate-vehicle-efficiency (vehicle-id uint) (total-miles uint) (fuel-used uint))
  (if (> fuel-used u0)
    (ok (/ total-miles fuel-used))
    (ok u0)
  )
)

;; Check driver qualification status
(define-read-only (check-driver-qualification (driver-id uint))
  (match (map-get? driver-profiles { driver-id: driver-id })
    driver
    (let
      (
        (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
      )
      (ok {
        license-valid: (> (get license-expiry driver) current-time),
        medical-valid: (> (get medical-cert-expiry driver) current-time),
        safety-compliant: (>= (get safety-score driver) (var-get safety-score-threshold)),
        overall-qualified: (and 
                            (> (get license-expiry driver) current-time)
                            (> (get medical-cert-expiry driver) current-time)
                            (>= (get safety-score driver) (var-get safety-score-threshold))
                          )
      })
    )
    ERR_DRIVER_NOT_FOUND
  )
)

;; Calculate fleet performance
(define-read-only (calculate-fleet-performance (fleet-id (string-ascii 32)))
  ;; Simplified calculation - in real implementation would aggregate all vehicles
  (ok {
    total-vehicles: u0,
    average-efficiency: u0,
    safety-score: u0,
    compliance-rate: u0
  })
)

;; Helper Functions

;; Calculate driver performance score
(define-read-only (calculate-driver-performance-score (safety uint) (efficiency uint) (compliance uint))
  (/ (+ safety efficiency compliance) u3)
)

;; Estimate maintenance cost
(define-read-only (estimate-maintenance-cost (vehicle-id uint) (maintenance-type (string-ascii 64)))
  ;; Simplified cost estimation based on maintenance type
  (if (is-eq maintenance-type "oil-change")
    u15000 ;; $150
    (if (is-eq maintenance-type "brake-service")
      u50000 ;; $500
      u30000 ;; $300 default
    )
  )
)

;; title: vehicle-performance-monitor
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

