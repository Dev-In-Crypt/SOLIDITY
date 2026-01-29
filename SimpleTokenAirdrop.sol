// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract SimpleTokenAirdrop {
    address public owner;
    IERC20 public token;

    mapping(address => bool) public claimed;
    uint256 public claimAmount;
    uint256 public claimDeadline;

    error NotOwner();
    error ZeroAddress();
    error ZeroAmount();
    error ClaimEnded();
    error AlreadyClaimed();
    error TransferFailed();

    event Claimed(address indexed user, uint256 amount);
    event Configured(uint256 claimAmount, uint256 claimDeadline);
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);

    constructor(address tokenAddress, uint256 _claimAmount, uint256 _durationSeconds) {
        if (tokenAddress == address(0)) revert ZeroAddress();
        if (_claimAmount == 0) revert ZeroAmount();

        owner = msg.sender;
        token = IERC20(tokenAddress);
        claimAmount = _claimAmount;
        claimDeadline = block.timestamp + _durationSeconds;

        emit Configured(claimAmount, claimDeadline);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    function claim() external {
        if (block.timestamp > claimDeadline) revert ClaimEnded();
        if (claimed[msg.sender]) revert AlreadyClaimed();

        claimed[msg.sender] = true;

        bool ok = token.transfer(msg.sender, claimAmount);
        if (!ok) revert TransferFailed();

        emit Claimed(msg.sender, claimAmount);
    }

    function setClaimAmount(uint256 newAmount) external onlyOwner {
        if (newAmount == 0) revert ZeroAmount();
        claimAmount = newAmount;
        emit Configured(claimAmount, claimDeadline);
    }

    function extendDeadline(uint256 extraSeconds) external onlyOwner {
        if (extraSeconds == 0) revert ZeroAmount();
        claimDeadline += extraSeconds;
        emit Configured(claimAmount, claimDeadline);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnerChanged(old, newOwner);
    }

    function withdrawTokens(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        bool ok = token.transfer(to, amount);
        if (!ok) revert TransferFailed();
    }
}
