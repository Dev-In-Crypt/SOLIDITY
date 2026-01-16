// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Lottery {
    address public owner;
    uint256 public ticketPrice;
    address[] public players;
    bool public isOpen;

    event TicketPurchased(address indexed player);
    event WinnerSelected(address indexed winner, uint256 prize);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(uint256 _ticketPrice) {
        owner = msg.sender;
        ticketPrice = _ticketPrice;
        isOpen = true;
    }

    function buyTicket() external payable {
        require(isOpen, "Lottery closed");
        require(msg.value == ticketPrice, "Invalid price");
        players.push(msg.sender);
        emit TicketPurchased(msg.sender);
    }

    function getPlayers() external view returns (address[] memory) {
        return players;
    }

    function closeLottery() external onlyOwner {
        isOpen = false;
    }

    function pickWinner() external onlyOwner {
        require(!isOpen, "Lottery still open");
        require(players.length > 0, "No players");

        uint256 random = uint256(
            keccak256(
                abi.encodePacked(block.timestamp, block.prevrandao, players.length)
            )
        );
        uint256 winnerIndex = random % players.length;
        address winner = players[winnerIndex];

        uint256 prize = address(this).balance;
        payable(winner).transfer(prize);

        emit WinnerSelected(winner, prize);

        delete players;
        isOpen = true;
    }
}
