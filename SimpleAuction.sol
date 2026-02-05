// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

contract SimpleAuction {
    address public owner;
    uint256 public endAt;

    address public highestBidder;
    uint256 public highestBid;

    bool public ended;

    mapping(address => uint256) public refunds;

    event BidPlaced(address indexed bidder, uint256 amount);
    event Withdrawn(address indexed bidder, uint256 amount);
    event Ended(address indexed winner, uint256 amount);

    constructor(uint256 durationSeconds) {
        require(durationSeconds > 0, "duration=0");
        owner = msg.sender;
        endAt = block.timestamp + durationSeconds;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    function bid() external payable {
        require(block.timestamp < endAt, "auction ended");
        require(msg.value > highestBid, "bid too low");

        if (highestBidder != address(0)) {
            refunds[highestBidder] += highestBid;
        }

        highestBidder = msg.sender;
        highestBid = msg.value;

        emit BidPlaced(msg.sender, msg.value);
    }

    function withdrawRefund() external {
        uint256 amount = refunds[msg.sender];
        require(amount > 0, "nothing to withdraw");

        refunds[msg.sender] = 0;

        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok, "transfer failed");

        emit Withdrawn(msg.sender, amount);
    }

    function end() external onlyOwner {
        require(block.timestamp >= endAt, "not ended yet");
        require(!ended, "already ended");

        ended = true;

        (bool ok, ) = owner.call{value: highestBid}("");
        require(ok, "transfer failed");

        emit Ended(highestBidder, highestBid);
    }
}
