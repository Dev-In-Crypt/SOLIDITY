// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address user) external view returns (uint256);
}

contract SimpleTokenVesting {
    IERC20 public immutable token;
    address public immutable owner;

    uint256 public immutable start;
    uint256 public immutable duration;

    uint256 public totalAllocation;
    uint256 public totalClaimed;
    bool public initialized;

    mapping(address => uint256) public allocation;
    mapping(address => uint256) public claimed;

    error NotOwner();
    error NotInitialized();
    error AlreadyInitialized();
    error ZeroAddress();
    error ZeroAmount();
    error BadArrayLength();
    error NotEnoughTokensInContract();
    error NothingToClaim();

    event Initialized(uint256 totalAllocation);
    event AllocationSet(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 amount);

    constructor(address tokenAddress, uint256 _start, uint256 _duration) {
        if (tokenAddress == address(0)) revert ZeroAddress();
        if (_duration == 0) revert ZeroAmount();

        token = IERC20(tokenAddress);
        owner = msg.sender;
        start = _start;
        duration = _duration;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    function setAllocations(address[] calldata users, uint256[] calldata amounts) external onlyOwner {
        if (initialized) revert AlreadyInitialized();
        if (users.length != amounts.length) revert BadArrayLength();

        uint256 sum;

        for (uint256 i = 0; i < users.length; i++) {
            address u = users[i];
            uint256 a = amounts[i];

            if (u == address(0)) revert ZeroAddress();

            allocation[u] = a;
            sum += a;

            emit AllocationSet(u, a);
        }

        totalAllocation = sum;

        if (token.balanceOf(address(this)) < totalAllocation) revert NotEnoughTokensInContract();

        initialized = true;
        emit Initialized(totalAllocation);
    }

    function vestedAmount(address user) public view returns (uint256) {
        if (!initialized) return 0;

        uint256 alloc = allocation[user];
        if (alloc == 0) return 0;

        if (block.timestamp <= start) return 0;

        uint256 elapsed = block.timestamp - start;
        if (elapsed >= duration) return alloc;

        return (alloc * elapsed) / duration;
    }

    function claimable(address user) public view returns (uint256) {
        uint256 vested = vestedAmount(user);
        uint256 already = claimed[user];
        if (vested <= already) return 0;
        return vested - already;
    }

    function claim() external {
        if (!initialized) revert NotInitialized();

        uint256 amount = claimable(msg.sender);
        if (amount == 0) revert NothingToClaim();

        claimed[msg.sender] += amount;
        totalClaimed += amount;

        bool ok = token.transfer(msg.sender, amount);
        require(ok);

        emit Claimed(msg.sender, amount);
    }

    function rescueTokens(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        bool ok = token.transfer(to, amount);
        require(ok);
    }
}
