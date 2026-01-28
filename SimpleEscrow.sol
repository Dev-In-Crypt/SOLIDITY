// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

contract SimpleEscrow {
    address public buyer;
    address public seller;
    address public arbiter;

    uint256 public amount;
    bool public funded;
    bool public released;
    bool public refunded;

    error ZeroAddress();
    error AmountZero();
    error NotBuyer();
    error NotSeller();
    error NotArbiter();
    error NotParticipant();
    error AlreadyFunded();
    error NotFunded();
    error AlreadyFinalized();

    event Funded(address indexed buyer, uint256 amount);
    event Released(address indexed seller, uint256 amount);
    event Refunded(address indexed buyer, uint256 amount);

    constructor(address _buyer, address _seller, address _arbiter) {
        if (_buyer == address(0) || _seller == address(0) || _arbiter == address(0)) revert ZeroAddress();
        buyer = _buyer;
        seller = _seller;
        arbiter = _arbiter;
    }

    function fund() external payable {
        if (msg.sender != buyer) revert NotBuyer();
        if (funded) revert AlreadyFunded();
        if (msg.value == 0) revert AmountZero();

        funded = true;
        amount = msg.value;

        emit Funded(buyer, msg.value);
    }

    function releaseToSeller() external {
        if (!funded) revert NotFunded();
        if (released || refunded) revert AlreadyFinalized();
        if (msg.sender != buyer && msg.sender != arbiter) revert NotParticipant();

        released = true;

        (bool ok, ) = seller.call{value: amount}("");
        require(ok);

        emit Released(seller, amount);
    }

    function refundToBuyer() external {
        if (!funded) revert NotFunded();
        if (released || refunded) revert AlreadyFinalized();
        if (msg.sender != seller && msg.sender != arbiter) revert NotParticipant();

        refunded = true;

        (bool ok, ) = buyer.call{value: amount}("");
        require(ok);

        emit Refunded(buyer, amount);
    }
}
