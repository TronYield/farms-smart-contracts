// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface ITronYieldStrategy {
    function distributeFee() external;
    function feeStrategy() external view returns (uint256, uint256);
}