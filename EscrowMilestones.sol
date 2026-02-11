// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract EscrowMilestones {
    address public buyer;
    address public seller;
    address public arbiter;

    uint256 public milestoneCount;
    uint256 public currentMilestone;

    IERC20 public token;
    uint256[] public amounts;

    bool public funded;
    bool public canceled;

    mapping(uint256 => bool) public released;

    event Funded(address indexed buyer, uint256 total);
    event Released(uint256 indexed milestoneId, uint256 amount);
    event Canceled(uint256 indexed milestoneId);
    event Refunded(address indexed buyer, uint256 amount);

    constructor(
        address _buyer,
        address _seller,
        address _arbiter,
        address tokenAddress,
        uint256[] memory milestoneAmounts
    ) {
        require(_buyer != address(0) && _seller != address(0) && _arbiter != address(0), "addr=0");
        require(tokenAddress != address(0), "token=0");
        require(milestoneAmounts.length > 0, "milestones=0");

        buyer = _buyer;
        seller = _seller;
        arbiter = _arbiter;
        token = IERC20(tokenAddress);

        amounts = milestoneAmounts;
        milestoneCount = milestoneAmounts.length;
        currentMilestone = 0;
    }

    modifier onlyBuyer() {
        require(msg.sender == buyer, "not buyer");
        _;
    }

    modifier onlySeller() {
        require(msg.sender == seller, "not seller");
        _;
    }

    modifier onlyArbiter() {
        require(msg.sender == arbiter, "not arbiter");
        _;
    }

    function totalRequired() public view returns (uint256 sum) {
        for (uint256 i = 0; i < amounts.length; i++) {
            sum += amounts[i];
        }
    }

    function fund() external onlyBuyer {
        require(!funded, "funded");
        require(!canceled, "canceled");

        uint256 total = totalRequired();
        require(total > 0, "total=0");

        funded = true;

        bool ok = token.transferFrom(msg.sender, address(this), total);
        require(ok, "transferFrom failed");

        emit Funded(msg.sender, total);
    }

    function releaseCurrent() external {
        require(funded, "not funded");
        require(!canceled, "canceled");
        require(currentMilestone < milestoneCount, "done");
        require(msg.sender == buyer || msg.sender == arbiter, "no auth");
        require(!released[currentMilestone], "already");

        uint256 amount = amounts[currentMilestone];
        released[currentMilestone] = true;
        currentMilestone += 1;

        bool ok = token.transfer(seller, amount);
        require(ok, "transfer failed");

        emit Released(currentMilestone - 1, amount);
    }

    function cancelAndRefund() external {
        require(funded, "not funded");
        require(!canceled, "canceled");
        require(msg.sender == seller || msg.sender == arbiter, "no auth");

        canceled = true;

        uint256 remaining = 0;
        for (uint256 i = currentMilestone; i < milestoneCount; i++) {
            if (!released[i]) remaining += amounts[i];
        }

        bool ok = token.transfer(buyer, remaining);
        require(ok, "transfer failed");

        emit Canceled(currentMilestone);
        emit Refunded(buyer, remaining);
    }

    function getMilestoneAmount(uint256 id) external view returns (uint256) {
        require(id < milestoneCount, "bad id");
        return amounts[id];
    }
}
