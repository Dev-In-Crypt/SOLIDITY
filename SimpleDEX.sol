pragma solidity ^0.8.24;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract SimpleDEX {
    mapping(address => mapping(address => uint256)) public reserves;
    address public owner;
    IERC20 public token;

    constructor(address _token) {
        owner = msg.sender;
        token = IERC20(_token);
    }

    function addLiquidity(uint256 tokenAmount) external payable {
        reserves[address(token)][address(0)](msg.sender) += tokenAmount;
        reserves[address(0)][address(token)](msg.sender) += msg.value;
    }

    function swap(address tokenIn, uint256 amountIn) external payable {
        uint256 reserveIn = IERC20(tokenIn).balanceOf(address(this));
        uint256 reserveOut = address(tokenIn) == address(token) ? address(this).balance : token.balanceOf(address(this));
        uint256 amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        if (tokenIn == address(token)) {
            token.transferFrom(msg.sender, address(this), amountIn);
            payable(msg.sender).transfer(amountOut);
        } else {
            token.transfer(msg.sender, amountOut);
        }
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256 amountOut) {
        uint256 amountInWithFee = amountIn * 997;
        amountOut = (amountInWithFee * reserveOut) / (reserveIn * 1000 + amountInWithFee);
    }
}
