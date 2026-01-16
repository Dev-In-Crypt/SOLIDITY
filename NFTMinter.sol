// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract NFTMinter {
    string public name = "Portfolio NFT";
    string public symbol = "PNFT";
    uint256 public constant MAX_SUPPLY = 100;
    uint256 public totalSupply;

    mapping(uint256 => address) public ownerOf;
    mapping(address => uint256) public balanceOf;
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    modifier onlyOwnerOf(uint256 tokenId) {
        require(ownerOf[tokenId] == msg.sender, "Not owner");
        _;
    }

    function mint(address to) external {
        require(totalSupply < MAX_SUPPLY, "Max supply reached");
        require(to != address(0), "Zero address");
        uint256 tokenId = totalSupply + 1;
        totalSupply += 1;

        ownerOf[tokenId] = to;
        balanceOf[to] += 1;

        emit Transfer(address(0), to, tokenId);
    }

    function approve(address to, uint256 tokenId) external onlyOwnerOf(tokenId) {
        getApproved[tokenId] = to;
        emit Approval(msg.sender, to, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        require(to != address(0), "Zero address");
        address owner = ownerOf[tokenId];
        require(owner == from, "From not owner");
        require(
            msg.sender == owner ||
            msg.sender == getApproved[tokenId] ||
            isApprovedForAll[owner][msg.sender],
            "Not approved"
        );

        balanceOf[from] -= 1;
        balanceOf[to] += 1;
        ownerOf[tokenId] = to;
        getApproved[tokenId] = address(0);

        emit Transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        transferFrom(from, to, tokenId);
    }
}
