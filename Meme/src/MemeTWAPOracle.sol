// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "./libraries/UniswapV2OracleLibrary.sol";
import "./libraries/FixedPoint.sol";

contract MemeTWAPOracle {
    using FixedPoint for *;


    /// @notice Uniswap V2 交易对（Meme/WETH）
    IUniswapV2Pair public immutable pair;

    /// @notice 两个代币的地址
    address public immutable token0;
    address public immutable token1;

    /// @notice LaunchPad 发行的 Meme Token
    address public immutable memeToken;

    /// @notice WETH 地址（或对应链的原生 Token 包装合约）
    address public immutable weth;

    /// @notice 累积价格记录
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;

    /// @notice 上次更新时间戳
    uint32 public blockTimestampLast;

    /// @notice 平均价格（uq112x112 固定点结构）
    FixedPoint.uq112x112 public price0Average;
    FixedPoint.uq112x112 public price1Average;


    constructor(address _pair, address _memeToken, address _weth) {
        require(_pair != address(0), "Invalid pair");
        require(_memeToken != address(0), "Invalid meme token");
        require(_weth != address(0), "Invalid weth");

        pair = IUniswapV2Pair(_pair);
        memeToken = _memeToken;
        weth = _weth;

        token0 = pair.token0();
        token1 = pair.token1();

        // 初始化记录
        price0CumulativeLast = pair.price0CumulativeLast();
        price1CumulativeLast = pair.price1CumulativeLast();

        (, , blockTimestampLast) = pair.getReserves();
    }


    /**
     * @notice 更新最新的时间加权平均价格 (TWAP)
     * @dev 每次交易对储备更新后可调用，或定期由 Keeper 调用
     */
    function update() external {
        (
            uint256 price0Cumulative,
            uint256 price1Cumulative,
            uint32 blockTimestamp
        ) = UniswapV2OracleLibrary.currentCumulativePrices(address(pair));

        uint32 timeElapsed = blockTimestamp - blockTimestampLast;
        require(timeElapsed > 0, "No time elapsed");

        // 计算平均价格
        price0Average = FixedPoint.uq112x112(
            uint224((price0Cumulative - price0CumulativeLast) / timeElapsed)
        );
        price1Average = FixedPoint.uq112x112(
            uint224((price1Cumulative - price1CumulativeLast) / timeElapsed)
        );

        // 更新记录
        price0CumulativeLast = price0Cumulative;
        price1CumulativeLast = price1Cumulative;
        blockTimestampLast = blockTimestamp;
    }


    /**
     * @notice 查询代币的平均价格
     * @param token 要查询的代币（token0 或 token1）
     * @param amountIn 输入数量
     * @return amountOut 平均输出数量
     */
    function consult(address token, uint256 amountIn) public view returns (uint256 amountOut) {
        if (token == token0) {
            amountOut = price0Average.mul(amountIn).decode144();
        } else if (token == token1) {
            amountOut = price1Average.mul(amountIn).decode144();
        } else {
            revert("Invalid token");
        }
    }

    // ====================== 3️⃣ 获取 Meme 对 ETH 的价格 ======================

    /**
     * @notice 获取 MEME → ETH 的平均价格
     * @param memeAmount 输入的 MEME 数量
     * @return 等价的 ETH 数量（TWAP）
     */
    function getMemeToEthPrice(uint256 memeAmount) external view returns (uint256) {
        if (memeToken == token0) {
            return price0Average.mul(memeAmount).decode144();
        } else {
            return price1Average.mul(memeAmount).decode144();
        }
    }


    /**
     * @notice 获取 ETH → MEME 的平均价格
     * @param ethAmount 输入的 ETH 数量
     * @return 等价的 MEME 数量（TWAP）
     */
    function getEthToMemePrice(uint256 ethAmount) external view returns (uint256) {
        if (weth == token0) {
            return price0Average.mul(ethAmount).decode144();
        } else {
            return price1Average.mul(ethAmount).decode144();
        }
    }


    /**
     * @notice 手动设置平均价格
     * @param _price0Average token0 对 token1 的平均价格
     * @param _price1Average token1 对 token0 的平均价格
     */
    function setPrice(uint224 _price0Average, uint224 _price1Average) external {
        price0Average = FixedPoint.uq112x112(_price0Average);
        price1Average = FixedPoint.uq112x112(_price1Average);
    }
}
