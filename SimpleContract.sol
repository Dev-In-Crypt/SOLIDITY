// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

contract WalletLedger {

mapping(address => uint) public balances;

event Deposited(address indexed user, uint amount);
event Withdrawn(address indexed user, uint amount);

  function deposit() external payable {
    require(msg.value > 0);
    balances[msg.sender] += msg.value;
    emit Deposited(msg.sender, msg.value);
  }

  function withdraw(uint amount) external {
    require(amount > 0);
    require(balances[msg.sender] >= amount);
    balances[msg.sender] -= amount;
    (bool ok, ) = msg.sender.call{value: amount}("");
    require(ok);
    emit Withdrawn(msg.sender, amount);
  }

}
