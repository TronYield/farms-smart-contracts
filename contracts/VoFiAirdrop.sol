// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import './interfaces/IToken.sol';

contract VoFiAirdrop is Ownable {
    address public vofi;

    event Airdropped(address indexed _user, uint256 indexed _amount);

    constructor() {
    }

    receive() external payable {}

    function setToken(address _vofi) external onlyOwner {
        vofi = _vofi;
    }

    function airdrop(address[] memory _users, uint8[] memory _allocs) external onlyOwner {
        uint256 balance = IERC20(vofi).balanceOf(address(this));
        if (balance > 0) {
            for (uint i = 0; i < _users.length; i++) {
                uint256 alloc = _allocs[i];
                uint256 allocBal = balance * alloc / 100;
                IERC20(vofi).transfer(_users[i], allocBal);
                emit Airdropped(_users[i], allocBal);
            }
        }
    }

    function tokenFunctionCall(bytes memory _calldata) external onlyOwner returns (bool) {
        (bool success, ) = vofi.call(_calldata);
        return success;
    }
}
