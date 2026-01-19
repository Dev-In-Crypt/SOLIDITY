// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract SimpleLending {
    IERC20 public collateralToken; // ERC20 для займов
    mapping(address => uint256) public collateral; // user => ETH shares
    mapping(address => uint256) public debt; // user => borrowed amount
    uint256 public totalCollateral; // total ETH shares
    uint256 public totalDebt;
    uint256 public constant LTV = 70; // 70% loan-to-value
    uint256 public constant INTEREST_RATE = 5; // 5% per borrow (simplified)

    constructor(address _collateralToken) {
        collateralToken = IERC20(_collateralToken);
    }

    function depositCollateral() external payable {
        require(msg.value > 0, "no collateral");
        collateral[msg.sender] += msg.value;
        totalCollateral += msg.value;
    }

    function borrow(uint256 amount) external {
        uint256 userCollateralValue = collateral[msg.sender] * 100;
        uint256 maxBorrow = (userCollateralValue * LTV) / 100;
        uint256 newDebt = debt[msg.sender] + amount * (100 + INTEREST_RATE) / 100;
        require(newDebt <= maxBorrow, "over LTV");
        require(collateralToken.balanceOf(address(this)) >= amount, "insufficient liquidity");

        debt[msg.sender] = newDebt;
        totalDebt += amount;
        collateralToken.transfer(msg.sender, amount);
    }

    function repay(uint256 amount) external {
        debt[msg.sender] -= amount;
        totalDebt -= amount;
        collateralToken.transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) external {
        require(collateral[msg.sender] >= amount, "insufficient collateral");
        uint256 userDebt = debt[msg.sender];
        require(userDebt == 0, "has debt");
        collateral[msg.sender] -= amount;
        totalCollateral -= amount;
        payable(msg.sender).transfer(amount);
    }

    function getHealth(address user) external view returns (uint256) {
        if (collateral[user] == 0) return 100;
        uint256 health = (collateral[user] * 100 * 100) / debt[user] / LTV;
        return health;
    }
}
