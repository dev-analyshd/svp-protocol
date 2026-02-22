# Phase 12: Mainnet Deployment Configuration

**Status**: 🚀 **MAINNET PARAMETERS & DEPLOYMENT STRATEGY**
**Target Networks**: Ethereum, Arbitrum One, Polygon
**Launch Date**: April 15, 2026 (Target)
**Phase**: Pre-Mainnet Configuration

---

## 🌐 Mainnet Network Parameters

### Ethereum Mainnet (Chain ID: 1)

#### Network Information
```
Network Name:           Ethereum Mainnet
Chain ID:               1
Network Type:           Proof of Stake
Consensus:              Ethereum Beacon Chain
Block Time:             ~12 seconds
Final Block Depth:      ~15 minutes
Average Gas Price:      [Current: 20-50 Gwei]

RPC Endpoint:
  Primary:   https://eth-mainnet.alchemyapi.io/v2/[KEY]
  Fallback1: https://mainnet.infura.io/v3/[KEY]
  Fallback2: https://endpoints.omnirpc.io/eth

Explorer:
  Primary:   https://etherscan.io
  Backup:    https://eth.blockscout.com

Network Stats:
  Daily Transactions:    ~1.3M
  Active Addresses:      ~200K
  Transaction Cost:      High (reference baseline)
  Liquidity Pools:       Largest (Uniswap v3, v4)
```

#### Deployment Parameters
```
NETWORK_NAME:           "Ethereum"
CHAIN_ID:              1
MAX_GAS_PRICE:         200 Gwei (safety limit)
MIN_CONFIRMATION:      12 blocks (~2.4 min)
DEPLOYMENT_TYPE:       Standard deployment
EXPECTED_GAS_COST:     $50K-$150K (in ETH)
```

### Arbitrum One (Chain ID: 42161)

#### Network Information
```
Network Name:           Arbitrum One
Chain ID:               42161
Parent Chain:           Ethereum (settlement)
Block Time:            ~250ms (very fast)
Finality:              ~7 minutes
Average Gas Price:     [Current: 0.1-1 Gwei]

RPC Endpoint:
  Primary:   https://arb1.arbitrum.io/rpc
  Fallback1: https://arbitrum.meowrpc.com
  Fallback2: https://arbitrum.publicrpc.com

Explorer:
  Primary:   https://arbiscan.io
  Backup:    https://explorer.arbitrum.io

Network Stats:
  Daily Transactions:    ~500K
  Active Addresses:      ~50K
  Transaction Cost:      Very low (0.1-1% of Ethereum)
  Liquidity Pools:       Growing (Uniswap v3, Camelot)
```

#### Deployment Parameters
```
NETWORK_NAME:           "Arbitrum One"
CHAIN_ID:              42161
MAX_GAS_PRICE:         10 Gwei (safety limit)
MIN_CONFIRMATION:      24 blocks (~6 seconds)
DEPLOYMENT_TYPE:       Standard deployment
EXPECTED_GAS_COST:     $200-$500 (in ETH)
```

### Polygon (Chain ID: 137)

#### Network Information
```
Network Name:           Polygon (Matic)
Chain ID:               137
Consensus:              Proof of Stake
Block Time:             ~2 seconds
Finality:              ~128 blocks (~256 seconds)
Average Gas Price:     [Current: 20-50 Gwei (MATIC)]

RPC Endpoint:
  Primary:   https://polygon-rpc.com
  Fallback1: https://poly-rpc.maticvigil.com
  Fallback2: https://polygonapi.terminet.io

Explorer:
  Primary:   https://polygonscan.com
  Backup:    https://www.oklink.com/polygon

Network Stats:
  Daily Transactions:    ~2M
  Active Addresses:      ~150K
  Transaction Cost:      Very low (~$0.01-$0.10)
  Liquidity Pools:       Good (Uniswap v3, QuickSwap)
```

#### Deployment Parameters
```
NETWORK_NAME:           "Polygon"
CHAIN_ID:              137
MAX_GAS_PRICE:         500 Gwei (safety limit)
MIN_CONFIRMATION:      256 blocks (~8.5 min)
DEPLOYMENT_TYPE:       Standard deployment
EXPECTED_GAS_COST:     $500-$1000 (in MATIC)
```

---

## 📋 Smart Contract Deployment Order

### Deployment Sequence (Per Network)

#### Phase 1: Core Infrastructure (Blocks 1-4)

**1. Deploy SVPToken.sol** (20-30 minutes)
```solidity
constructor(
  string memory name = "SVP Protocol Token",
  string memory symbol = "SVP",
  uint8 decimals = 18,
  uint256 initialSupply = 1,000,000 * 10**18
)

Post-Deploy Verification:
- ✅ Name: "SVP Protocol Token"
- ✅ Symbol: "SVP"
- ✅ Decimals: 18
- ✅ Total Supply: 1,000,000 SVP
- ✅ Contract verified on explorer
- ✅ Owner set to timelock
```

**2. Deploy Governance Token** (10-20 minutes)
```solidity
constructor(
  address svpTokenAddress,
  uint256 initialGovernanceSupply = 100,000 * 10**18
)

Post-Deploy Verification:
- ✅ Token linked correctly
- ✅ Governance supply set
- ✅ Voting weight calculated
- ✅ Contract verified
```

**3. Deploy Timelock Governor** (15-25 minutes)
```solidity
constructor(
  address governance,
  uint256 delay = 2 days,
  uint256 votingPeriod = 50400 blocks (Ethereum),
  uint256 votingDelay = 1 block,
  uint256 proposalThreshold = 10,000 * 10**18
)

Post-Deploy Verification:
- ✅ Timelock delay: 2 days
- ✅ Voting period: 50,400 blocks
- ✅ Proposal threshold set
- ✅ Governance token linked
```

**4. Deploy Emergency Fund** (10-15 minutes)
```solidity
constructor(
  address owner,
  uint256 emergencyWithdrawalDelay = 7 days
)

Post-Deploy Verification:
- ✅ Owner set correctly
- ✅ Delay configured
- ✅ Fund access available
- ✅ Recovery procedures tested
```

#### Phase 2: Price & Yield Infrastructure (Blocks 5-9)

**5. Deploy Price Feed Aggregator** (15-20 minutes)
```solidity
constructor(
  address[] memory priceFeeds,
  address[] memory tokens,
  uint256 updateInterval = 1 hours
)

Post-Deploy Verification:
- ✅ Price feeds connected
- ✅ Tokens registered
- ✅ Update interval set
- ✅ Initial prices retrieved
```

**6. Deploy Yield Calculator** (10-15 minutes)
```solidity
constructor(
  uint256 baseYield = 10%, // 10% annual
  uint256 maxYield = 25%,  // 25% max
  address priceAggregator
)

Post-Deploy Verification:
- ✅ Yield parameters set
- ✅ Price source linked
- ✅ Calculations verified
```

**7. Deploy Staking Rewards** (15-20 minutes)
```solidity
constructor(
  address svpToken,
  address rewardToken,
  uint256 rewardRate = 100 * 10**18 // per day
)

Post-Deploy Verification:
- ✅ Token addresses set
- ✅ Reward rate configured
- ✅ Distribution parameters verified
```

**8. Deploy Revenue Distribution** (15-20 minutes)
```solidity
constructor(
  address[] memory recipients,
  uint256[] memory percentages,
  address tokenAddress
)

Post-Deploy Verification:
- ✅ Recipients configured
- ✅ Percentages sum to 100%
- ✅ Token address set
- ✅ Distribution logic tested
```

**9. Deploy Dividend Distribution** (15-20 minutes)
```solidity
constructor(
  address svpToken,
  address[] memory dividendTokens,
  uint256 distributionInterval = 7 days
)

Post-Deploy Verification:
- ✅ SVP token linked
- ✅ Dividend tokens registered
- ✅ Distribution interval set
```

#### Phase 3: Vault Infrastructure (Blocks 10-15)

**10. Deploy Vault Base** (20-30 minutes)
```solidity
constructor(
  address svpToken,
  uint256 minDeposit = 1 * 10**18,
  uint256 maxDeposit = 10,000,000 * 10**18,
  address yieldCalculator
)

Post-Deploy Verification:
- ✅ Token address set
- ✅ Deposit limits configured
- ✅ Yield calculator linked
- ✅ Emergency pause available
```

**11. Deploy Vault Manager** (15-20 minutes)
```solidity
constructor(
  address[] memory vaults,
  address governor,
  uint256 rebalanceInterval = 1 days
)

Post-Deploy Verification:
- ✅ Vaults registered
- ✅ Governor linked
- ✅ Rebalance timing set
```

**12. Deploy Risk Manager** (15-20 minutes)
```solidity
constructor(
  uint256 maxRiskLevel = 80%, // 80% max
  address priceAggregator
)

Post-Deploy Verification:
- ✅ Risk parameters set
- ✅ Price source linked
- ✅ Risk monitoring active
```

**13. Deploy Emergency Withdrawal** (10-15 minutes)
```solidity
constructor(
  address vault,
  uint256 withdrawalDelay = 3 hours,
  address governor
)

Post-Deploy Verification:
- ✅ Vault linked
- ✅ Delay configured
- ✅ Governor access set
```

**14. Deploy Vault Analytics** (10-15 minutes)
```solidity
constructor(
  address vault,
  address priceAggregator
)

Post-Deploy Verification:
- ✅ Vault linked
- ✅ Analytics calculations verified
```

**15. Deploy Liquidity Provider** (20-30 minutes)
```solidity
constructor(
  address router,  // DEX router (Uniswap/Camelot/QuickSwap)
  address factory, // DEX factory
  address svpToken
)

Post-Deploy Verification:
- ✅ DEX contracts linked correctly
- ✅ SVP token set
- ✅ Liquidity pool created
```

#### Phase 4: Governance Infrastructure (Blocks 16-18)

**16. Deploy Governance Token Wrapper** (10-15 minutes)
```solidity
constructor(
  address svpToken,
  address governanceToken
)

Post-Deploy Verification:
- ✅ Tokens linked
- ✅ Voting power calculated
```

**17. Deploy Proposal Queue** (10-15 minutes)
```solidity
constructor(
  address governor,
  uint256 maxQueuedProposals = 100
)

Post-Deploy Verification:
- ✅ Governor linked
- ✅ Queue capacity set
```

**18. Deploy Voting Escrow (Optional Upgrade)** (15-20 minutes)
```solidity
constructor(
  address svpToken,
  uint256 maxLockTime = 4 years
)

Post-Deploy Verification:
- ✅ Token linked
- ✅ Lock time configured
```

#### Phase 5: Upgradeable Proxies (Blocks 19-21)

**19. Deploy Proxy Admin** (10-15 minutes)
```solidity
constructor(
  address owner
)

Post-Deploy Verification:
- ✅ Admin permissions set
- ✅ Access control verified
```

**20. Deploy Implementation Proxies** (20-30 minutes)
- For contracts requiring upgrades
- One proxy per upgradeable contract
- Total proxies: [N] (as needed)

Post-Deploy Verification:
- ✅ Logic contracts linked
- ✅ Admin set correctly
- ✅ Initialization data verified

**21. Deploy Access Control Registry** (10-15 minutes)
```solidity
constructor(
  address governance
)

Post-Deploy Verification:
- ✅ Roles configured
- ✅ Access control verified
```

---

## 💰 Deployment Cost Estimation

### Ethereum Mainnet Costs

```
Contract Deployment Costs:

Core Contracts (4):
  SVPToken              ~$40K-$60K
  GovernanceToken       ~$20K-$30K
  Governor              ~$40K-$60K
  EmergencyFund         ~$15K-$25K
  Subtotal: ~$115K-$175K

Infrastructure (5):
  PriceFeedAggregator   ~$30K-$50K
  YieldCalculator       ~$25K-$40K
  StakingRewards        ~$25K-$40K
  RevenueDistribution   ~$20K-$30K
  DividendDistribution  ~$25K-$40K
  Subtotal: ~$125K-$200K

Vault Infrastructure (6):
  VaultBase             ~$50K-$80K
  VaultManager          ~$30K-$50K
  RiskManager           ~$25K-$40K
  EmergencyWithdrawal   ~$20K-$30K
  VaultAnalytics        ~$15K-$25K
  LiquidityProvider     ~$40K-$60K
  Subtotal: ~$180K-$285K

Governance (3):
  GovernanceWrapper     ~$15K-$25K
  ProposalQueue         ~$15K-$25K
  VotingEscrow          ~$25K-$40K
  Subtotal: ~$55K-$90K

Infrastructure (3):
  ProxyAdmin            ~$10K-$15K
  Proxies (N)           ~$10K-$15K each
  AccessControl         ~$10K-$15K
  Subtotal: ~$30K-$45K
  
───────────────────────────
Total Estimated Cost:     $505K-$795K USD
Contingency (20%):        $101K-$159K USD
───────────────────────────
Total with Buffer:        $606K-$954K USD

Cost Per Network (3x):    $1.8M-$2.9M USD total
```

### Arbitrum One Costs (70% savings)

```
Total Estimated Cost:     $150K-$240K USD
(70% cheaper due to L2 optimization)
```

### Polygon Costs (85% savings)

```
Total Estimated Cost:     $75K-$120K USD
(85% cheaper due to PoS efficiency)
```

### Total Mainnet Deployment Budget

```
Ethereum:     $600K-$950K
Arbitrum:     $150K-$240K
Polygon:      $75K-$120K
──────────────────────────
Total:        $825K-$1.31M USD

Contingency:  +20% ($165K-$262K)
──────────────────────────
Final Budget: $990K-$1.57M USD
```

---

## ⚙️ Initialization Parameters

### SVP Token Configuration
```
Name:                   "SVP Protocol Token"
Symbol:                 "SVP"
Decimals:              18
Initial Supply:        1,000,000 SVP (1M)
Max Supply:            10,000,000 SVP (10M)
Mint Cap:              Unlimited (governance controlled)
Burn Allowed:          Yes
Pause Allowed:         Yes (emergency)
```

### Staking Configuration
```
Min Stake:             1 SVP (10**18 wei)
Max Stake:             Unlimited
Lock-up Period:        0 days (immediate unstaking)
Reward Rate:           100 SVP/day (adjustable)
Reward Token:          [Native network token or SVP]
Claim Frequency:       Daily (manual or auto)
Cooldown Period:       0 seconds
```

### Vault Configuration
```
Min Deposit:           1 SVP (10**18 wei)
Max Deposit:           10,000,000 SVP
Deposit Fee:           0% (initially)
Withdrawal Fee:        0% (initially)
Performance Fee:       20% of yield (standard)
Management Fee:        0% (no ongoing fee)
Rebalance Frequency:   Daily
```

### Governance Configuration
```
Voting Token:          Governance Token (1 token = 1 vote)
Voting Delay:          1 block
Voting Period:         50,400 blocks (Ethereum)
                       201,600 blocks (Arbitrum)
                       50,400 blocks (Polygon)
Proposal Threshold:    10,000 tokens
Quorum Requirement:    4% of total supply
Timelock Delay:        2 days (48 hours)
Max Proposal Duration: 7 days
```

### Dividend Configuration
```
Distribution Token:    [Stablecoin - USDC/DAI/USDT]
Distribution Schedule: Weekly (Sunday 00:00 UTC)
Min Claim Amount:      $1 USDC equivalent
Max Claim Per User:    Unlimited
Claim Fee:             0%
Accrual Frequency:     Real-time
Excess Dividend:       Carried forward to next period
```

### Oracle Configuration
```
Price Feed Provider:   Chainlink
Update Frequency:      Hourly (3600 seconds)
Staleness Threshold:   24 hours
Fallback Strategy:     Secondary oracle on-chain
Deviation Threshold:   5% (trigger update)
Gas Optimization:      Off-chain aggregation
```

---

## 🔐 Security Configuration

### Access Control

**Admin Functions** (Multi-sig, 3-of-5)
```
- Contract upgrades
- Parameter changes
- Emergency pause
- Fund recovery
- Whitelist management
```

**Governor Functions** (Timelock, 2-day delay)
```
- Vault parameter changes
- Reward rate adjustments
- Fee configuration
- Asset addition/removal
- Policy updates
```

**User Functions** (Open to all)
```
- Deposits
- Withdrawals
- Staking
- Voting
- Claiming rewards/dividends
```

### Emergency Procedures

**Pause Mechanism**
```
Activation:     Admin multi-sig (3-of-5 approval)
Duration:       Up to 30 days (renewable)
Effect:         Disables new deposits, enables withdrawals
Manual Unlock:  Requires governance vote
```

**Circuit Breaker**
```
Trigger:        If price changes >20% in 1 hour
Activation:     Automatic
Duration:       15 minutes (automatic reset)
Effect:         Rate limiting on large transactions
Manual Reset:   Admin multi-sig
```

**Emergency Fund**
```
Total Reserve:  10% of vault TVL
Withdrawal:     7-day delay (can be expedited by governance)
Purpose:        Compensating victims of exploits
Governance:     Community voting on allocation
```

---

## 📊 Deployment Readiness Checklist

### Pre-Deployment (Week Before)

- [ ] All contracts compiled without warnings
- [ ] All tests passing (19/19)
- [ ] Code review completed
- [ ] Security audit completed
- [ ] Deployment scripts tested on testnet
- [ ] RPC endpoints verified and responsive
- [ ] Private keys secured (multi-sig setup)
- [ ] Team trained on deployment procedures
- [ ] Emergency rollback plan prepared
- [ ] Communications drafted

### Deployment Day

- [ ] Final code review (spot-check)
- [ ] All team members online and ready
- [ ] Multi-sig signatories confirmed
- [ ] Gas prices checked and within budget
- [ ] Backup RPC endpoints tested
- [ ] Monitoring tools active
- [ ] Communication channels open
- [ ] Deployment scripts verified one last time

### Post-Deployment

- [ ] All contracts verified on block explorers
- [ ] Contract ownership transferred to governance
- [ ] Initial liquidity provided
- [ ] Frontend updated with contract addresses
- [ ] SDK updated with new ABIs
- [ ] Monitoring dashboards active
- [ ] Documentation updated
- [ ] Community announcement published

---

## 🚨 Rollback Procedures

### If Deployment Fails

1. **Identify Issue** (< 5 minutes)
   - Check transaction status
   - Review logs
   - Assess impact

2. **Stop Deployment** (< 1 minute)
   - Cancel pending transactions
   - Pause all processes
   - Notify team

3. **Assess & Fix** (15-30 minutes)
   - Identify root cause
   - Implement fix
   - Test fix locally

4. **Retry Deployment** (< 1 hour)
   - Adjust deployment parameters
   - Rerun scripts
   - Verify success

5. **Validate** (< 30 minutes)
   - Confirm all contracts deployed
   - Verify initialization parameters
   - Test basic functionality

### If Critical Issue Post-Deployment

1. **Activate Emergency Pause** (< 1 minute)
   - Multi-sig pause all operations
   - Notify users
   - Preserve all funds

2. **Investigate** (< 1 hour)
   - Identify issue scope
   - Assess user impact
   - Plan recovery

3. **Prepare Fix** (1-4 hours)
   - Develop patch
   - Test thoroughly
   - Plan redeployment

4. **Communicate** (Continuous)
   - Post frequent updates
   - Provide ETA for resolution
   - Manage community expectations

5. **Redeploy** (As needed)
   - Deploy patched version
   - Migrate state if needed
   - Resume operations
   - Post-incident review

---

## 📋 Network-Specific Configurations

### Ethereum Mainnet (.env)
```
ETHEREUM_RPC=https://eth-mainnet.alchemyapi.io/v2/[KEY]
ETHEREUM_CHAIN_ID=1
ETHEREUM_GAS_LIMIT=15000000
ETHEREUM_GAS_PRICE=50 # Gwei
ETHEREUM_CONFIRMATIONS=12
ETHEREUM_BLOCK_TIME=12 # seconds
ETHEREUM_MULTISIG=[Address]
ETHEREUM_TIMELOCK=[Address]
```

### Arbitrum One (.env)
```
ARBITRUM_RPC=https://arb1.arbitrum.io/rpc
ARBITRUM_CHAIN_ID=42161
ARBITRUM_GAS_LIMIT=2000000
ARBITRUM_GAS_PRICE=0.5 # Gwei
ARBITRUM_CONFIRMATIONS=24
ARBITRUM_BLOCK_TIME=0.25 # seconds
ARBITRUM_MULTISIG=[Address]
ARBITRUM_TIMELOCK=[Address]
```

### Polygon (.env)
```
POLYGON_RPC=https://polygon-rpc.com
POLYGON_CHAIN_ID=137
POLYGON_GAS_LIMIT=5000000
POLYGON_GAS_PRICE=50 # Gwei (MATIC)
POLYGON_CONFIRMATIONS=256
POLYGON_BLOCK_TIME=2 # seconds
POLYGON_MULTISIG=[Address]
POLYGON_TIMELOCK=[Address]
```

---

## ✨ Success Criteria

### Deployment Success = All of:
1. ✅ All 21 contracts deployed successfully
2. ✅ All contracts verified on block explorers
3. ✅ All initialization parameters correct
4. ✅ Ownership transferred to governance/multi-sig
5. ✅ No critical issues found
6. ✅ All systems responsive
7. ✅ Monitoring active and reporting
8. ✅ Team confident in rollout

### Go-Live Success = All of:
1. ✅ Initial liquidity provided ($[N]K+)
2. ✅ Frontend fully functional
3. ✅ SDK working with mainnet
4. ✅ Users can deposit and withdraw
5. ✅ Governance fully functional
6. ✅ No critical bugs reported
7. ✅ Transaction success rate >99%
8. ✅ Community support strong

---

**Status**: ✅ **MAINNET CONFIGURATION COMPLETE**
**Total Contracts**: 21 smart contracts across 3 networks
**Estimated Cost**: $990K-$1.57M USD (with 20% contingency)
**Timeline**: April 9-15, 2026
**Next Phase**: Pre-mainnet verification checklist

