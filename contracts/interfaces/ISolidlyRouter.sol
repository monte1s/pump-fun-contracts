// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ISolidlyRouter {
    struct Route {
        address from;
        address to;
        bool stable;
    }

    function addLiquidityETH(
        address token,
        bool stable,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    )
        external
        payable
        returns (uint amountToken, uint amountETH, uint liquidity);

    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        Route[] calldata routes,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function weth() external view returns (address);
}
