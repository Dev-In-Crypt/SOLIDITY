// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

contract SimpleETHVault {
    address public owner;
    bool public paused;

    mapping(address => uint256) public balance;

    error NotOwner();
    error Paused();
    error ZeroAmount();
    error NotEnoughBalance();
    error TransferFailed();

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event PausedSet(bool paused);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    function deposit() external payable whenNotPaused {
        if (msg.value == 0) revert ZeroAmount();
        balance[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (balance[msg.sender] < amount) revert NotEnoughBalance();

        balance[msg.sender] -= amount;

        (bool ok, ) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit Withdrawn(msg.sender, amount);
    }

    function setPaused(bool v) external onlyOwner {
        paused = v;
        emit PausedSet(v);
    }
}
