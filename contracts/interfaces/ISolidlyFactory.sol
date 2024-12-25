// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ISolidlyFactory {
    function createPair(
        address tokenA,
        address tokenB,
        bool stable
    ) external returns (address pair);
    function getPair(
        address tokenA,
        address tokenB,
        bool stable
    ) external view returns (address pair);
}
