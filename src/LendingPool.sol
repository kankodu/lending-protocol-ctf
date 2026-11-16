// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20, IFreeLunchFlashLoanCallback} from "./interfaces/Interfaces.sol";

contract LendingPool {
    uint256 internal constant WAD = 1e18;
    uint256 internal constant ORACLE_PRICE_SCALE = 1e36;

    /// @notice Price of 1 collateral token in loan tokens, scaled by ORACLE_PRICE_SCALE (1:1).
    uint256 public constant COLLATERAL_PRICE = 1e36;

    /// @notice Loan-to-value ratio, scaled by WAD.
    uint256 public constant LLTV = 0.8e18;
    /// @notice ~20% APR as a per-second rate, scaled by WAD.
    uint256 public constant BORROW_RATE = 6_341_958_396;

    IERC20 public immutable loanToken;
    IERC20 public immutable collateralToken;

    uint256 public totalSupplyAssets;
    uint256 public totalSupplyShares;
    uint256 public totalBorrowAssets;
    uint256 public totalBorrowShares;
    uint256 public lastUpdate;

    mapping(address => uint256) public supplyShares;
    mapping(address => uint256) public borrowShares;
    mapping(address => uint256) public collateral;

    constructor(address _loanToken, address _collateralToken) {
        loanToken = IERC20(_loanToken);
        collateralToken = IERC20(_collateralToken);
        lastUpdate = block.timestamp;
    }

    function supply(uint256 assets) external returns (uint256 shares) {
        _accrueInterest();
        shares = totalSupplyShares == 0 ? assets : assets * totalSupplyShares / totalSupplyAssets;
        require(shares != 0, "zero shares");
        supplyShares[msg.sender] += shares;
        totalSupplyShares += shares;
        totalSupplyAssets += assets;
        loanToken.transferFrom(msg.sender, address(this), assets);
    }

    function withdraw(uint256 shares) external returns (uint256 assets) {
        _accrueInterest();
        assets = shares * totalSupplyAssets / totalSupplyShares;
        supplyShares[msg.sender] -= shares;
        totalSupplyShares -= shares;
        totalSupplyAssets -= assets;
        require(totalBorrowAssets <= totalSupplyAssets, "insufficient liquidity");
        loanToken.transfer(msg.sender, assets);
    }

    function supplyCollateral(uint256 amount) external {
        collateral[msg.sender] += amount;
        collateralToken.transferFrom(msg.sender, address(this), amount);
    }

    function withdrawCollateral(uint256 amount) external {
        _accrueInterest();
        collateral[msg.sender] -= amount;
        require(_isHealthy(msg.sender), "unhealthy");
        collateralToken.transfer(msg.sender, amount);
    }

    function borrow(uint256 assets) external returns (uint256 shares) {
        _accrueInterest();

        shares = totalBorrowShares == 0 ? assets : assets * totalBorrowShares / totalBorrowAssets;
        require(shares != 0, "zero shares");

        borrowShares[msg.sender] += shares;
        totalBorrowShares += shares;
        totalBorrowAssets += assets;

        require(_isHealthy(msg.sender), "insufficient collateral");
        require(totalBorrowAssets <= totalSupplyAssets, "insufficient liquidity");

        loanToken.transfer(msg.sender, assets);
    }

    function repay(uint256 assets, address onBehalf) external returns (uint256 shares) {
        _accrueInterest();
        shares = assets * totalBorrowShares / totalBorrowAssets;
        borrowShares[onBehalf] -= shares;
        totalBorrowShares -= shares;
        totalBorrowAssets -= assets;
        loanToken.transferFrom(msg.sender, address(this), assets);
    }

    function flashLoan(IERC20 asset, uint256 assets, bytes calldata data) external {
        asset.transfer(msg.sender, assets);
        IFreeLunchFlashLoanCallback(msg.sender).onFreeLunchFlashLoan(asset, assets, data);
        asset.transferFrom(msg.sender, address(this), assets);
    }

    function accrueInterest() external {
        _accrueInterest();
    }

    function _accrueInterest() internal {
        uint256 elapsed = block.timestamp - lastUpdate;
        if (elapsed == 0) return;
        if (totalBorrowAssets != 0) {
            uint256 interest = totalBorrowAssets * BORROW_RATE * elapsed / WAD;
            totalBorrowAssets += interest;
            totalSupplyAssets += interest;
        }
        lastUpdate = block.timestamp;
    }

    function _isHealthy(address user) internal view returns (bool) {
        if (borrowShares[user] == 0) return true;
        uint256 borrowed = borrowShares[user] * totalBorrowAssets / totalBorrowShares;
        uint256 collateralValue = collateral[user] * COLLATERAL_PRICE / ORACLE_PRICE_SCALE;
        uint256 maxBorrow = collateralValue * LLTV / WAD;
        return borrowed <= maxBorrow;
    }
}
