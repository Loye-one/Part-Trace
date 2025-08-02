# Part Trace Provenance Smart Contract

A Clarity smart contract for creating an immutable and verifiable history of high-value automotive parts using NFTs. Each NFT represents a unique part and tracks its status changes throughout the supply chain.

## Overview

This contract enables manufacturers, distributors, and dealers to track automotive parts from manufacturing to installation in vehicles. Each part is represented as an NFT with a complete audit trail of its journey through the supply chain.

## Features

- **Immutable Part History**: Complete tracking from manufacturing to installation
- **NFT-Based Authentication**: Each part is represented as a unique NFT
- **Multi-Party Verification**: Manufacturers, distributors, and dealers can interact with the system
- **Status Tracking**: Real-time status updates (Manufactured, In-Transit, Delivered, Installed)
- **Metadata Support**: Off-chain data linking for detailed part specifications
- **Input Validation**: Comprehensive validation to ensure data integrity

## Contract Architecture

### Status Flow
1. **Manufactured** (u0) - Part is created by manufacturer
2. **In-Transit** (u1) - Part is shipped to distributor/dealer
3. **Delivered** (u2) - Part delivery is confirmed by recipient
4. **Installed** (u3) - Part is installed in a vehicle (final state)

### Key Components

#### Data Storage
- `last-token-id`: Tracks the last minted token ID
- `manufacturer-principal`: The designated manufacturer principal
- `authentic-part`: NFT collection for parts

#### Data Maps
- `part-serial-numbers`: Maps token ID to serial number
- `part-types`: Maps token ID to part type/model
- `token-metadata-uri`: Maps token ID to metadata URI
- `part-status-map`: Maps token ID to current status
- `part-custodian-map`: Maps token ID to current custodian

## Functions

### Administrative Functions

#### `set-manufacturer`
Sets a new manufacturer principal. Only callable by contract owner.

```clarity
(set-manufacturer (new-manufacturer principal))
```

**Parameters:**
- `new-manufacturer`: The principal of the new manufacturer

**Returns:** `(response bool uint)`

### Manufacturer Functions

#### `manufacture-part`
Mints a new part NFT. Only callable by the manufacturer.

```clarity
(manufacture-part (serial-number (string-utf8 40)) (part-type (string-utf8 40)) (metadata-uri (string-utf8 256)))
```

**Parameters:**
- `serial-number`: Unique serial number of the part
- `part-type`: Type or model of the part
- `metadata-uri`: URI for off-chain data

**Returns:** `(response uint uint)` - Token ID of minted NFT

#### `ship-part`
Marks a part as shipped to a new custodian.

```clarity
(ship-part (token-id uint) (new-custodian principal))
```

**Parameters:**
- `token-id`: ID of the part NFT
- `new-custodian`: Principal of the new custodian

**Returns:** `(response bool uint)`

### Custodian Functions

#### `confirm-delivery`
Confirms delivery of a part. Only callable by the designated custodian.

```clarity
(confirm-delivery (token-id uint))
```

**Parameters:**
- `token-id`: ID of the part NFT

**Returns:** `(response bool uint)`

#### `install-part`
Marks a part as installed in a vehicle.

```clarity
(install-part (token-id uint) (vehicle-vin (string-utf8 17)))
```

**Parameters:**
- `token-id`: ID of the part NFT
- `vehicle-vin`: VIN of the vehicle where part was installed

**Returns:** `(response bool uint)`

### Read-Only Functions

#### `get-part-status`
Returns the current status of a part.

```clarity
(get-part-status (token-id uint))
```

#### `get-part-details`
Returns comprehensive details for a part NFT.

```clarity
(get-part-details (token-id uint))
```

#### `get-manufacturer`
Returns the current manufacturer principal.

#### `get-last-token-id`
Returns the last token ID that was minted.

#### `get-owner`
Returns the owner of a specific part NFT.

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u101 | `ERR-NOT-AUTHORIZED` | Caller not authorized for this action |
| u102 | `ERR-TOKEN-NOT-FOUND` | Token does not exist |
| u103 | `ERR-OWNER-ONLY` | Only token owner can perform this action |
| u104 | `ERR-MANUFACTURER-ONLY` | Only manufacturer can perform this action |
| u105 | `ERR-INVALID-STATUS` | Invalid status for this operation |
| u106 | `ERR-ALREADY-INSTALLED` | Part is already installed |
| u107 | `ERR-NOT-IN-TRANSIT` | Part is not in transit |
| u108 | `ERR-WRONG-CUSTODIAN` | Wrong custodian for this operation |
| u109 | `ERR-INVALID-INPUT` | Invalid input provided |
| u110 | `ERR-EMPTY-STRING` | Empty string not allowed |

## Events

The contract emits events for key operations:

### `manufacture-part`
```json
{
  "event": "manufacture-part",
  "token-id": 1,
  "serial-number": "ABC123XYZ",
  "part-type": "Airbag-Model-X"
}
```

### `ship-part`
```json
{
  "event": "ship-part",
  "token-id": 1,
  "from": "SP1...",
  "to": "SP2..."
}
```

### `confirm-delivery`
```json
{
  "event": "confirm-delivery",
  "token-id": 1,
  "custodian": "SP2..."
}
```

### `install-part`
```json
{
  "event": "install-part",
  "token-id": 1,
  "dealer": "SP2...",
  "installed-in-vin": "1HGBH41JXMN109186"
}
```

## Usage Example

### 1. Manufacturer creates a part
```clarity
(contract-call? .part-trace-provenance manufacture-part 
  u"ABC123XYZ" 
  u"Airbag-Model-X" 
  u"https://parts-db.com/abc123xyz")
```

### 2. Manufacturer ships to dealer
```clarity
(contract-call? .part-trace-provenance ship-part 
  u1 
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

### 3. Dealer confirms delivery
```clarity
(contract-call? .part-trace-provenance confirm-delivery u1)
```

### 4. Dealer installs part
```clarity
(contract-call? .part-trace-provenance install-part 
  u1 
  u"1HGBH41JXMN109186")
```

## Security Features

- **Input Validation**: All user inputs are validated before processing
- **Access Control**: Role-based permissions for different operations
- **State Validation**: Ensures parts can only move through valid state transitions
- **Principal Validation**: Prevents invalid principal assignments
- **String Validation**: Ensures non-empty strings for critical data

## Development

### Prerequisites
- Clarinet 0.31.1 or later
- Stacks blockchain knowledge

### Testing
```bash
clarinet check
clarinet test
```

### Deployment
```bash
clarinet deploy --testnet
```

## Version History

### v1.1.0
- Added comprehensive input validation
- Improved error handling
- Enhanced security features
- Optimized gas usage
- Better Unicode support with string-utf8

### v1.0.0
- Initial implementation
- Basic part tracking functionality
- NFT-based part representation

## License

This project is licensed under the MIT License.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## Support

For questions or issues, please open an issue in the repository or contact the development team.