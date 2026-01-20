// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
}

contract SimpleStaking {
    IERC20 public stakingToken;
    address public owner;

    mapping(address => uint256) public staked;
    mapping(address => uint256) public rewards;

    uint256 public constant REWARD_PERCENT = 10;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 reward);
    event RewardFunded(uint256 amount);
    event EmergencyWithdraw(address indexed to, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor(address _stakingToken) {
        stakingToken = IERC20(_stakingToken);
        owner = msg.sender;
    }

    function fundRewards(uint256 amount) external onlyOwner {
        require(amount > 0, "amount = 0");
        bool ok = stakingToken.transferFrom(msg.sender, address(this), amount);
        require(ok, "transfer failed");
        emit RewardFunded(amount);
    }

    function stake(uint256 amount) external {
        require(amount > 0, "amount = 0");

        bool ok = stakingToken.transferFrom(msg.sender, address(this), amount);
        require(ok, "transfer failed");

        staked[msg.sender] += amount;

        uint256 reward = (amount * REWARD_PERCENT) / 100;
        rewards[msg.sender] += reward;

        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external {
        require(amount > 0, "amount = 0");
        require(staked[msg.sender] >= amount, "not enough staked");

        uint256 totalUserStake = staked[msg.sender];
        uint256 totalUserReward = rewards[msg.sender];

        uint256 rewardShare = (totalUserReward * amount) / totalUserStake;

        staked[msg.sender] -= amount;
        rewards[msg.sender] -= rewardShare;

        uint256 payout = amount + rewardShare;
        require(
            stakingToken.balanceOf(address(this)) >= payout,
            "not enough tokens in pool"
        );

        bool ok = stakingToken.transfer(msg.sender, payout);
        require(ok, "transfer failed");

        emit Unstaked(msg.sender, amount, rewardShare);
    }

    function emergencyWithdraw(address to, uint256 amount)
        external
        onlyOwner
    {
        require(to != address(0), "zero address");
        bool ok = stakingToken.transfer(to, amount);
        require(ok, "transfer failed");
        emit EmergencyWithdraw(to, amount);
    }
}
