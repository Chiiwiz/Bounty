# BugBounty Hunter DAO Smart Contract

A decentralized bug bounty platform where security researchers stake tokens and collectively vote on vulnerability rewards, built on the Stacks blockchain.

## Overview

BugBounty Hunter DAO is a community-driven security platform that enables researchers to stake tokens, submit vulnerability reports for reward consideration, and collectively review bounty claims. The contract manages the entire lifecycle of bug bounty submissions in a transparent and meritocratic manner.

## Key Features

- **Stake-to-Participate Model**: Researchers stake STX to join the review network
- **Peer Review System**: Bounty claims are validated through researcher consensus
- **Time-bound Submissions**: Report filing rights are active for a limited period
- **Transparent Reward Distribution**: All bounty decisions are made collectively

## Contract Constants

| Constant | Description |
|----------|-------------|
| `REVIEW_WINDOW` | Bounty review duration (~24 hours) |
| `ACTIVE_PERIOD` | Period researchers can file reports (~10 days) |
| `MAXIMUM_BOUNTY` | Maximum reward payout limit |

## Core Functions

### For Security Researchers

#### `stake_as_researcher`
Join the platform by staking STX tokens.
```clarity
(stake_as_researcher (stake_amount uint))
```
- **Parameters**: `stake_amount` - Amount of STX to stake
- **Returns**: `(ok true)` on success
- **Errors**:
  - `ERR_INPUT_ERROR` - Invalid input values
  - `ERR_STAKE_REQUIRED` - Zero amount not allowed
  - STX transfer failures

#### `file_vulnerability_report`
Submit a bug bounty claim for a discovered vulnerability.
```clarity
(file_vulnerability_report (reporter_address principal) (bounty_payout uint))
```
- **Parameters**: 
  - `reporter_address` - Principal address of the reporter
  - `bounty_payout` - Requested bounty amount
- **Returns**: `(ok report_id)` with the new report ID
- **Errors**:
  - `ERR_NOT_AUTHORIZED` - Caller not an active researcher
  - `ERR_INPUT_ERROR` - Invalid reporter principal
  - `ERR_MINIMUM_NOT_MET` - Invalid bounty amount
  - `ERR_REVIEW_EXPIRED` - Active period expired

#### `submit_review`
Review a pending bounty claim.
```clarity
(submit_review (report_id uint) (approve_bounty bool))
```
- **Parameters**:
  - `report_id` - ID of the report to review
  - `approve_bounty` - Boolean indicating approval/rejection
- **Returns**: `(ok true)` on successful review
- **Errors**:
  - `ERR_BOUNTY_UNKNOWN` - Invalid report ID
  - `ERR_NOT_AUTHORIZED` - Caller not a researcher
  - `ERR_REVIEW_EXPIRED` - Review period closed
  - `ERR_DUPLICATE_REVIEW` - Already reviewed this report

### System Functions

#### `progress_epoch`
Updates the system's epoch counter.
```clarity
(progress_epoch)
```
- **Returns**: `(ok updated_epoch)` with the new epoch value
- **Errors**:
  - `ERR_COOLDOWN_ACTIVE` - Repeated calls from same researcher

#### `get_epoch`
Read-only function to check the current epoch.
```clarity
(get_epoch)
```
- **Returns**: Current epoch value

## Error Codes

| Code | Description |
|------|-------------|
| `ERR_NOT_AUTHORIZED (u1)` | Caller lacks necessary permissions |
| `ERR_STAKE_REQUIRED (u2)` | Stake amount insufficient |
| `ERR_BOUNTY_INVALID (u3)` | Bounty parameters invalid |
| `ERR_DUPLICATE_REVIEW (u4)` | Already reviewed this report |
| `ERR_REVIEW_EXPIRED (u5)` | Review period has expired |
| `ERR_COOLDOWN_ACTIVE (u6)` | Sequential updates from same researcher not allowed |
| `ERR_INPUT_ERROR (u7)` | Input validation failed |
| `ERR_MINIMUM_NOT_MET (u8)` | Amount below minimum threshold |
| `ERR_BOUNTY_UNKNOWN (u9)` | Referenced report doesn't exist |

## Implementation Details

### Data Structures

The contract uses three primary data maps:
1. `researcher_registry` - Tracks researcher stakes and status
2. `vulnerability_reports` - Stores bounty claim details
3. `review_ledger` - Records review activity per researcher per report

### Security Considerations

- Sequential update protection prevents epoch manipulation
- Comprehensive input validation for all public functions
- Protection against duplicate reviews
- Time-bound actions with deadline enforcement

## Usage Example

1. Become a researcher:
```clarity
;; Stake 100 STX to join the platform
(contract-call? .bugbounty-hunter stake_as_researcher u100000000)
```

2. File a vulnerability report:
```clarity
;; Submit report for researcher SP123... requesting 50 STX bounty
(contract-call? .bugbounty-hunter file_vulnerability_report 'SP123456789ABCDEFGHJKL u50000000)
```

3. Review a bounty claim:
```clarity
;; Approve report #5
(contract-call? .bugbounty-hunter submit_review u5 true)
```

4. Check current epoch:
```clarity
(contract-call? .bugbounty-hunter get_epoch)
```