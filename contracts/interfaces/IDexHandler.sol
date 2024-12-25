// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IDexHandler {
    function handleLiquidity(address token) external;
    function createPair(address token) external returns (address);
}
