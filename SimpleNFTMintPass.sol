// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

contract SimpleNFTMintPass {
    address public owner;

    string public name;
    string public symbol;

    uint256 public maxSupply;
    uint256 public totalSupply;
    uint256 public mintPrice;
    uint256 public mintDeadline;

    mapping(uint256 => address) public ownerOf;
    mapping(address => uint256) public balanceOf;
    mapping(address => bool) public hasMinted;

    error NotOwner();
    error ZeroAddress();
    error ZeroAmount();
    error SoldOut();
    error MintEnded();
    error AlreadyMinted();
    error NotTokenOwner();
    error TransferFailed();

    event Minted(address indexed to, uint256 indexed tokenId);
    event Transferred(address indexed from, address indexed to, uint256 indexed tokenId);
    event ConfigChanged(uint256 mintPrice, uint256 mintDeadline);
    event Withdrawn(address indexed to, uint256 amount);

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        uint256 _mintPrice,
        uint256 _durationSeconds
    ) {
        if (_maxSupply == 0) revert ZeroAmount();

        owner = msg.sender;
        name = _name;
        symbol = _symbol;
        maxSupply = _maxSupply;
        mintPrice = _mintPrice;
        mintDeadline = block.timestamp + _durationSeconds;

        emit ConfigChanged(mintPrice, mintDeadline);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    function mint() external payable returns (uint256 tokenId) {
        if (block.timestamp > mintDeadline) revert MintEnded();
        if (totalSupply >= maxSupply) revert SoldOut();
        if (hasMinted[msg.sender]) revert AlreadyMinted();
        if (msg.value != mintPrice) revert ZeroAmount();

        tokenId = totalSupply + 1;

        hasMinted[msg.sender] = true;
        ownerOf[tokenId] = msg.sender;
        balanceOf[msg.sender] += 1;
        totalSupply += 1;

        emit Minted(msg.sender, tokenId);
    }

    function transfer(address to, uint256 tokenId) external {
        if (to == address(0)) revert ZeroAddress();

        address from = ownerOf[tokenId];
        if (from != msg.sender) revert NotTokenOwner();

        ownerOf[tokenId] = to;
        balanceOf[from] -= 1;
        balanceOf[to] += 1;

        emit Transferred(from, to, tokenId);
    }

    function setMintConfig(uint256 newPrice, uint256 newDeadline) external onlyOwner {
        mintPrice = newPrice;
        mintDeadline = newDeadline;
        emit ConfigChanged(newPrice, newDeadline);
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
