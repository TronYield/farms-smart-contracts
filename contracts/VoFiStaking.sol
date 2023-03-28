// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import './interfaces/IFeeStrategy.sol';

// VoFiStaking is the master of VoFi. He can make VoFi and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once VoFi is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract VoFiStaking is Ownable, ReentrancyGuard {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  // Info of each user.
  struct UserInfo {
    uint256 amount;         // How many LP tokens the user has provided.
    uint256 rewardDebt;     // Reward debt. See explanation below.
    uint256 rewardLockedUp;  // Reward locked up.
    uint256 nextHarvestUntil; // When can the user harvest again.
    //
    // We do some fancy math here. Basically, any point in time, the amount of VoFis
    // entitled to a user but is pending to be distributed is:
    //
    //   pending reward = (user.amount * pool.accVoFiPerShare) - user.rewardDebt
    //
    // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
    //   1. The pool's `accVoFiPerShare` (and `lastRewardTimestamp`) gets updated.
    //   2. User receives the pending reward sent to his/her address.
    //   3. User's `amount` gets updated.
    //   4. User's `rewardDebt` gets updated.
  }

  // Info of each pool.
  struct PoolInfo {
    IERC20 lpToken;           // Address of LP token contract.
    uint256 allocPoint;       // How many allocation points assigned to this pool. vofiToken to distribute per block.
    uint256 lastRewardTimestamp;  // Last timestamp that VoFi distribution occurs.
    uint256 accVoFiPerShare;   // Accumulated VoFi per share, times 1e12. See below.
    uint16 depositFeeBP;      // Deposit fee in basis points
    uint256 harvestInterval;  // Harvest interval in seconds
  }

  // The VoFi TOKEN!
  ERC20 public vofiToken;
  // Buyback address
  address public buybackAddress;
  // Dev address.
  address public devAddress;
  // Deposit Fee address
  address public feeAddress;
  // VoFi tokens created per second.
  uint256 public vofiPerSec;
  // Bonus muliplier for early vofiToken makers.
  uint256 public constant BONUS_MULTIPLIER = 1;
  // Max harvest interval: 14 days.
  uint256 public constant MAXIMUM_HARVEST_INTERVAL = 14 days;
  // fee distribution rates
  uint16 public constant BUYBACK_RATE = 8000; // 80% of deposit fee
  uint16 public constant DEV_FEE_RATE = 1000; // 10% of deposit fee
  uint16 public constant HOLDING_FEE_RATE = 1000; // 10% of deposit fee

  // Info of each pool.
  PoolInfo[] public poolInfo;
  // Info of each user that stakes LP tokens.
  mapping(uint256 => mapping(address => UserInfo)) public userInfo;
  // Total allocation points. Must be the sum of all allocation points in all pools.
  uint256 public totalAllocPoint = 0;
  // The block number when VoFi mining starts.
  uint256 public startTimestamp;
  // Total locked up rewards
  uint256 public totalLockedUpRewards;

  // VoFi fee duduction strategy address.
  IFeeStrategy public feeStrategy;

  // Referral commission rate in basis points.
  uint16 public referralCommissionRate = 100;
  // Max referral commission rate: 10%.
  uint16 public constant MAXIMUM_REFERRAL_COMMISSION_RATE = 1000;

  event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
  event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
  event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
  event EmissionRateUpdated(address indexed caller, uint256 previousAmount, uint256 newAmount);
  event ReferralCommissionPaid(address indexed user, address indexed referrer, uint256 commissionAmount);
  event RewardLockedUp(address indexed user, uint256 indexed pid, uint256 amountLockedUp);

  constructor(
    ERC20 _vofiToken,
    address _feeStrategy
  ) public {
    vofiToken = _vofiToken;
    startTimestamp = block.timestamp;
    vofiPerSec = 5 * 1e15;

    devAddress = msg.sender;
    feeAddress = msg.sender;
    buybackAddress = msg.sender;

    feeStrategy = IFeeStrategy(_feeStrategy);
  }

  function poolLength() external view returns (uint256) {
    return poolInfo.length;
  }

  // Add a new lp to the pool. Can only be called by the owner.
  // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
  function add(uint256 _allocPoint, IERC20 _lpToken, uint16 _depositFeeBP, uint256 _harvestInterval, bool _withUpdate) external onlyOwner {
    require(_depositFeeBP <= 1000, 'add: exceed deposit fee allownance'); // deposit fee should be less than 10%
    require(_harvestInterval <= MAXIMUM_HARVEST_INTERVAL, 'add: invalid harvest interval');
    if (_withUpdate) {
      massUpdatePools();
    }
    uint256 lastRewardTimestamp = block.timestamp > startTimestamp ? block.timestamp : startTimestamp;
    totalAllocPoint = totalAllocPoint.add(_allocPoint);
    poolInfo.push(PoolInfo({
      lpToken: _lpToken,
      allocPoint: _allocPoint,
      lastRewardTimestamp: lastRewardTimestamp,
      accVoFiPerShare: 0,
      depositFeeBP: _depositFeeBP,
      harvestInterval: _harvestInterval
    }));
  }

  // Update the given pool's VoFi allocation point and deposit fee. Can only be called by the owner.
  function set(uint256 _pid, uint256 _allocPoint, uint16 _depositFeeBP, uint256 _harvestInterval, bool _withUpdate) external onlyOwner {
    require(_depositFeeBP <= 1000, 'set: exceed deposit fee allownance'); // deposit fee should be less than 10%
    require(_harvestInterval <= MAXIMUM_HARVEST_INTERVAL, 'set: invalid harvest interval');
    if (_withUpdate) {
      massUpdatePools();
    }
    totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
    poolInfo[_pid].allocPoint = _allocPoint;
    poolInfo[_pid].depositFeeBP = _depositFeeBP;
    poolInfo[_pid].harvestInterval = _harvestInterval;
  }

  // Return reward multiplier over the given _from to _to block.
  function getMultiplier(uint256 _from, uint256 _to) public pure returns (uint256) {
    return _to.sub(_from).mul(BONUS_MULTIPLIER);
  }

  // View function to see pending VoFi on frontend.
  function pendingVoFi(uint256 _pid, address _user) external view returns (uint256) {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][_user];
    uint256 accVoFiPerShare = pool.accVoFiPerShare;
    uint256 lpSupply = pool.lpToken.balanceOf(address(this));
    if (block.timestamp > pool.lastRewardTimestamp && lpSupply != 0) {
      uint256 multiplier = getMultiplier(pool.lastRewardTimestamp, block.timestamp);
      uint256 tokenRewards = multiplier.mul(vofiPerSec).mul(pool.allocPoint).div(totalAllocPoint);
      accVoFiPerShare = accVoFiPerShare.add(tokenRewards.mul(1e12).div(lpSupply));
    }
    uint256 pending = user.amount.mul(accVoFiPerShare).div(1e12).sub(user.rewardDebt);
    return pending.add(user.rewardLockedUp);
  }

  // View function to see if user can harvest VoFi.
  function canHarvest(uint256 _pid, address _user) public view returns (bool) {
    UserInfo storage user = userInfo[_pid][_user];
    return block.timestamp >= user.nextHarvestUntil;
  }

  // Update reward variables for all pools. Be careful of gas spending!
  function massUpdatePools() public {
    uint256 length = poolInfo.length;
    for (uint256 pid = 0; pid < length; ++pid) {
      updatePool(pid);
    }
  }

  // Update reward variables of the given pool to be up-to-date.
  function updatePool(uint256 _pid) public {
    PoolInfo storage pool = poolInfo[_pid];
    if (block.timestamp <= pool.lastRewardTimestamp) {
      return;
    }
    uint256 lpSupply = pool.lpToken.balanceOf(address(this));
    if (lpSupply == 0 || pool.allocPoint == 0) {
      pool.lastRewardTimestamp = block.timestamp;
      return;
    }
    uint256 multiplier = getMultiplier(pool.lastRewardTimestamp, block.timestamp);
    uint256 tokenRewards = multiplier.mul(vofiPerSec).mul(pool.allocPoint).div(totalAllocPoint);
    pool.accVoFiPerShare = pool.accVoFiPerShare.add(tokenRewards.mul(1e12).div(lpSupply));
    pool.lastRewardTimestamp = block.timestamp;
  }

  // Deposit LP tokens to MasterChef for VoFi allocation.
  function deposit(uint256 _pid, uint256 _amount) external nonReentrant {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    updatePool(_pid);
    payOrLockupPendingVoFi(_pid);
    if (_amount > 0) {
      pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
      // if (address(pool.lpToken) == address(vofiToken)) {
      //     uint256 transferTax = _amount.mul(vofiToken.transferTaxRate()).div(10000);
      //     _amount = _amount.sub(transferTax);
      // }
      if (pool.depositFeeBP > 0) {
        uint256 depositFeeRate = feeStrategy.getExactFarmDepositFeeBPForVoFiHolder(pool.depositFeeBP, msg.sender);
        uint256 depositFee = _amount.mul(depositFeeRate).div(10000);
        uint256 buybackFee = depositFee.mul(BUYBACK_RATE).div(10000);
        uint256 devFee = depositFee.mul(DEV_FEE_RATE).div(10000);
        uint holdingFee = depositFee.mul(HOLDING_FEE_RATE).div(10000);

        require(buybackFee.add(devFee).add(holdingFee) == depositFee, 'VoFi: fee distribution mismatch');

        pool.lpToken.safeTransfer(buybackAddress, buybackFee);
        pool.lpToken.safeTransfer(devAddress, devFee);
        pool.lpToken.safeTransfer(feeAddress, holdingFee);

        user.amount = user.amount.add(_amount).sub(depositFee);
      } else {
        user.amount = user.amount.add(_amount);
      }
    }
    user.rewardDebt = user.amount.mul(pool.accVoFiPerShare).div(1e12);
    emit Deposit(msg.sender, _pid, _amount);
  }

  // Withdraw LP tokens from MasterChef.
  function withdraw(uint256 _pid, uint256 _amount) external nonReentrant {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    require(user.amount >= _amount, 'withdraw: not good');
    updatePool(_pid);
    payOrLockupPendingVoFi(_pid);
    if (_amount > 0) {
      user.amount = user.amount.sub(_amount);
      pool.lpToken.safeTransfer(address(msg.sender), _amount);
    }
    user.rewardDebt = user.amount.mul(pool.accVoFiPerShare).div(1e12);
    emit Withdraw(msg.sender, _pid, _amount);
  }

  // Withdraw without caring about rewards. EMERGENCY ONLY.
  function emergencyWithdraw(uint256 _pid) external nonReentrant {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    uint256 amount = user.amount;
    user.amount = 0;
    user.rewardDebt = 0;
    user.rewardLockedUp = 0;
    user.nextHarvestUntil = 0;
    pool.lpToken.safeTransfer(address(msg.sender), amount);
    emit EmergencyWithdraw(msg.sender, _pid, amount);
  }

  // Pay or lockup pending VoFi.
  function payOrLockupPendingVoFi(uint256 _pid) internal {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];

    if (user.nextHarvestUntil == 0) {
      user.nextHarvestUntil = block.timestamp.add(pool.harvestInterval);
    }

    uint256 pending = user.amount.mul(pool.accVoFiPerShare).div(1e12).sub(user.rewardDebt);
    if (canHarvest(_pid, msg.sender)) {
      if (pending > 0 || user.rewardLockedUp > 0) {
        uint256 totalRewards = pending.add(user.rewardLockedUp);

        // reset lockup
        totalLockedUpRewards = totalLockedUpRewards.sub(user.rewardLockedUp);
        user.rewardLockedUp = 0;
        user.nextHarvestUntil = block.timestamp.add(pool.harvestInterval);

        // send rewards
        safeTokenTransfer(msg.sender, totalRewards);
      }
    } else if (pending > 0) {
      user.rewardLockedUp = user.rewardLockedUp.add(pending);
      totalLockedUpRewards = totalLockedUpRewards.add(pending);
      emit RewardLockedUp(msg.sender, _pid, pending);
    }
  }

  // Safe vofiToken transfer function, just in case if rounding error causes pool to not have enough VoFi.
  function safeTokenTransfer(address _to, uint256 _amount) internal {
    uint256 tokenBal = vofiToken.balanceOf(address(this));
    if (_amount > tokenBal) {
      vofiToken.transfer(_to, tokenBal);
    } else {
      vofiToken.transfer(_to, _amount);
    }
  }

  // Update dev address by the previous dev.
  function setDevAddress(address _devAddress) external {
    require(msg.sender == devAddress, 'setDevAddress: FORBIDDEN');
    require(_devAddress != address(0), 'setDevAddress: ZERO');
    devAddress = _devAddress;
  }

  function setFeeAddress(address _feeAddress) external {
    require(msg.sender == feeAddress, 'setFeeAddress: FORBIDDEN');
    require(_feeAddress != address(0), 'setFeeAddress: ZERO');
    feeAddress = _feeAddress;
  }

  function setBuybackAddress(address _buybackAddress) external {
    require(msg.sender == buybackAddress, 'setBuybackAddress: FORBIDDEN');
    require(_buybackAddress != address(0), 'setBuybackAddress: ZERO');
    buybackAddress = _buybackAddress;
  }

  // Pancake has to add hidden dummy pools in order to alter the emission, here we make it simple and transparent to all.
  function updateEmissionRate(uint256 _vofiPerSec) external onlyOwner {
    massUpdatePools();
    emit EmissionRateUpdated(msg.sender, vofiPerSec, _vofiPerSec);
    vofiPerSec = _vofiPerSec;
  }

  // Update referral commission rate by the owner
  function setReferralCommissionRate(uint16 _referralCommissionRate) external onlyOwner {
    require(_referralCommissionRate <= MAXIMUM_REFERRAL_COMMISSION_RATE, 'setReferralCommissionRate: invalid referral commission rate basis points');
    referralCommissionRate = _referralCommissionRate;
  }

  function setFeeStrategy(address _feeStrategy) external onlyOwner {
    feeStrategy = IFeeStrategy(_feeStrategy);
  }
}
