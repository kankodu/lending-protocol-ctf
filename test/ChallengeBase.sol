// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {LendingPool} from "../src/LendingPool.sol";
import {Token} from "../src/Token.sol";

abstract contract ChallengeBase is Test {
    LendingPool internal pool;
    Token internal loanToken;
    Token internal collateralToken;

    address internal deployer = makeAddr("deployer");
    address internal ALICE = address(0xA11CE);
    address internal BOB = address(0xB0B);
    address internal ATTACKER = address(0xBEEF);

    uint256 internal constant ONE_YEAR = 365 days;
    uint256 internal constant YEARS_ELAPSED = 4;

    uint256 internal constant ALICE_SUPPLY = 3_000 ether;
    uint256 internal constant BOB_COLLATERAL = 1_500 ether;
    uint256 internal constant BOB_BORROW = 10 ether;

    uint256 internal attackerStartNonce;
    uint256 internal startTimestamp;

    function setUp() public virtual {
        // Deployer receives the entire supply of both tokens and funds the actors.
        startHoax(deployer);
        loanToken = new Token();
        collateralToken = new Token();
        pool = new LendingPool(address(loanToken), address(collateralToken));
        loanToken.transfer(ALICE, ALICE_SUPPLY);
        collateralToken.transfer(BOB, BOB_COLLATERAL);
        vm.stopPrank();

        vm.label(address(loanToken), "LOAN");
        vm.label(address(collateralToken), "COLLATERAL");

        // Multiple addresses represented as ALICE lend into the pool.
        vm.startPrank(ALICE);
        loanToken.approve(address(pool), type(uint256).max);
        pool.supply(ALICE_SUPPLY);
        vm.stopPrank();

        // Multiple addresses represented as BOB open over collateralised borrows
        vm.startPrank(BOB);
        collateralToken.approve(address(pool), type(uint256).max);
        pool.supplyCollateral(BOB_COLLATERAL);
        pool.borrow(BOB_BORROW);
        vm.stopPrank();

        // Four years of normal operations
        for (uint256 i = 0; i < YEARS_ELAPSED; i++) {
            vm.warp(block.timestamp + ONE_YEAR);
            pool.accrueInterest();
        }

        vm.label(ATTACKER, "ATTACKER");
        attackerStartNonce = vm.getNonce(ATTACKER);
        startTimestamp = block.timestamp;
    }

    function _assertSolved() internal {
        // time warping is not allowed
        assertEq(block.timestamp, startTimestamp, "time was warped");
        assertEq(pool.lastUpdate(), startTimestamp, "pool accrued at a warped timestamp");
        // do the attack in one tx
        assertLe(vm.getNonce(ATTACKER), attackerStartNonce + 1, "attacker sent more than one tx");
        
        // get away with atleast 500 Loan tokens
        assertGe(loanToken.balanceOf(ATTACKER), 500 ether, "no drain: attacker holds < 500 LOAN");
        assertEq(pool.borrowShares(ATTACKER), 0, "debt was recorded: not a free borrow");
    }
}
