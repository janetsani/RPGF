## RPGF.clar overview

This project contains a single Clarity contract at `contracts/RPGF.clar` that manages milestone-based payouts from a tracked SIP-010 token pool (intended for sBTC), with admin-controlled configuration and milestone registration.

### Key data

- `admin`: principal that can configure the contract.
- `next-id`: auto-incremented milestone id counter.
- `sbtc-token`: optional principal of the SIP-010 token contract.
- `pool-balance`: tracked token balance held by this contract.
- `milestones`: map keyed by `id` with fields:
  - `description`: `(string-ascii 64)`
  - `target-calls`: `uint`
  - `payout`: `uint`
  - `claimant`: `principal`
  - `target-contract`: `principal`
  - `claimed`: `bool`

### Traits

- `sip010-ft`: defines `transfer`.
- `interaction-count-trait`: defines `get-interaction-count`.

### Public functions

- `set-admin(new-admin)`: admin-only; sets the admin principal.
- `set-sbtc-token(token)`: admin-only; stores the SIP-010 token contract principal.
- `deposit-sbtc(token, amount)`: transfers tokens from caller into the contract and increments `pool-balance`.
- `withdraw-sbtc(token, amount, recipient)`: admin-only; transfers tokens from contract to `recipient` and decrements `pool-balance`.
- `register-milestone(description, target-calls, payout, claimant, target-contract)`: admin-only; stores a milestone and returns its id.
- `claim-milestone(id, target-contract, token)`: checks milestone status, verifies target contract interaction count, transfers payout, and marks milestone claimed.

### Read-only functions

- `get-admin()`
- `get-sbtc-token()`
- `get-pool-balance()`
- `get-milestone(id)`

### Errors

The contract uses fixed error codes for authorization, input validation, pool balance, token/target mismatch, and missing or already claimed milestones. See the constants in `contracts/RPGF.clar` for the full list.
