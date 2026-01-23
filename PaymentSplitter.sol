// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

contract PaymentSplitter {
    address[] public payees;
    uint256[] public shares;

    mapping(address => uint256) public released;
    uint256 public totalShares;
    uint256 public totalReleased;

    event PaymentReceived(address from, uint256 amount);
    event PaymentReleased(address to, uint256 amount);

    constructor(address[] memory _payees, uint256[] memory _shares) {
        require(_payees.length == _shares.length, "length mismatch");
        require(_payees.length > 0, "no payees");

        for (uint256 i = 0; i < _payees.length; i++) {
            require(_payees[i] != address(0), "zero address");
            require(_shares[i] > 0, "zero shares");

            payees.push(_payees[i]);
            shares.push(_shares[i]);
            totalShares += _shares[i];
        }
    }

    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }

    function pendingPayment(address account) public view returns (uint256) {
        uint256 totalReceived = address(this).balance + totalReleased;
        uint256 accountShares;
        for (uint256 i = 0; i < payees.length; i++) {
            if (payees[i] == account) {
                accountShares = shares[i];
                break;
            }
        }
        if (accountShares == 0) {
            return 0;
        }

        uint256 alreadyReleased = released[account];
        uint256 payment = (totalReceived * accountShares) / totalShares - alreadyReleased;
        return payment;
    }

    function release(address payable account) external {
        uint256 payment = pendingPayment(account);
        require(payment > 0, "no payment");

        released[account] += payment;
        totalReleased += payment;

        (bool ok, ) = account.call{value: payment}("");
        require(ok, "transfer failed");

        emit PaymentReleased(account, payment);
    }
}
