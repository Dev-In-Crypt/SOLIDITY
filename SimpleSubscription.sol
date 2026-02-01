// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

contract SimpleSubscription {
    address public owner;
    uint256 public pricePerPeriod;
    uint256 public periodSeconds;

    mapping(address => uint256) public paidUntil;

    error NotOwner();
    error ZeroAmount();
    error ZeroAddress();
    error NotActive();
    error TransferFailed();

    event Subscribed(address indexed user, uint256 periods, uint256 paidUntil);
    event PriceChanged(uint256 newPrice);
    event PeriodChanged(uint256 newPeriodSeconds);
    event Withdrawn(address indexed to, uint256 amount);

    constructor(uint256 _pricePerPeriod, uint256 _periodSeconds) {
        owner = msg.sender;
        if (_pricePerPeriod == 0) revert ZeroAmount();
        if (_periodSeconds == 0) revert ZeroAmount();
        pricePerPeriod = _pricePerPeriod;
        periodSeconds = _periodSeconds;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    function subscribe(uint256 periods) external payable {
        if (periods == 0) revert ZeroAmount();

        uint256 cost = pricePerPeriod * periods;
        if (msg.value != cost) revert ZeroAmount();

        uint256 startFrom = paidUntil[msg.sender];
        if (startFrom < block.timestamp) startFrom = block.timestamp;

        uint256 newPaidUntil = startFrom + (periodSeconds * periods);
        paidUntil[msg.sender] = newPaidUntil;

        emit Subscribed(msg.sender, periods, newPaidUntil);
    }

    function isActive(address user) external view returns (bool) {
        return paidUntil[user] >= block.timestamp;
    }

    function setPrice(uint256 newPrice) external onlyOwner {
        if (newPrice == 0) revert ZeroAmount();
        pricePerPeriod = newPrice;
        emit PriceChanged(newPrice);
    }

    function setPeriodSeconds(uint256 newPeriodSeconds) external onlyOwner {
        if (newPeriodSeconds == 0) revert ZeroAmount();
        periodSeconds = newPeriodSeconds;
        emit PeriodChanged(newPeriodSeconds);
    }

    function withdraw(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        (bool ok, ) = to.call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit Withdrawn(to, amount);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        owner = newOwner;
    }
}
