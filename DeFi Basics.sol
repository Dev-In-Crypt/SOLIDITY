// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract PayableDemo {
    address public owner;
    
    constructor() {
        owner = msg.sender;
    }
    
    function deposit() external payable {
        emit Deposit(msg.sender, msg.value);
    }
    
    function withdrawAll() external {
        uint balance = address(this).balance;
        require(balance > 0, "No balance");
        payable(msg.sender).transfer(balance);
    }
    
    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }
    
    event Deposit(address indexed from, uint256 amount);
}
