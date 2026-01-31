// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

contract SimpleMultiSigWallet {
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public required;

    struct TxData {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 approvals;
    }

    TxData[] public txs;
    mapping(uint256 => mapping(address => bool)) public approvedBy;

    error ZeroAddress();
    error NotOwner();
    error BadRequired();
    error TxDoesNotExist();
    error AlreadyApproved();
    error AlreadyExecuted();
    error ExecuteFailed();

    event Deposit(address indexed from, uint256 amount);
    event Submitted(uint256 indexed txId, address indexed to, uint256 value, bytes data);
    event Approved(uint256 indexed txId, address indexed owner);
    event Executed(uint256 indexed txId);

    constructor(address[] memory _owners, uint256 _required) {
        if (_owners.length == 0) revert BadRequired();

        for (uint256 i = 0; i < _owners.length; i++) {
            address o = _owners[i];
            if (o == address(0)) revert ZeroAddress();
            if (isOwner[o]) revert BadRequired();
            isOwner[o] = true;
            owners.push(o);
        }

        if (_required == 0 || _required > owners.length) revert BadRequired();
        required = _required;
    }

    modifier onlyOwner() {
        if (!isOwner[msg.sender]) revert NotOwner();
        _;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function ownersCount() external view returns (uint256) {
        return owners.length;
    }

    function txCount() external view returns (uint256) {
        return txs.length;
    }

    function submit(address to, uint256 value, bytes calldata data) external onlyOwner returns (uint256 txId) {
        if (to == address(0)) revert ZeroAddress();

        txs.push(TxData({
            to: to,
            value: value,
            data: data,
            executed: false,
            approvals: 0
        }));

        txId = txs.length - 1;
        emit Submitted(txId, to, value, data);
    }

    function approve(uint256 txId) external onlyOwner {
        if (txId >= txs.length) revert TxDoesNotExist();
        TxData storage t = txs[txId];
        if (t.executed) revert AlreadyExecuted();
        if (approvedBy[txId][msg.sender]) revert AlreadyApproved();

        approvedBy[txId][msg.sender] = true;
        t.approvals += 1;

        emit Approved(txId, msg.sender);
    }

    function execute(uint256 txId) external onlyOwner {
        if (txId >= txs.length) revert TxDoesNotExist();
        TxData storage t = txs[txId];
        if (t.executed) revert AlreadyExecuted();
        if (t.approvals < required) revert BadRequired();

        t.executed = true;

        (bool ok, ) = t.to.call{value: t.value}(t.data);
        if (!ok) revert ExecuteFailed();

        emit Executed(txId);
    }
}
