// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address user) external view returns (uint256);
}

contract SimpleTokenLockup {
    IERC20 public immutable token;
    address public owner;

    uint256 public lockEnd;
    bool public funded;

    uint256 public totalShares;
    mapping(address => uint256) public shares;
    mapping(address => bool) public claimed;

    error NotOwner();
    error ZeroAddress();
    error ZeroAmount();
    error AlreadyFunded();
    error NotFunded();
    error TooEarly();
    error NothingToClaim();
    error AlreadyClaimed();
    error BadArrayLength();
    error TransferFailed();

    event Funded(uint256 amount, uint256 lockEnd);
    event SharesSet(address indexed user, uint256 share);
    event Claimed(address indexed user, uint256 amount);
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);

    constructor(address tokenAddress, uint256 lockEndTimestamp) {
        if (tokenAddress == address(0)) revert ZeroAddress();
        if (lockEndTimestamp <= block.timestamp) revert ZeroAmount();

        token = IERC20(tokenAddress);
        owner = msg.sender;
        lockEnd = lockEndTimestamp;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    function setShares(address[] calldata users, uint256[] calldata userShares) external onlyOwner {
        if (funded) revert AlreadyFunded();
        if (users.length != userShares.length) revert BadArrayLength();

        uint256 sum;

        for (uint256 i = 0; i < users.length; i++) {
            address u = users[i];
            uint256 s = userShares[i];

            if (u == address(0)) revert ZeroAddress();
            if (s == 0) revert ZeroAmount();

            if (shares[u] == 0) {
                shares[u] = s;
                sum += s;
            } else {
                sum = sum - shares[u] + s;
                shares[u] = s;
            }

            emit SharesSet(u, s);
        }

        totalShares = sum;
    }

    function fund(uint256 amount) external onlyOwner {
        if (amount == 0) revert ZeroAmount();
        if (funded) revert AlreadyFunded();
        if (totalShares == 0) revert ZeroAmount();

        funded = true;

        bool ok = token.transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        emit Funded(amount, lockEnd);
    }

    function claim() external {
        if (!funded) revert NotFunded();
        if (block.timestamp < lockEnd) revert TooEarly();
        if (claimed[msg.sender]) revert AlreadyClaimed();

        uint256 s = shares[msg.sender];
        if (s == 0) revert NothingToClaim();

        claimed[msg.sender] = true;

        uint256 bal = token.balanceOf(address(this));
        uint256 amount = (bal * s) / totalShares;

        bool ok = token.transfer(msg.sender, amount);
        if (!ok) revert TransferFailed();

        emit Claimed(msg.sender, amount);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address old = owner;
        owner = newOwner;
        emit OwnerChanged(old, newOwner);
    }

    function rescue(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        bool ok = token.transfer(to, amount);
        if (!ok) revert TransferFailed();
    }
}
