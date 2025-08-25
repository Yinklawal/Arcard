# Trading Card NFT Smart Contract

A comprehensive NFT trading card system built on the Stacks blockchain using Clarity smart contracts. This contract enables users to mint unique trading cards, list them for sale, and trade them with built-in creator royalties and administrative controls.

## 🎮 Features

### Core Functionality
- **NFT Minting**: Create unique trading cards with custom royalty percentages
- **Marketplace Trading**: List cards for sale with customizable prices
- **Creator Royalties**: Automatic royalty distribution to original card creators
- **Gifting System**: Transfer cards directly to other users
- **Tournament Mode**: Administrative control to pause trading during tournaments

### Administrative Features
- **Game Master System**: Delegated administrative control
- **Tournament Mode Toggle**: Ability to temporarily disable trading
- **Trade Update Intervals**: 24-hour cooldown between price updates

## 📋 Contract Overview

### NFT Definition
```clarity
(define-non-fungible-token card-id uint)
```

### Key Constants
- `CARD_MIN_VALUE`: 1 microSTX (minimum trade value)
- `CARD_MAX_VALUE`: 1,000,000,000 microSTX (maximum trade value)
- `MAX_CREATOR_ROYALTY`: 22% (maximum royalty percentage)
- `TRADE_UPDATE_INTERVAL`: 86,400 seconds (24 hours)
- `MAX_CARD_NUMBER`: 1,000,000 (maximum card ID)

## 🚀 Getting Started

### Prerequisites
- Stacks wallet (Hiro Wallet, Xverse, etc.)
- STX tokens for gas fees and trading
- Access to Stacks testnet or mainnet

### Deployment
1. Deploy the contract to the Stacks blockchain
2. The deployer automatically becomes the `GAME_CREATOR`
3. Optionally assign a `game-master` for day-to-day administration

## 📖 Function Reference

### Administrative Functions

#### `assign-game-master`
```clarity
(assign-game-master (new-master principal))
```
- **Purpose**: Assign a new game master (only callable by game creator)
- **Parameters**: `new-master` - Principal to assign as game master
- **Returns**: `(ok true)` on success

#### `toggle-tournament-mode`
```clarity
(toggle-tournament-mode)
```
- **Purpose**: Enable/disable tournament mode (only callable by game master)
- **Effect**: Pauses all trading activities when active
- **Returns**: `(ok true)` on success

### Core Trading Functions

#### `card-mint`
```clarity
(card-mint (card-num uint) (royalty-percent uint))
```
- **Purpose**: Mint a new trading card
- **Parameters**: 
  - `card-num`: Unique card identifier (0 to 1,000,000)
  - `royalty-percent`: Creator royalty percentage (0 to 22%)
- **Returns**: `(ok true)` on successful mint

#### `card-trade`
```clarity
(card-trade (card-num uint) (trade-value uint))
```
- **Purpose**: List a card for sale on the marketplace
- **Parameters**:
  - `card-num`: Card ID to list
  - `trade-value`: Sale price in microSTX
- **Requirements**: Must own the card, card not already trading
- **Returns**: `(ok true)` on successful listing

#### `card-collect`
```clarity
(card-collect (card-num uint))
```
- **Purpose**: Purchase a card from the marketplace
- **Parameters**: `card-num`: Card ID to purchase
- **Process**:
  1. Transfers creator royalty (if applicable)
  2. Transfers remaining amount to seller
  3. Transfers NFT to buyer
- **Returns**: `(ok true)` on successful purchase

#### `update-trade-value`
```clarity
(update-trade-value (card-num uint) (new-value uint))
```
- **Purpose**: Update the price of a listed card
- **Parameters**:
  - `card-num`: Card ID to update
  - `new-value`: New price in microSTX
- **Cooldown**: 24 hours between updates
- **Returns**: `(ok true)` on successful update

#### `withdraw-from-trade`
```clarity
(withdraw-from-trade (card-num uint))
```
- **Purpose**: Remove a card from the marketplace
- **Parameters**: `card-num`: Card ID to remove
- **Requirements**: Must own the listed card
- **Returns**: `(ok true)` on successful withdrawal

#### `gift-card`
```clarity
(gift-card (card-num uint) (recipient principal))
```
- **Purpose**: Transfer a card to another user for free
- **Parameters**:
  - `card-num`: Card ID to gift
  - `recipient`: Principal to receive the card
- **Returns**: `(ok true)` on successful transfer

### Read-Only Functions

#### `is-card-trading`
```clarity
(is-card-trading (card-num uint))
```
- **Purpose**: Check if a card is currently listed for sale
- **Returns**: `true` if trading, `false` otherwise

#### `get-card-trade-info`
```clarity
(get-card-trade-info (card-num uint))
```
- **Purpose**: Get marketplace information for a card
- **Returns**: Trading details (trader, value, posted-at) or `none`

#### `get-creator-royalty-data`
```clarity
(get-creator-royalty-data (card-num uint))
```
- **Purpose**: Get creator and royalty information for a card
- **Returns**: Creator principal and royalty percentage

## ⚠️ Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 101 | `ERR_CARD_NOT_TRADEABLE` | Card is not listed for sale |
| 102 | `ERR_INSUFFICIENT_TOKENS` | Insufficient STX balance |
| 103 | `ERR_COLLECTION_FAILED` | NFT transfer failed |
| 104 | `ERR_INVALID_CREATOR_ROYALTY` | Royalty percentage too high |
| 105 | `ERR_PERMISSION_DENIED` | Unauthorized action |
| 106 | `ERR_CANNOT_TRADE_WITH_SELF` | Cannot trade with yourself |
| 107 | `ERR_INVALID_TRADE_VALUE` | Price outside allowed range |
| 108 | `ERR_TRADE_UPDATE_BLOCKED` | Too soon to update price |
| 109 | `ERR_TOURNAMENT_ACTIVE` | Trading disabled during tournament |
| 110 | `ERR_CARD_ALREADY_TRADING` | Card already listed for sale |
| 111 | `ERR_INVALID_CARD_NUMBER` | Card ID outside valid range |
| 112 | `ERR_INVALID_GAMEMASTER` | Invalid game master assignment |

## 🎯 Usage Examples

### Minting a Card
```clarity
;; Mint card #1 with 5% creator royalty
(contract-call? .trading-card-nft card-mint u1 u5)
```

### Listing a Card for Sale
```clarity
;; List card #1 for 1000000 microSTX (1 STX)
(contract-call? .trading-card-nft card-trade u1 u1000000)
```

### Buying a Card
```clarity
;; Purchase card #1
(contract-call? .trading-card-nft card-collect u1)
```

### Gifting a Card
```clarity
;; Gift card #1 to another user
(contract-call? .trading-card-nft gift-card u1 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

## 🔒 Security Features

- **Ownership Verification**: All functions verify NFT ownership before execution
- **Self-Trading Prevention**: Users cannot trade with themselves
- **Tournament Mode**: Emergency pause functionality
- **Rate Limiting**: 24-hour cooldown on price updates
- **Input Validation**: Comprehensive validation of all parameters
- **Royalty Caps**: Maximum 22% creator royalties

## 🛠️ Development

### Testing
The contract includes comprehensive error handling and validation. Test all functions with:
- Valid and invalid parameters
- Edge cases (minimum/maximum values)
- Permission scenarios
- Tournament mode interactions

### Integration
This contract can be integrated with:
- Web frontends using Stacks.js
- Mobile applications
- Game clients
- Marketplace interfaces
