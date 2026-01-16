// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ISimpleToken {
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
}

contract StakingPool {
    ISimpleToken public stakingToken;
    address public owner;
    uint256 public rewardRate;

    struct StakeInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    mapping(address => StakeInfo) public stakes;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 reward);
    event RewardRateUpdated(uint256 newRate);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _token, uint256 _rewardRate) {
        owner = msg.sender;
        stakingToken = ISimpleToken(_token);
        rewardRate = _rewardRate;
    }

    function setRewardRate(uint256 _rewardRate) external onlyOwner {
        rewardRate = _rewardRate;
        emit RewardRateUpdated(_rewardRate);
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Amount = 0");
        stakingToken.transferFrom(msg.sender, address(this), amount);

        StakeInfo storage info = stakes[msg.sender];
        info.amount += amount;
        info.rewardDebt += amount * rewardRate;

        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external {
        StakeInfo storage info = stakes[msg.sender];
        require(info.amount >= amount && amount > 0, "Invalid amount");

        uint256 reward = (info.amount * rewardRate) - info.rewardDebt;

        info.amount -= amount;
        info.rewardDebt = info.amount * rewardRate;

        stakingToken.transfer(msg.sender, amount);
        if (reward > 0) {
            stakingToken.transfer(msg.sender, reward);
        }

        emit Unstaked(msg.sender, amount, reward);
    }
}
