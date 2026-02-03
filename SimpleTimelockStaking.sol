// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address user) external view returns (uint256);
}

contract SimpleTimelockStaking {
    IERC20 public immutable stakeToken;
    IERC20 public immutable rewardToken;
    address public owner;

    uint256 public lockSeconds;
    uint256 public rewardRatePerSecond;
    uint256 public periodFinish;
    uint256 public lastUpdateTime;
    uint256 public accRewardPerToken;
    uint256 public totalStaked;

    uint256 private constant PRECISION = 1e18;

    mapping(address => uint256) public staked;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public unlockAt;

    error NotOwner();
    error ZeroAddress();
    error ZeroAmount();
    error LockActive();
    error NotEnoughStaked();
    error NoRewardsConfigured();
    error TransferFailed();

    event Staked(address indexed user, uint256 amount, uint256 unlockAt);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 amount);
    event RewardNotified(uint256 rewardAmount, uint256 duration, uint256 ratePerSecond);
    event LockChanged(uint256 newLockSeconds);
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);

    constructor(address _stakeToken, address _rewardToken, uint256 _lockSeconds) {
        if (_stakeToken == address(0) || _rewardToken == address(0)) revert ZeroAddress();
        owner = msg.sender;
        stakeToken = IERC20(_stakeToken);
        rewardToken = IERC20(_rewardToken);
        lockSeconds = _lockSeconds;
        lastUpdateTime = block.timestamp;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        uint256 t = block.timestamp;
        return t < periodFinish ? t : periodFinish;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) return accRewardPerToken;
        uint256 t = lastTimeRewardApplicable();
        uint256 dt = t - lastUpdateTime;
        return accRewardPerToken + (dt * rewardRatePerSecond * PRECISION) / totalStaked;
    }

    function earned(address account) public view returns (uint256) {
        uint256 rpt = rewardPerToken();
        uint256 delta = rpt - userRewardPerTokenPaid[account];
        return rewards[account] + (staked[account] * delta) / PRECISION;
    }

    function _updateReward(address account) internal {
        accRewardPerToken = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = accRewardPerToken;
        }
    }

    function notifyReward(uint256 rewardAmount, uint256 durationSeconds) external onlyOwner {
        if (rewardAmount == 0 || durationSeconds == 0) revert ZeroAmount();

        _updateReward(address(0));

        rewardRatePerSecond = rewardAmount / durationSeconds;
        if (rewardRatePerSecond == 0) revert ZeroAmount();

        periodFinish = block.timestamp + durationSeconds;
        lastUpdateTime = block.timestamp;

        bool ok = rewardToken.transferFrom(msg.sender, address(this), rewardAmount);
        if (!ok) revert TransferFailed();

        emit RewardNotified(rewardAmount, durationSeconds, rewardRatePerSecond);
    }

    function stake(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (rewardRatePerSecond == 0) revert NoRewardsConfigured();

        _updateReward(msg.sender);

        totalStaked += amount;
        staked[msg.sender] += amount;

        uint256 u = block.timestamp + lockSeconds;
        if (u > unlockAt[msg.sender]) unlockAt[msg.sender] = u;

        bool ok = stakeToken.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        emit Staked(msg.sender, amount, unlockAt[msg.sender]);
    }

    function withdraw(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (staked[msg.sender] < amount) revert NotEnoughStaked();
        if (block.timestamp < unlockAt[msg.sender]) revert LockActive();

        _updateReward(msg.sender);

        totalStaked -= amount;
        staked[msg.sender] -= amount;

        bool ok = stakeToken.transfer(msg.sender, amount);
        if (!ok) revert TransferFailed();

        emit Withdrawn(msg.sender, amount);
    }

    function claimReward() external {
        _updateReward(msg.sender);

        uint256 reward = rewards[msg.sender];
        if (reward == 0) revert ZeroAmount();

        rewards[msg.sender] = 0;

        bool ok = rewardToken.transfer(msg.sender, reward);
        if (!ok) revert TransferFailed();

        emit RewardPaid(msg.sender, reward);
    }

    function setLockSeconds(uint256 newLockSeconds) external onlyOwner {
        lockSeconds = newLockSeconds;
        emit LockChanged(newLockSeconds);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnerChanged(old, newOwner);
    }

    function rescueRewardTokens(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        bool ok = rewardToken.transfer(to, amount);
        if (!ok) revert TransferFailed();
    }
}
