// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.24;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function totalSupply() external view returns (uint256);
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}

contract LPToken {
    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;
    string public name;
    string public symbol;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function burn(address from, uint256 amount) external {
        balanceOf[from] -= amount;
        totalSupply -= amount;
    }
}

contract MultiPairDEX {
    struct Pool {
        IERC20 tokenA;
        IERC20 tokenB;
        uint256 reserveA;
        uint256 reserveB;
        LPToken lpToken;
    }

    mapping(bytes32 => Pool) public pools;
    mapping(address => mapping(bytes32 => uint256)) public liquidityProvided; // user => pairKey => amount

    modifier onlyValidPair(address tokenA, address tokenB) {
        require(tokenA != tokenB, "invalid pair");
        _;
    }

    function getPairKey(address tokenA, address tokenB) public pure returns (bytes32) {
        return tokenA < tokenB ? keccak256(abi.encodePacked(tokenA, tokenB)) : keccak256(abi.encodePacked(tokenB, tokenA));
    }

    function createPair(address tokenA, address tokenB, string memory lpName, string memory lpSymbol) 
        external onlyValidPair(tokenA, tokenB) {
        bytes32 pairKey = getPairKey(tokenA, tokenB);
        require(address(pools[pairKey].tokenA) == address(0), "pair exists");
        LPToken lp = new LPToken(lpName, lpSymbol);
        pools[pairKey] = Pool(IERC20(tokenA), IERC20(tokenB), 0, 0, lp);
    }

    function addLiquidity(address tokenA, address tokenB, uint256 amountADesired, uint256 amountBDesired) 
        external onlyValidPair(tokenA, tokenB) {
        bytes32 pairKey = getPairKey(tokenA, tokenB);
        Pool storage pool = pools[pairKey];
        require(address(pool.tokenA) != address(0), "pair not created");

        uint256 reserveA = IERC20(tokenA).balanceOf(address(this));
        uint256 reserveB = IERC20(tokenB).balanceOf(address(this));

        uint256 amountA;
        uint256 amountB;
        if (reserveA > 0 && reserveB > 0) {
            uint256 amountBOptimal = quote(amountADesired, reserveA, reserveB);
            require(amountBOptimal <= amountBDesired, "insufficient B");
            amountA = amountADesired;
            amountB = amountBOptimal;
        } else {
            amountA = amountADesired;
            amountB = amountBDesired;
        }

        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

        uint256 liquidity = (pool.lpToken.totalSupply() == 0) 
            ? sqrt(amountA * amountB) 
            : min(amountA * pool.reserveB / reserveB, amountB * pool.reserveA / reserveA);

        pool.lpToken.mint(msg.sender, liquidity);
        liquidityProvided[msg.sender][pairKey] += liquidity;

        pool.reserveA += amountA;
        pool.reserveB += amountB;
    }

    function removeLiquidity(address tokenA, address tokenB, uint256 liquidity) 
        external onlyValidPair(tokenA, tokenB) {
        bytes32 pairKey = getPairKey(tokenA, tokenB);
        Pool storage pool = pools[pairKey];
        uint256 balanceA = IERC20(tokenA).balanceOf(address(this));
        uint256 balanceB = IERC20(tokenB).balanceOf(address(this));

        uint256 amountA = (liquidity * balanceA) / pool.lpToken.totalSupply();
        uint256 amountB = (liquidity * balanceB) / pool.lpToken.totalSupply();

        pool.lpToken.burn(msg.sender, liquidity);
        liquidityProvided[msg.sender][pairKey] -= liquidity;

        IERC20(tokenA).transfer(msg.sender, amountA);
        IERC20(tokenB).transfer(msg.sender, amountB);

        pool.reserveA = balanceA - amountA;
        pool.reserveB = balanceB - amountB;
    }

    function swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOutMin) external {
        require(tokenIn != tokenOut, "invalid pair");
        bytes32 pairKey = getPairKey(tokenIn, tokenOut);
        Pool storage pool = pools[pairKey];
        require(address(pool.tokenA) != address(0), "pair not created");

        uint256 reserveIn = (tokenIn == address(pool.tokenA)) ? pool.reserveA : pool.reserveB;
        uint256 reserveOut = (tokenOut == address(pool.tokenA)) ? pool.reserveA : pool.reserveB;
        require(reserveIn > 0 && reserveOut > 0, "insufficient liquidity");

        uint256 amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        require(amountOut >= amountOutMin, "slippage");

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).transfer(msg.sender, amountOut);

        // Update reserves (simplified)
        if (tokenIn == address(pool.tokenA)) {
            pool.reserveA += amountIn;
            pool.reserveB -= amountOut;
        } else {
            pool.reserveA -= amountOut;
            pool.reserveB += amountIn;
        }
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256) {
        uint256 amountInWithFee = amountIn * 997 / 1000;
        return amountInWithFee * reserveOut / (reserveIn + amountInWithFee);
    }

    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) public pure returns (uint256 amountB) {
        return amountA * reserveB / reserveA;
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
    }

    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
