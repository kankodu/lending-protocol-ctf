// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ChallengeBase} from "./ChallengeBase.sol";

/// @notice Starting as ATTACKER with no tokens and no collateral, end up holding
///         at least 500 LOAN Token while having 0 borrow shares recorded against you.
///
///         Run: forge test --match-contract Challenge -vvv
contract Challenge is ChallengeBase {
    function test_solve() public {
        vm.startPrank(ATTACKER);

        // TODO: your solution goes here.

        vm.stopPrank();

        _assertSolved();
    }
}
