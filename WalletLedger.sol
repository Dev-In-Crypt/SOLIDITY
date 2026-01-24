// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

contract WalletLedger {
    mapping(address => uint256) public balances;
    mapping(address => uint256) public pendingWithdrawals;

    address public owner;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Transferred(address indexed from, address indexed to, uint256 amount);
    event PendingWithdrawalAdded(address indexed from, address indexed to, uint256 amount);
    event Claimed(address indexed user, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function _creditBalance(address user, uint256 amount) internal {
        balances[user] += amount;
        emit Deposited(user, amount);
    }

    function deposit() external payable {
        require(msg.value > 0, "No ETH sent");
        _creditBalance(msg.sender, msg.value);
    }

    receive() external payable {
        require(msg.value > 0, "No ETH sent");
        _creditBalance(msg.sender, msg.value);
    }

    fallback() external payable {
        revert("Calldata not allowed");
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "Amount = 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        balances[msg.sender] -= amount;

        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "ETH transfer failed");

        emit Withdrawn(msg.sender, amount);
    }

    function transferTo(address to, uint256 amount) external {
        require(to != address(0), "Zero address");
        require(amount > 0, "Amount = 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        balances[msg.sender] -= amount;
        balances[to] += amount;

        emit Transferred(msg.sender, to, amount);
    }

    function payFromBalance(address to, uint256 amount) external {
        require(to != address(0), "Zero address");
        require(amount > 0, "Amount = 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        balances[msg.sender] -= amount;
        pendingWithdrawals[to] += amount;

        emit PendingWithdrawalAdded(msg.sender, to, amount);
    }

    function claim() external {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "Nothing to claim");

        pendingWithdrawals[msg.sender] = 0;

        (bool ok, ) = payable(msg.sender).call{value: amount}("");
        require(ok, "ETH transfer failed");

        emit Claimed(msg.sender, amount);
    }

    function sendEther(address payable to, uint256 amount) external onlyOwner {
        require(to != address(0), "Zero address");
        require(amount > 0, "Amount = 0");
        require(address(this).balance >= amount, "Not enough ETH");

        (bool ok, ) = to.call{value: amount}("");
        require(ok, "ETH transfer failed");
    }
}
