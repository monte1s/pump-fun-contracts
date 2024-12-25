// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

library BondingCurve {
    struct Liquidity {
        uint256 reserveEth;
        uint256 reserveToken; // inflated current reserve
        uint256 virtualEth;
        uint256 initialRealToken; // real reserve at the creation of the pool
        uint256 initialInflatedToken; // inflated reserve at the creation of the pool
        uint256 maxEth;
        uint256 k;
    }

    function _getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 k
    ) internal pure returns (uint256) {
        uint256 newReserveOut = k / (reserveIn + amountIn);
        return reserveOut - newReserveOut;
    }

    function _getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 k
    ) internal pure returns (uint256) {
        uint256 newReserveIn = k / (reserveOut - amountOut);
        return reserveIn - newReserveIn;
    }

    function getTokenOut(
        uint ethIn,
        Liquidity memory liq
    ) internal pure returns (uint256 tokenOut) {
        if (liq.reserveEth + ethIn > liq.maxEth) {
            // calculate amount out with inflated reserve up to maxEth
            uint256 ethInInflated = liq.maxEth - liq.reserveEth;
            uint256 curveOut = _getAmountOut(
                ethInInflated,
                liq.reserveEth,
                liq.reserveToken,
                liq.k
            );
            // calculate remaining amount out with final reserves
            uint256 realEthLeft = liq.maxEth - liq.virtualEth;
            uint256 realTokenLeft = _getRealTokenLeft(
                liq.initialRealToken,
                liq.initialInflatedToken,
                liq.reserveToken - curveOut
            );
            uint256 remainingOut = _getAmountOut(
                ethIn - ethInInflated,
                realEthLeft,
                realTokenLeft,
                realEthLeft * realTokenLeft
            );
            tokenOut = curveOut + remainingOut;
        } else {
            tokenOut = _getAmountOut(
                ethIn,
                liq.reserveEth,
                liq.reserveToken,
                liq.k
            );
        }
    }

    function getTokenIn(
        uint ethOut,
        Liquidity memory liq
    ) internal pure returns (uint256 tokenIn) {
        tokenIn = _getAmountIn(ethOut, liq.reserveToken, liq.reserveEth, liq.k);
    }

    function getEthOut(
        uint tokenIn,
        Liquidity memory liq
    ) internal pure returns (uint256 ethOut) {
        ethOut = _getAmountOut(
            tokenIn,
            liq.reserveToken,
            liq.reserveEth,
            liq.k
        );
    }

    function getEthIn(
        uint tokenOut,
        Liquidity memory liq
    ) internal pure returns (uint256 ethIn) {
        ethIn = _getAmountIn(tokenOut, liq.reserveEth, liq.reserveToken, liq.k);
        if (ethIn + liq.reserveEth > liq.maxEth) {
            // calculate amount in with inflated reserve up to maxEth
            uint256 ethInInflated = liq.maxEth - liq.reserveEth;
            // get the tokenOut that can be bought with the inflated ethIn
            uint256 curveOut = _getAmountOut(
                ethInInflated,
                liq.reserveEth,
                liq.reserveToken,
                liq.k
            );
            // calculate remaining amount in with final reserves
            uint256 realEthLeft = liq.maxEth - liq.virtualEth;
            uint256 realTokenLeft = _getRealTokenLeft(
                liq.initialRealToken,
                liq.initialInflatedToken,
                liq.reserveToken - curveOut
            );
            uint256 remainingIn = _getAmountIn(
                tokenOut - curveOut,
                realEthLeft,
                realTokenLeft,
                realEthLeft * realTokenLeft
            );
            ethIn = ethInInflated + remainingIn;
        }
    }

    function _getInflatedTokenSupply(
        uint256 tokenSupply,
        uint256 virtualEth,
        uint256 maxEth
    ) internal pure returns (uint256) {
        uint256 a = (maxEth * tokenSupply) / (2 * (maxEth + virtualEth));
        uint256 b = (maxEth * tokenSupply) / (2 * (maxEth - virtualEth));
        return a + b;
    }

    function _getRealTokenLeft(
        uint256 _initialRealToken,
        uint256 _initialInflatedToken,
        uint256 _reserveToken
    ) internal pure returns (uint256) {
        return _initialRealToken - (_initialInflatedToken - _reserveToken);
    }
}
