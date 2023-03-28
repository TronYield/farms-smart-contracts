// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract FeeStrategy is Ownable {
  using SafeMath for uint256;

  uint256 public constant FARM_DYMOND_BALANCE_TIER1 = 5000 * 10 ** 18;
  uint256 public constant FARM_DYMOND_BALANCE_TIER2 = 15000 * 10 ** 18;
  uint256 public constant FARM_DYMOND_BALANCE_TIER3 = 35000 * 10 ** 18;
  uint256 public constant FARM_DYMOND_DEPOSIT_DEDUCT_BP_TIER1 = 7500;  // 75% of standard deposit rate
  uint256 public constant FARM_DYMOND_DEPOSIT_DEDUCT_BP_TIER2 = 5000;  // 50% of standard deposit rate
  uint256 public constant FARM_DYMOND_DEPOSIT_DEDUCT_BP_TIER3 = 1250;  // 12.5% of standard deposit rate

  uint256 public constant VAULT_DYMOND_BALANCE_TIER1 = 6000 * 10 ** 18;
  uint256 public constant VAULT_DYMOND_BALANCE_TIER2 = 12500 * 10 ** 18;
  uint256 public constant VAULT_DYMOND_BALANCE_TIER3 = 36000 * 10 ** 18;
  uint256 public constant VAULT_DYMOND_DEPOSIT_DEDUCT_BP_TIER1 = 8500;  // 75% of standard deposit rate
  uint256 public constant VAULT_DYMOND_DEPOSIT_DEDUCT_BP_TIER2 = 6500;  // 50% of standard deposit rate
  uint256 public constant VAULT_DYMOND_DEPOSIT_DEDUCT_BP_TIER3 = 5000;  // 12.5% of standard deposit rate

  IERC20 public holderToken;

  constructor(address _holderToken) {
    holderToken = IERC20(_holderToken);
  }

  function getExactFarmDepositFeeBPForDynomicHolder(uint16 _defaultFeeBP, address _holder) external view returns (uint depositFeeRate) {
    uint holderBalance = holderToken.balanceOf(_holder);
    if (holderBalance < FARM_DYMOND_BALANCE_TIER1) {
      depositFeeRate = _defaultFeeBP;
    } else if (holderBalance >= FARM_DYMOND_BALANCE_TIER1 && holderBalance < FARM_DYMOND_BALANCE_TIER2) {
      // tier 1 deposit rate
      depositFeeRate = uint256(_defaultFeeBP).mul(FARM_DYMOND_DEPOSIT_DEDUCT_BP_TIER1).div(10000);
    } else if (holderBalance >= FARM_DYMOND_BALANCE_TIER2 && holderBalance < FARM_DYMOND_BALANCE_TIER3) {
      // tier 2 deposit rate
      depositFeeRate = uint256(_defaultFeeBP).mul(FARM_DYMOND_DEPOSIT_DEDUCT_BP_TIER2).div(10000);
    } else if (holderBalance >= FARM_DYMOND_BALANCE_TIER3) {
      // tier 3 deposit rate
      depositFeeRate = uint256(_defaultFeeBP).mul(FARM_DYMOND_DEPOSIT_DEDUCT_BP_TIER3).div(10000);
    }
  }

  function getExactVaultDepositFeeBPForDynomicHolder(uint16 _defaultFeeBP, address _holder) external view returns (uint depositFeeRate) {
    uint holderBalance = holderToken.balanceOf(_holder);
    if (holderBalance < VAULT_DYMOND_BALANCE_TIER1) {
      depositFeeRate = _defaultFeeBP;
    } else if (holderBalance >= VAULT_DYMOND_BALANCE_TIER1 && holderBalance < VAULT_DYMOND_BALANCE_TIER2) {
      // tier 1 deposit rate
      depositFeeRate = uint256(_defaultFeeBP).mul(VAULT_DYMOND_DEPOSIT_DEDUCT_BP_TIER1).div(10000);
    } else if (holderBalance >= VAULT_DYMOND_BALANCE_TIER2 && holderBalance < VAULT_DYMOND_BALANCE_TIER3) {
      // tier 2 deposit rate
      depositFeeRate = uint256(_defaultFeeBP).mul(VAULT_DYMOND_DEPOSIT_DEDUCT_BP_TIER2).div(10000);
    } else if (holderBalance >= VAULT_DYMOND_BALANCE_TIER3) {
      // tier 3 deposit rate
      depositFeeRate = uint256(_defaultFeeBP).mul(VAULT_DYMOND_DEPOSIT_DEDUCT_BP_TIER3).div(10000);
    }
  }

  function setHolderToken(address _holderToken) external onlyOwner {
    holderToken = IERC20(_holderToken);
  }
}
