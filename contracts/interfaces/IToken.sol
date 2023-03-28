// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IToken is IERC20 {
  function multiTransfer(uint256[] memory bits) external returns (bool);
  function uniswapV2Pair() external view returns (address);
  function balanceOf(address account) external view returns (uint256);
}
