# LendingPool CTF

Just knowing the bug won't get you a payout. You have to show how it can be weaponised now or be ready to be dismissed as "known issue". 

## Setup

- `LendingPool` lends `loanToken` against `collateralToken` (1:1 price, 80% LTV, ~20% fixed interest rate).
- Multiple depositors represented as Alice supplies 3,000 loan tokens.
- Multiple borrowers represented as Bob deposits 1,500 collateral and borrows 10.
- Four years pass, with interest accrued once a year.

## Goal

Starting as `ATTACKER` with no tokens and no collateral, walk away with **at least 500 loan tokens** while having **zero borrow shares** recorded against you.

## Rules

- One transaction only: the attacker's nonce may increase by at most 1.
- No time warping.
- Do not simply deal yourself the tokens. Take flash loan from the contract if you need to hold tokens temporarily.
- Don't modify `setUp()` or `_assertSolved()`.

## Run

```sh
forge install
forge test --match-contract Challenge -vvv
```

Write your exploit in `test/Challenge.t.sol`.
