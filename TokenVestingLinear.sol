// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract TokenVestingLinear {
    IERC20 public immutable token;
    address public owner;

    uint256 public immutable start;
    uint256 public immutable duration;

    uint256 public totalAllocated;
    bool public sealed;

    mapping(address => uint256) public allocation;
    mapping(address => uint256) public claimed;

    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    event BeneficiarySet(address indexed user, uint256 amount);
    event Sealed(uint256 totalAllocated);
    event Claimed(address indexed user, uint256 amount);
    event Rescued(address indexed to, uint256 amount);

    constructor(address tokenAddress, uint256 startTimestamp, uint256 durationSeconds) {
        require(tokenAddress != address(0), "token=0");
        require(durationSeconds > 0, "duration=0");

        token = IERC20(tokenAddress);
        owner = msg.sender;
        start = startTimestamp;
        duration = durationSeconds;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    function setBeneficiaries(address[] calldata users, uint256[] calldata amounts) external onlyOwner {
        require(!sealed, "sealed");
        require(users.length == amounts.length, "len");

        uint256 sum = totalAllocated;

        for (uint256 i = 0; i < users.length; i++) {
            address u = users[i];
            uint256 a = amounts[i];

            require(u != address(0), "user=0");

            sum = sum - allocation[u] + a;
            allocation[u] = a;

            emit BeneficiarySet(u, a);
        }

        totalAllocated = sum;
    }

    function seal() external onlyOwner {
        require(!sealed, "sealed");
        require(totalAllocated > 0, "alloc=0");
        sealed = true;
        emit Sealed(totalAllocated);
    }

    function vested(address user) public view returns (uint256) {
        uint256 alloc = allocation[user];
        if (alloc == 0) return 0;

        if (block.timestamp <= start) return 0;

        uint256 elapsed = block.timestamp - start;
        if (elapsed >= duration) return alloc;

        return (alloc * elapsed) / duration;
    }

    function claimable(address user) public view returns (uint256) {
        uint256 v = vested(user);
        uint256 c = claimed[user];
        if (v <= c) return 0;
        return v - c;
    }

    function claim() external {
        require(sealed, "not sealed");

        uint256 amount = claimable(msg.sender);
        require(amount > 0, "nothing");

        claimed[msg.sender] += amount;

        bool ok = token.transfer(msg.sender, amount);
        require(ok, "transfer failed");

        emit Claimed(msg.sender, amount);
    }

    function rescueTokens(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "to=0");
        require(amount > 0, "amount=0");

        bool ok = token.transfer(to, amount);
        require(ok, "transfer failed");

        emit Rescued(to, amount);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "owner=0");
        address old = owner;
        owner = newOwner;
        emit OwnerChanged(old, newOwner);
    }
}
