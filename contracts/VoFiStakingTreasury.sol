// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract VoFiStakingTreasury is Ownable {
    address public vofi;
    address public stakingMaster;

    event TokenDistributed(address indexed _team, uint256 indexed _amount);

    constructor() {
    }

    receive() external payable {}

    function setToken(address _vofi) external onlyOwner {
        vofi = _vofi;
    }

    function setStakingMaster(address _staking) external onlyOwner {
        stakingMaster = _staking;
        IERC20(vofi).approve(_staking, ~uint256(0));
    }

    function tokenFunctionCall(bytes memory _calldata) external onlyOwner returns (bool) {
        (bool success, ) = vofi.call(_calldata);
        return success;
    }
}
