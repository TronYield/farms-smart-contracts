// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract VoFiTokenVest is Ownable {
    address public vofi;
    uint256 public startedVestTimestamp;
    uint256 public vestPeriod = 180 days;

    event TokenDistributed(address indexed _team, uint256 indexed _amount);

    constructor() {
    }

    receive() external payable {}

    function setToken(address _vofi) external onlyOwner {
        vofi = _vofi;
    }

    function vestCurrentTokens() external onlyOwner {
        startedVestTimestamp = block.timestamp;
    }

    function distributeTokens(address[] memory _teams, uint256[] memory _allocs) external onlyOwner returns (bool) {
        require(startedVestTimestamp + vestPeriod < block.timestamp, "VoFi Vest: Vest not end yet");
        uint256 balance = IERC20(vofi).balanceOf(address(this));
        if (balance > 0) {
            for (uint i = 0; i < _teams.length; i++) {
                uint256 alloc = _allocs[i];
                uint256 allocBal = balance * alloc / 100;
                IERC20(vofi).transfer(_teams[i], allocBal);
                emit TokenDistributed(_teams[i], allocBal);
            }
        }
        return true;
    }

    function tokenFunctionCall(bytes memory _calldata) external onlyOwner returns (bool) {
        (bool success, ) = vofi.call(_calldata);
        return success;
    }
}
