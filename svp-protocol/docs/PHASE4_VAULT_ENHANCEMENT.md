# Phase 4: SPV Vault Enhancement (ERC-4626)

**Status:** In Progress  
**Timeline:** 2-3 days  
**Priority:** High (enables institutional capital pooling)

## Overview

Phase 4 enhances the existing SVPSPVVault.sol (650 lines from Phase 2) with advanced portfolio management, yield optimization, and partition-aware vault features. This phase transforms the vault from basic capital pooling to an institutional-grade investment vehicle supporting complex rebalancing, multi-asset yield optimization, and SVPToken1400 partition integration.

---

## Phase 2 Foundation (Current State)

### What Already Exists

**SVPSPVVault.sol (650 lines):**
- ERC-4626 standard implementation (deposit/withdraw/mint/redeem)
- Position management (open/close positions)
- Redemption queue with cooldown period
- NAV (Net Asset Value) calculation per share
- Fee collection (management + performance fees)
- Rebalancing framework
- Dividend tracking
- Access control (MANAGER_ROLE, ADMIN_ROLE)
- Pausable contract with ReentrancyGuard

**Data Structures:**
- `Position`: Asset holdings with allocation tracking
- `RedemptionRequest`: Cooldown-based redemption queue
- `PerformanceMetrics`: Historical performance tracking

**Core Features:**
- Minimum deposit enforcement (100 USDC)
- Maximum allocation per asset (30%)
- Weekly rebalancing frequency
- Annual management fee (2%)
- Performance fee (20% of profits)
- NAV history tracking

---

## Phase 4 Enhancements

### 1. Advanced Rebalancing Strategies

**Purpose:** Enable flexible portfolio composition management with multiple strategy options

**New Features:**

#### A. Target Allocation Rebalancing
```solidity
struct TargetAllocation {
    address asset;
    uint256 targetPercentage;  // In basis points
    uint256 tolerance;          // Rebalance if deviation > tolerance
}

mapping(bytes32 => TargetAllocation[]) public allocationStrategies;
bytes32 public activeStrategy;

function setAllocationStrategy(bytes32 strategyId, TargetAllocation[] calldata allocations)
    external
    onlyRole(MANAGER_ROLE)

function rebalanceToTarget(bytes32 strategyId)
    external
    onlyRole(MANAGER_ROLE)
    nonReentrant
```

**Benefits:**
- Portfolio composition consistency
- Automated drift correction
- Multi-strategy support (growth, conservative, balanced)

#### B. Risk-Based Rebalancing
```solidity
struct RiskProfile {
    uint256 maxAssetConcentration;    // Max % in single asset
    uint256 maxSectorConcentration;   // Max % in single sector
    uint256 minDiversification;       // Minimum number of assets
    uint256 volatilityThreshold;      // Rebalance if vol > threshold
}

function rebalanceByRiskProfile(uint256 riskLevel)
    external
    onlyRole(MANAGER_ROLE)
```

#### C. Time-Weighted Rebalancing
```solidity
struct RebalanceSchedule {
    uint256 frequency;                 // Days between rebalances
    uint256 dayOfWeek;                // 0-6 (Monday-Sunday)
    uint256 hourOfDay;                 // 0-23 UTC
    bool enabled;
}

function scheduleRebalance(RebalanceSchedule calldata schedule)
    external
    onlyRole(MANAGER_ROLE)
```

**Implementation Requirements:**
- 3-5 new functions for strategy management
- Storage for allocation strategies and schedules
- 8 new events for rebalancing actions
- ~200 lines of code

---

### 2. Yield Optimization Module

**Purpose:** Maximize returns through intelligent yield farming and deployment strategies

**New Features:**

#### A. Yield Strategy Registry
```solidity
struct YieldStrategy {
    string name;
    address targetProtocol;           // Lido, Curve, Aave, etc.
    uint256 expectedAPY;              // Expected annual percentage yield
    uint256 riskScore;                // 1-100 (higher = riskier)
    bytes32[] supportedAssets;        // Assets compatible with strategy
    bool enabled;
    uint256 maxAllocation;            // Max % of vault in this strategy
}

mapping(bytes32 => YieldStrategy) public yieldStrategies;

function registerYieldStrategy(bytes32 strategyId, YieldStrategy calldata strategy)
    external
    onlyRole(ADMIN_ROLE)

function deployToYieldStrategy(bytes32 strategyId, uint256 amount)
    external
    onlyRole(MANAGER_ROLE)
    nonReentrant

function withdrawFromYieldStrategy(bytes32 strategyId, uint256 amount)
    external
    onlyRole(MANAGER_ROLE)
    nonReentrant
```

#### B. Compound Yield Tracking
```solidity
struct YieldPosition {
    bytes32 strategyId;
    uint256 principalDeployed;
    uint256 yieldAccrued;
    uint256 deploymentTimestamp;
    uint256 lastClaimTimestamp;
    bool autoCompound;
}

mapping(address => YieldPosition[]) public yieldPositions;

function claimYield(uint256 positionIndex)
    external
    nonReentrant
    returns (uint256 yieldAmount)

function setAutoCompound(uint256 positionIndex, bool enabled)
    external
```

#### C. Yield Comparison & Redeployment
```solidity
function getStrategyAPY(bytes32 strategyId)
    external
    view
    returns (uint256 estimatedAPY)

function findHighestYieldStrategy(address asset)
    external
    view
    returns (bytes32 bestStrategy, uint256 apy)

function redeployToHigherYield()
    external
    onlyRole(MANAGER_ROLE)
    nonReentrant
```

**Implementation Requirements:**
- Strategy registration and management (~150 lines)
- Yield position tracking (100+ lines)
- Auto-compound logic (80+ lines)
- 12+ new events
- Integration with external protocols (Curve, Lido, Aave interfaces)

---

### 3. Partition-Aware Vault Features

**Purpose:** Integrate with SVPToken1400 partitions for partition-specific yield and governance

**New Features:**

#### A. Partition-Specific Yield Pools
```solidity
struct PartitionPool {
    bytes32 partition;                // From SVPToken1400
    uint256 totalDeposits;            // Total in partition-specific pool
    uint256 yieldAccrued;             // Yield earned by partition
    mapping(address => uint256) deposits;  // User deposits by partition
}

mapping(bytes32 => PartitionPool) public partitionPools;

function depositByPartition(
    bytes32 partition,
    uint256 assets,
    address receiver
)
    external
    whenNotPaused
    nonReentrant
    returns (uint256 shares)

function getPartitionYieldPerShare(bytes32 partition)
    external
    view
    returns (uint256)

function claimPartitionYield(bytes32 partition)
    external
    nonReentrant
    returns (uint256 yieldAmount)
```

#### B. Partition-Based Allocation Rules
```solidity
struct PartitionAllocationRule {
    bytes32 partition;
    uint256[] allowedAssets;          // Assets this partition can access
    uint256 maxAllocation;             // Max % of vault
    bool yieldEnabled;                 // Can earn yield
    bool votingEnabled;                // Can vote in governance
}

mapping(bytes32 => PartitionAllocationRule) public allocationRules;

function setPartitionAllocationRule(
    bytes32 partition,
    PartitionAllocationRule calldata rule
)
    external
    onlyRole(ADMIN_ROLE)

function enforcePartitionAllocations()
    external
    onlyRole(MANAGER_ROLE)
```

#### C. Cross-Partition Yield Routing
```solidity
enum YieldRoutingStrategy {
    PROPORTIONAL,      // Route yield by partition deposits
    EQUAL,            // Equal yield to all partitions
    PERFORMANCE_BASED, // Yield based on partition performance
    CUSTOM            // Custom routing formula
}

struct YieldRoutingConfig {
    YieldRoutingStrategy strategy;
    mapping(bytes32 => uint256) customWeights;  // For CUSTOM strategy
    uint256 lastRoutedTimestamp;
}

YieldRoutingConfig public yieldRouting;

function setYieldRouting(YieldRoutingStrategy strategy)
    external
    onlyRole(ADMIN_ROLE)

function routeYieldToPartitions()
    external
    onlyRole(MANAGER_ROLE)
    nonReentrant
```

**Implementation Requirements:**
- Partition pool tracking (120+ lines)
- Allocation rule enforcement (100+ lines)
- Yield routing engine (150+ lines)
- Integration with SVPToken1400 interfaces
- 15+ new events

---

### 4. Advanced Withdrawal Management

**Purpose:** Handle complex withdrawal scenarios with optimized liquidity management

**New Features:**

#### A. Tiered Withdrawal Queues
```solidity
enum WithdrawalTier {
    INSTANT,        // Available immediately (up to 5% of AUM)
    STANDARD,       // 1-3 day cooldown
    DELAYED,        // 1 week cooldown (for complex positions)
    CUSTOM          // Custom duration
}

struct TieredRedemption {
    address requester;
    uint256 shareAmount;
    WithdrawalTier tier;
    uint256 requestTimestamp;
    uint256 releaseTimestamp;
    bool completed;
}

mapping(WithdrawalTier => TieredRedemption[]) public tierQueues;

function requestTieredRedemption(uint256 shares, WithdrawalTier tier)
    external
    returns (uint256 redemptionId)

function executeTieredRedemption(uint256 redemptionId)
    external
    nonReentrant
```

#### B. Withdrawal Optimization
```solidity
function optimizeWithdrawal(uint256 shareAmount)
    external
    view
    returns (
        address[] memory assets,
        uint256[] memory amounts,
        uint256 minValue
    )

function executeOptimizedWithdrawal(
    uint256 shareAmount,
    address[] calldata assets,
    uint256[] calldata minAmounts
)
    external
    nonReentrant
    returns (uint256 totalValue)
```

#### C. Liquidity Reserve Management
```solidity
struct LiquidityReserve {
    uint256 targetPercentage;         // % of AUM to keep liquid
    uint256 currentBalance;            // Current liquid balance
    uint256 lastRebalanceTimestamp;
    bool autoMaintain;                 // Auto-rebalance to target
}

LiquidityReserve public reserve;

function setLiquidityReserve(uint256 targetPercentage, bool autoMaintain)
    external
    onlyRole(ADMIN_ROLE)

function maintainLiquidityReserve()
    external
    onlyRole(MANAGER_ROLE)
    nonReentrant
```

**Implementation Requirements:**
- Tiered queue system (120+ lines)
- Withdrawal optimization logic (100+ lines)
- Liquidity reserve management (80+ lines)
- 10+ new events

---

### 5. Performance Analytics & Reporting

**Purpose:** Provide comprehensive performance metrics and reporting capabilities

**New Features:**

#### A. Enhanced Performance Tracking
```solidity
struct PerformanceSnapshot {
    uint256 timestamp;
    uint256 totalAssets;
    uint256 totalShares;
    uint256 navPerShare;
    int256 dailyReturn;               // % change from previous day
    int256 weeklyReturn;
    int256 monthlyReturn;
    int256 yearToDateReturn;
    uint256 totalYieldGenerated;
    uint256 feesCollected;
}

PerformanceSnapshot[] public performanceHistory;
mapping(address => uint256) public userContribution;
mapping(address => uint256) public userRealizedGains;

function recordPerformanceSnapshot() external onlyRole(MANAGER_ROLE)

function getPerformanceMetrics(uint256 daysBack)
    external
    view
    returns (PerformanceSnapshot memory)

function calculateUserPnL(address user)
    external
    view
    returns (int256 totalPnL, uint256 realizedGains, uint256 unrealizedGains)
```

#### B. Risk Metrics
```solidity
struct RiskMetrics {
    uint256 volatility;               // Standard deviation of returns
    uint256 sharpeRatio;              // Risk-adjusted return
    uint256 maxDrawdown;              // Largest peak-to-trough decline
    uint256 beta;                     // Correlation to benchmark
    uint256 concentrationRisk;        // Largest position % of portfolio
}

function calculateRiskMetrics(uint256 lookbackDays)
    external
    view
    returns (RiskMetrics memory)
```

#### C. Report Generation
```solidity
function generatePerformanceReport(uint256 startTimestamp, uint256 endTimestamp)
    external
    view
    returns (string memory reportURI)

function exportPortfolioComposition()
    external
    view
    returns (
        address[] memory assets,
        uint256[] memory amounts,
        uint256[] memory percentages
    )
```

**Implementation Requirements:**
- Performance tracking (150+ lines)
- Risk calculation (120+ lines)
- Report generation (100+ lines)
- 8+ new events

---

### 6. Multi-Asset & Stablecoin Support

**Purpose:** Expand vault to support multiple stablecoin bases and cross-collateral scenarios

**New Features:**

#### A. Multi-Asset Vault Base
```solidity
mapping(address => bool) public supportedAssets;
address[] public baseAssets;

struct AssetConfig {
    address assetAddress;
    uint8 decimals;
    uint256 conversionRate;           // Rate to primary asset (USDC)
    bool enabled;
}

mapping(address => AssetConfig) public assetConfigs;

function addSupportedAsset(
    address assetAddress,
    uint8 decimals,
    uint256 conversionRate
)
    external
    onlyRole(ADMIN_ROLE)

function depositInAsset(
    address asset,
    uint256 amount,
    address receiver
)
    external
    nonReentrant
    returns (uint256 shares)
```

#### B. Cross-Asset Rebalancing
```solidity
function rebalanceBetweenAssets(
    address fromAsset,
    address toAsset,
    uint256 amount
)
    external
    onlyRole(MANAGER_ROLE)
    nonReentrant

function automaticStablecoinArbitrage()
    external
    onlyRole(MANAGER_ROLE)
    nonReentrant
```

**Implementation Requirements:**
- Multi-asset support (100+ lines)
- Conversion rate tracking (60+ lines)
- Cross-asset logic (80+ lines)
- 5+ new events

---

## Implementation Architecture

### File Organization

**Main Contract Enhancement:**
- `contracts/SVPSPVVault.sol` - Extend from 675 → ~1,200 lines
  - Advanced rebalancing (250 lines)
  - Yield optimization (280 lines)
  - Partition features (300 lines)
  - Withdrawal management (200 lines)
  - Analytics (150 lines)
  - Multi-asset support (120 lines)
  - Helper functions (100 lines)

**New Supporting Files:**
- `contracts/interfaces/IYieldStrategy.sol` - External protocol interfaces
- `contracts/libraries/VaultMath.sol` - Calculation library (200+ lines)
- `contracts/libraries/PerformanceCalculator.sol` - Performance metrics (180+ lines)

**Documentation:**
- `docs/PHASE4_DEPLOYMENT.md` - Deployment guide
- `docs/PHASE4_STRATEGIES.md` - Strategy configuration guide
- `docs/VAULT_EXAMPLES.md` - Usage examples

### Integration Points

**With Phase 2 Contracts:**
- `SVPToken.sol` - Base token for positions
- `SVPToken1400.sol` - Partition-aware features
- `SVPDividendDistributor.sol` - Dividend routing
- `SVPValuationEngine.sol` - Asset price feeds
- `SVPGovernance.sol` - Governance integration

**With External Protocols:**
- Curve Finance (stablecoin swaps)
- Lido (ETH staking)
- Aave (lending)
- Uniswap v3 (liquidity provision)

### Access Control Matrix

| Function | DEFAULT_ADMIN | MANAGER_ROLE | ADMIN_ROLE | Role |
|----------|---------------|--------------|-----------|------|
| setAllocationStrategy | ✓ | - | - | Admin |
| rebalanceToTarget | - | ✓ | - | Manager |
| registerYieldStrategy | ✓ | - | - | Admin |
| deployToYieldStrategy | - | ✓ | - | Manager |
| setPartitionAllocationRule | ✓ | - | ✓ | Admin |
| routeYieldToPartitions | - | ✓ | - | Manager |
| setLiquidityReserve | ✓ | - | ✓ | Admin |
| recordPerformanceSnapshot | - | ✓ | - | Manager |
| addSupportedAsset | ✓ | - | ✓ | Admin |

### Events (40+ Total)

**Rebalancing Events:**
```solidity
event AllocationStrategyUpdated(bytes32 indexed strategyId, uint256 timestamp);
event StrategyRebalanced(bytes32 indexed strategyId, uint256[] oldAllocations, uint256[] newAllocations);
event RiskProfileRebalanced(uint256 riskLevel, uint256 timestamp);
event RebalanceScheduleSet(uint256 frequency, uint256 dayOfWeek, uint256 hourOfDay);
```

**Yield Optimization Events:**
```solidity
event YieldStrategyRegistered(bytes32 indexed strategyId, string name, uint256 expectedAPY);
event DeployedToYieldStrategy(bytes32 indexed strategyId, uint256 amount, uint256 timestamp);
event WithdrawnFromYieldStrategy(bytes32 indexed strategyId, uint256 amount, uint256 yieldGenerated);
event YieldClaimed(address indexed user, uint256 amount, uint256 timestamp);
event AutoCompoundEnabled(uint256 indexed positionIndex, bool enabled);
```

**Partition Events:**
```solidity
event PartitionPoolCreated(bytes32 indexed partition, uint256 timestamp);
event PartitionDeposit(bytes32 indexed partition, address indexed user, uint256 assets, uint256 shares);
event PartitionYieldClaimed(bytes32 indexed partition, address indexed user, uint256 amount);
event YieldRoutingConfigured(uint8 indexed strategy, uint256 timestamp);
```

**Withdrawal Events:**
```solidity
event TieredRedemptionRequested(uint256 indexed redemptionId, WithdrawalTier tier, uint256 releaseTime);
event WithdrawalOptimized(uint256 shareAmount, address[] assets, uint256[] amounts);
event LiquidityReserveSet(uint256 targetPercentage, bool autoMaintain);
```

**Analytics Events:**
```solidity
event PerformanceSnapshotRecorded(uint256 timestamp, uint256 navPerShare, int256 dailyReturn);
event RiskMetricsCalculated(uint256 volatility, uint256 sharpeRatio, uint256 maxDrawdown);
```

---

## Testing Requirements

### Unit Tests (50+ cases)

**Rebalancing:**
- [ ] Allocation strategy creation and validation
- [ ] Rebalance to target allocation
- [ ] Tolerance-based triggering
- [ ] Multi-strategy support
- [ ] Risk profile rebalancing
- [ ] Time-weighted scheduling

**Yield Optimization:**
- [ ] Strategy registration and validation
- [ ] Deployment to yield strategy
- [ ] Yield claim and compounding
- [ ] Strategy comparison and switching
- [ ] APY calculation accuracy
- [ ] Multi-strategy deployment

**Partition Features:**
- [ ] Partition pool creation
- [ ] Partition-specific deposits
- [ ] Yield routing to partitions
- [ ] Allocation rule enforcement
- [ ] Cross-partition yield distribution
- [ ] Partition balance tracking

**Withdrawal Management:**
- [ ] Tiered redemption queues
- [ ] Tier-specific cooldowns
- [ ] Withdrawal optimization
- [ ] Liquidity reserve maintenance
- [ ] Emergency withdrawals

**Performance Tracking:**
- [ ] Performance snapshot recording
- [ ] Return calculations (daily/weekly/monthly/YTD)
- [ ] User P&L tracking
- [ ] Risk metrics calculation
- [ ] Report generation

**Multi-Asset:**
- [ ] Supported asset registration
- [ ] Cross-asset deposits
- [ ] Conversion rate updates
- [ ] Stablecoin arbitrage

### Integration Tests (20+ cases)

- [ ] End-to-end deposit → invest → yield → withdraw cycle
- [ ] SVPToken1400 partition integration
- [ ] SVPValuationEngine price feeds
- [ ] SVPGovernance voting with vault shares
- [ ] SVPDividendDistributor dividend routing
- [ ] Multi-asset cross-collateral scenarios
- [ ] Concurrent rebalancing and deposits
- [ ] Yield strategy switching under load

### Edge Cases

- [ ] Division by zero (zero shares, zero AUM)
- [ ] Rounding errors in allocation calculations
- [ ] Maximum allocation constraints
- [ ] Concurrent redemptions exceeding liquidity
- [ ] Failed strategy deployments with recovery
- [ ] Extreme price volatility scenarios
- [ ] Yield curve inversions

---

## Implementation Timeline

### Day 1: Foundation (8 hours)
- [ ] Extend SVPSPVVault contract structure
- [ ] Implement rebalancing strategies (functions 1-3)
- [ ] Add allocation strategy storage and setters
- [ ] Write rebalancing core logic

### Day 2: Yield & Partitions (8 hours)
- [ ] Implement yield strategy registry (40 lines)
- [ ] Add yield position tracking
- [ ] Implement partition pool system
- [ ] Add partition-aware deposit/withdrawal
- [ ] Implement yield routing

### Day 3: Withdrawal & Analytics (8 hours)
- [ ] Implement tiered withdrawal queues
- [ ] Add withdrawal optimization
- [ ] Create performance tracking system
- [ ] Add risk metrics calculation
- [ ] Implement multi-asset support
- [ ] Code review and refinement

### Quality Gates

- [ ] 95%+ test coverage
- [ ] Zero critical security issues
- [ ] All functions documented with NatSpec
- [ ] Gas optimization complete
- [ ] Integration tests passing
- [ ] Performance benchmarks acceptable

---

## Deliverables

✅ **Solidity Contracts:**
- Enhanced SVPSPVVault.sol (~1,200 lines)
- Supporting libraries (400+ lines)
- Interface definitions

✅ **Documentation:**
- PHASE4_DEPLOYMENT.md - Deployment procedures
- PHASE4_STRATEGIES.md - Strategy configurations
- VAULT_EXAMPLES.md - Usage examples
- Code comments and NatSpec

✅ **Tests:**
- 50+ unit tests
- 20+ integration tests
- Edge case coverage
- Gas benchmarks

✅ **Artifacts:**
- Contract ABI files
- Deployment transaction hashes (testnet)
- Performance reports

---

## Next Phase Dependencies

**Phase 5: Governance System** depends on:
- ✅ Phase 4 vault with yield tracking
- Voting power calculation integration with partition yields

**Phase 6: Dividend Distribution** depends on:
- ✅ Phase 4 yield routing to partitions
- Performance fee calculation from vault yields

**Phase 7: Frontend dApp** depends on:
- ✅ Phase 4 vault analytics and reporting endpoints
- Vault composition visualization data

---

## Success Criteria

✅ All 1,200 lines of enhanced vault code deployed to testnet  
✅ All 70+ tests passing with 95%+ coverage  
✅ Zero critical/high security findings  
✅ Gas optimization: <500K per rebalance  
✅ Performance analytics working end-to-end  
✅ Partition integration fully functional  
✅ Documentation comprehensive and verified  

---

**Ready to proceed with implementation?**

This Phase 4 will result in an institutional-grade vault system capable of sophisticated portfolio management, yield optimization, and partition-aware features. The enhanced vault becomes the capital pooling layer for the entire SVP Protocol.
