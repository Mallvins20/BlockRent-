 BlockRent — Decentralized Land Rental Agreement Smart Contract (Clarity)

**Version:** 1.0  
**Language:** [Clarity](https://docs.stacks.co/write-smart-contracts/clarity)  
**Author:** `tx-sender` (contract deployer)  
**License:** MIT  

Overview

`BlockRent.clar` is a **secure and transparent Clarity smart contract** designed to manage **land rental agreements** on the Stacks blockchain.  
It provides a decentralized system for registering land parcels, creating and managing lease agreements, and facilitating rent payments between landlords and tenants — all without intermediaries.

The contract is built with **security, auditability, and real-world usability** in mind.

---

 Features

 Land Management
- Register new land parcels with metadata.  
- Transfer ownership of registered lands to another principal.  
- Prevents invalid transfers and ensures ownership authenticity.

 Rental Agreements
- Create rental agreements between landlord and tenant.
- Define rent amount, duration, and payment period.
- Optional **auto-renew** functionality.

 Rent Payment
- Tenants pay rent directly in STX to the landlord.
- Validations ensure correct and active agreement.
- Payment events are logged for audit transparency.

 Agreement Renewal & Termination
- Renew contracts with additional duration.
- Terminate agreements with reason logging.
- Both parties (landlord/tenant) can initiate termination.

 Admin Controls
- Contract owner can **deactivate** agreements for compliance or security issues.
- Includes logging for every admin action.

Security Features

| Protection | Description |
|-------------|--------------|
| **Principal Validation** | Prevents self-transactions (e.g., landlord = tenant). |
| **Zero-Value Checks** | Ensures non-zero land IDs, durations, and rent amounts. |
| **Access Control** | Restricts functions to authorized users only. |
| **Input Validation** | Checks string lengths, positive integers, and valid periods. |
| **Event Logging** | Every key operation is recorded on-chain. |

 Data Structures

### 🏠 `lands`
| Field | Type | Description |
|-------|------|-------------|
| `land-id` | `uint` | Unique identifier for land parcel |
| `owner` | `principal` | Current land owner |
| `meta` | `string-ascii (64)` | Land metadata (e.g., location or description) |

`agreements`
| Field | Type | Description |
|-------|------|-------------|
| `agreement-id` | `uint` | Unique agreement identifier |
| `land-id` | `uint` | Linked land parcel |
| `landlord` | `principal` | Land owner |
| `tenant` | `principal` | Renter |
| `rent-amount` | `uint` | STX rent per period |
| `start-block` | `uint` | Agreement start block |
| `duration` | `uint` | Total duration in blocks |
| `period` | `uint` | Rent payment frequency (in blocks) |
| `auto-renew` | `bool` | Whether agreement auto-renews |
| `active` | `bool` | Whether the agreement is active |

Key Public Functions

| Function | Description |
|-----------|-------------|
| `register-land(meta)` | Register a new land parcel. |
| `transfer-land(land-id, new-owner)` | Transfer ownership of a registered land. |
| `create-agreement(land-id, tenant, rent, duration, period, auto-renew)` | Create a rental agreement. |
| `pay-rent(agreement-id)` | Pay rent in STX from tenant to landlord. |
| `renew-agreement(agreement-id, extra-duration)` | Extend an existing agreement. |
| `terminate-agreement(agreement-id, reason)` | End an agreement with reason logging. |
| `admin-deactivate(agreement-id, reason)` | Admin-only emergency termination. |

 Read-Only (Query) Functions

| Function | Description |
|-----------|-------------|
| `get-land(land-id)` | View land information. |
| `get-agreement(agreement-id)` | View agreement details. |
| `is-agreement-active(agreement-id)` | Check if an agreement is active. |
| `agreement-expiry(agreement-id)` | Get the expiry block of an agreement. |
| `next-rent-due(agreement-id)` | Calculate next rent due block. |
| `get-counters()` | View total number of lands and agreements. |
| `get-contract-owner()` | Returns the contract owner principal. |

 Example Workflow

1. **Land Registration**
   ```clarity
   (contract-call? .blockrent register-land "Plot 21, Kaduna South")
