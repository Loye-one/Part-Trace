;; ---------------------------------------------------------
;; Contract: part-trace-provenance.clar
;; Description: Creates an immutable and verifiable history for
;; high-value automotive parts using NFTs. Each NFT represents a
;; unique part and tracks its status changes (e.g., manufactured,
;; shipped, delivered, installed) across the supply chain.
;;
;; Version: 1.0.0
;; ---------------------------------------------------------

;; --- Constants and Errors ---
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u101))
(define-constant ERR-TOKEN-NOT-FOUND (err u102))
(define-constant ERR-OWNER-ONLY (err u103))
(define-constant ERR-MANUFACTURER-ONLY (err u104))
(define-constant ERR-INVALID-STATUS (err u105))
(define-constant ERR-ALREADY-INSTALLED (err u106))
(define-constant ERR-NOT-IN-TRANSIT (err u107))
(define-constant ERR-WRONG-CUSTODIAN (err u108))

;; --- Data Storage ---
(define-data-var last-token-id uint u0)
;; The principal designated as the primary manufacturer.
(define-data-var manufacturer-principal principal CONTRACT-OWNER)

;; --- NFT Definition ---
(define-non-fungible-token authentic-part uint)

;; --- Data Maps ---
;; Maps token ID to part serial number.
(define-map part-serial-numbers uint (string-ascii 40))
;; Maps token ID to part type (e.g., "Airbag-Model-X").
(define-map part-types uint (string-ascii 40))
;; Maps token ID to a URI for detailed part schematics/data.
(define-map token-metadata-uri uint (string-ascii 256))
;; Maps token ID to its current supply chain status code.
;; u0: Manufactured, u1: In-Transit, u2: Delivered, u3: Installed
(define-map part-status-map uint uint)
;; Maps token ID to the principal of the current custodian (distributor/dealer).
(define-map part-custodian-map uint principal)

;; =========================================================
;; --- Administrative Functions ---
;; =========================================================

;; @desc Sets a new manufacturer principal. Can only be called by the contract owner.
;; @param new-manufacturer: The principal of the new manufacturer.
;; @returns (response bool uint)
(define-public (set-manufacturer (new-manufacturer principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (var-set manufacturer-principal new-manufacturer))
  )
)

;; =========================================================
;; --- Manufacturer Functions ---
;; =========================================================

;; @desc Mints a new part NFT. Can only be called by the manufacturer.
;; @param serial-number: The unique serial number of the part.
;; @param part-type: The type or model of the part.
;; @param metadata-uri: A URI for off-chain data.
;; @returns (response uint uint)
(define-public (manufacture-part (serial-number (string-ascii 40)) (part-type (string-ascii 40)) (metadata-uri (string-ascii 256)))
  (begin
    (asserts! (is-eq tx-sender (var-get manufacturer-principal)) ERR-MANUFACTURER-ONLY)

    (let ((token-id (+ u1 (var-get last-token-id))))
      (try! (nft-mint? authentic-part token-id (var-get manufacturer-principal)))
      (map-set part-serial-numbers token-id serial-number)
      (map-set part-types token-id part-type)
      (map-set token-metadata-uri token-id metadata-uri)
      (map-set part-status-map token-id u0) ;; Status: Manufactured
      (map-set part-custodian-map token-id (var-get manufacturer-principal))
      (var-set last-token-id token-id)

      (print {
        event: "manufacture-part",
        token-id: token-id,
        serial-number: serial-number,
        part-type: part-type
      })
      (ok token-id)
    )
  )
)

;; @desc Marks a part as shipped to a new custodian (e.g., a distributor or dealership).
;; @param token-id: The ID of the part NFT.
;; @param new-custodian: The principal of the new custodian.
;; @returns (response bool uint)
(define-public (ship-part (token-id uint) (new-custodian principal))
  (begin
    (let ((owner (unwrap! (nft-get-owner? authentic-part token-id) ERR-TOKEN-NOT-FOUND)))
      (asserts! (is-eq tx-sender owner) ERR-OWNER-ONLY)
      (asserts! (is-eq (map-get? part-status-map token-id) (some u0)) ERR-INVALID-STATUS) ;; Must be 'Manufactured'

      (map-set part-status-map token-id u1) ;; Status: In-Transit
      (map-set part-custodian-map token-id new-custodian)

      (print {
        event: "ship-part",
        token-id: token-id,
        from: tx-sender,
        to: new-custodian
      })
      (ok true)
    )
  )
)

;; =========================================================
;; --- Custodian and Dealer Functions ---
;; =========================================================

;; @desc Confirms delivery of a part. Can only be called by the designated new custodian.
;; @param token-id: The ID of the part NFT.
;; @returns (response bool uint)
(define-public (confirm-delivery (token-id uint))
  (begin
    (let ((current-custodian (unwrap! (map-get? part-custodian-map token-id) ERR-TOKEN-NOT-FOUND)))
      (asserts! (is-eq tx-sender current-custodian) ERR-WRONG-CUSTODIAN)
      (asserts! (is-eq (map-get? part-status-map token-id) (some u1)) ERR-NOT-IN-TRANSIT) ;; Must be 'In-Transit'

      ;; Transfer NFT ownership to the new custodian (the dealership)
      (let ((manufacturer (var-get manufacturer-principal)))
        (try! (nft-transfer? authentic-part token-id manufacturer tx-sender))
      )

      (map-set part-status-map token-id u2) ;; Status: Delivered

      (print {
        event: "confirm-delivery",
        token-id: token-id,
        custodian: tx-sender
      })
      (ok true)
    )
  )
)

;; @desc Marks a part as installed in a vehicle, finalizing its journey.
;; @param token-id: The ID of the part NFT.
;; @param vehicle-vin: The VIN of the vehicle where the part was installed.
;; @returns (response bool uint)
(define-public (install-part (token-id uint) (vehicle-vin (string-ascii 17)))
  (begin
    (let ((owner (unwrap! (nft-get-owner? authentic-part token-id) ERR-TOKEN-NOT-FOUND)))
      (asserts! (is-eq tx-sender owner) ERR-OWNER-ONLY) ;; Only the current owner (dealer) can install
      (asserts! (not (is-eq (map-get? part-status-map token-id) (some u3))) ERR-ALREADY-INSTALLED)

      (map-set part-status-map token-id u3) ;; Status: Installed

      (print {
        event: "install-part",
        token-id: token-id,
        dealer: owner,
        installed-in-vin: vehicle-vin
      })
      (ok true)
    )
  )
)

;; =========================================================
;; --- Read-Only Functions ---
;; =========================================================

;; @desc Gets the current status of a part.
;; @param token-id: The ID of the token.
;; @returns (optional uint) where u0=Manufactured, u1=In-Transit, u2=Delivered, u3=Installed
(define-read-only (get-part-status (token-id uint))
  (map-get? part-status-map token-id)
)

;; @desc Gets the details for a specific part NFT.
;; @param token-id: The ID of the token.
;; @returns A tuple with the part's details.
(define-read-only (get-part-details (token-id uint))
  (let ((owner (nft-get-owner? authentic-part token-id))
        (serial-number (map-get? part-serial-numbers token-id))
        (part-type (map-get? part-types token-id))
        (status (map-get? part-status-map token-id))
        (custodian (map-get? part-custodian-map token-id))
        (metadata (map-get? token-metadata-uri token-id)))
    (ok {
      owner: owner,
      serial-number: serial-number,
      part-type: part-type,
      status: status,
      custodian: custodian,
      metadata-uri: metadata
    })
  )
)

;; @desc Gets the current manufacturer principal.
;; @returns principal
(define-read-only (get-manufacturer)
  (var-get manufacturer-principal)
)

;; @desc Gets the last token ID that was minted.
;; @returns (response uint uint)
(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

;; @desc Gets the owner of a specific part NFT.
;; @param token-id: The ID of the token.
;; @returns (response (optional principal) uint)
(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? authentic-part token-id))
)