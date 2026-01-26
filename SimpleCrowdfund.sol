// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

contract SimpleCrowdfund {
    address public owner;

    uint256 public goal;
    uint256 public deadline;

    uint256 public totalRaised;
    bool public ownerClaimed;

    mapping(address => uint256) public contributions;

    error NotOwner();
    error ZeroAmount();
    error CampaignEnded();
    error CampaignNotEnded();
    error GoalNotReached();
    error GoalReached();
    error NothingToRefund();
    error AlreadyClaimed();

    event Contributed(address indexed user, uint256 amount);
    event Refunded(address indexed user, uint256 amount);
    event OwnerClaimed(address indexed owner, uint256 amount);

    constructor(uint256 _goal, uint256 _durationSeconds) {
        owner = msg.sender;
        goal = _goal;
        deadline = block.timestamp + _durationSeconds;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    function contribute() external payable {
        if (msg.value == 0) revert ZeroAmount();
        if (block.timestamp >= deadline) revert CampaignEnded();

        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;

        emit Contributed(msg.sender, msg.value);
    }

    function claimAsOwner() external onlyOwner {
        if (block.timestamp < deadline) revert CampaignNotEnded();
        if (totalRaised < goal) revert GoalNotReached();
        if (ownerClaimed) revert AlreadyClaimed();

        ownerClaimed = true;

        uint256 amount = address(this).balance;
        (bool ok, ) = owner.call{value: amount}("");
        require(ok);

        emit OwnerClaimed(owner, amount);
    }

    function refund() external {
        if (block.timestamp < deadline) revert CampaignNotEnded();
        if (totalRaised >= goal) revert GoalReached();

        uint256 amount = contributions[msg.sender];
        if (amount == 0) revert NothingToRefund();

        contributions[msg.sender] = 0;

        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok);

        emit Refunded(msg.sender, amount);
    }

    function timeLeft() external view returns (uint256) {
        if (block.timestamp >= deadline) return 0;
        return deadline - block.timestamp;
    }

    function isGoalReached() external view returns (bool) {
        return totalRaised >= goal;
    }
}
