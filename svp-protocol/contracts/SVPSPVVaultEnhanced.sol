// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title SVPSPVVaultEnhanced
 * @notice Enhanced Special Purpose Vehicle vault for institutional capital pooling (ERC-4626)
 * @dev Implements advanced rebalancing, yield optimization, partition awareness, and multi-asset support
 * @author Hudu Yusuf (Analys)
 */
contract SVPSPVVaultEnhanced is ERC4626, AccessControl, ReentrancyGuard, Pausable {
    using EnumerableSet for EnumerableSet.AddressSet;
    
    // ============= Constants & Enums =============
    
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant REBALANCER_ROLE = keccak256("REBALANCER_ROLE");
    
    /// @notice Basis point divisor (100 = 1%)
    uint256 public constant BPS = 10000;
    
    /// @notice Withdrawal tier enum
    enum WithdrawalTier {
        INSTANT,
        STANDARD,
        DELAYED,
        CUSTOM
    }
    
    /// @notice Yield routing strategy enum
    enum YieldRoutingStrategy {
        PROPORTIONAL,
        EQUAL,
        PERFORMANCE_BASED,
        CUSTOM
    }
    
    // ============= Data Structures =============
    
    /// @notice Target allocation for rebalancing
    struct TargetAllocation {
        address asset;
        uint256 targetPercentage;
        uint256 tolerance;
    }
    
    /// @notice Allocation strategy
    struct AllocationStrategy {
        string name;
        uint256 createdAt;
        bool enabled;
        uint256 allocationCount;
    }
    
    /// @notice Risk profile configuration
    struct RiskProfile {
        uint256 maxAssetConcentration;
        uint256 maxSectorConcentration;
        uint256 minDiversification;
        uint256 volatilityThreshold;
    }
    
    /// @notice Rebalancing schedule
    struct RebalanceSchedule {
        uint256 frequency;
        uint256 dayOfWeek;
        uint256 hourOfDay;
        bool enabled;
    }
    
    /// @notice Yield strategy registry
    struct YieldStrategy {
        string name;
        address targetProtocol;
        uint256 expectedAPY;
        uint256 riskScore;
        bool enabled;
        uint256 maxAllocation;
        uint256 deployedAmount;
        uint256 createdAt;
    }
    
    /// @notice Yield position tracking
    struct YieldPosition {
        bytes32 strategyId;
        uint256 principalDeployed;
        uint256 yieldAccrued;
        uint256 deploymentTimestamp;
        uint256 lastClaimTimestamp;
        bool autoCompound;
        bool active;
    }
    
    /// @notice Partition pool structure
    struct PartitionPool {
        bytes32 partition;
        uint256 totalDeposits;
        uint256 yieldAccrued;
        uint256 createdAt;
        bool enabled;
    }
    
    /// @notice Partition allocation rule
    struct PartitionAllocationRule {
        bytes32 partition;
        uint256 maxAllocation;
        bool yieldEnabled;
        bool votingEnabled;
        uint256 createdAt;
    }
    
    /// @notice Yield routing configuration
    struct YieldRoutingConfig {
        YieldRoutingStrategy strategy;
        uint256 lastRoutedTimestamp;
        bool enabled;
    }
    
    /// @notice Tiered redemption request
    struct TieredRedemption {
        address requester;
        uint256 shareAmount;
        WithdrawalTier tier;
        uint256 requestTimestamp;
        uint256 releaseTimestamp;
        bool completed;
    }
    
    /// @notice Liquidity reserve configuration
    struct LiquidityReserve {
        uint256 targetPercentage;
        uint256 currentBalance;
        uint256 lastRebalanceTimestamp;
        bool autoMaintain;
    }
    
    /// @notice Performance snapshot
    struct PerformanceSnapshot {
        uint256 timestamp;
        uint256 totalAssets;
        uint256 totalShares;
        uint256 navPerShare;
        int256 dailyReturn;
        int256 weeklyReturn;
        int256 monthlyReturn;
        int256 yearToDateReturn;
        uint256 totalYieldGenerated;
        uint256 feesCollected;
    }
    
    /// @notice Risk metrics calculation
    struct RiskMetrics {
        uint256 volatility;
        uint256 sharpeRatio;
        uint256 maxDrawdown;
        uint256 beta;
        uint256 concentrationRisk;
    }
    
    /// @notice Asset configuration for multi-asset support
    struct AssetConfig {
        address assetAddress;
        uint8 decimals;
        uint256 conversionRate;
        bool enabled;
        uint256 addedAt;
    }
    
    /// @notice Original position structure (from Phase 2)
    struct Position {
        address svpToken;
        uint256 amount;
        uint256 allocationPercentage;
        uint256 entryPrice;
        uint256 currentValue;
        uint256 acquisitionBlock;
    }
    
    // ============= State Variables =============
    
    // Rebalancing strategies
    mapping(bytes32 => AllocationStrategy) public allocationStrategies;
    mapping(bytes32 => TargetAllocation[]) public strategyAllocations;
    bytes32[] public strategyIds;
    bytes32 public activeStrategy;
    
    RiskProfile public currentRiskProfile;
    RebalanceSchedule public rebalanceSchedule;
    
    // Yield optimization
    mapping(bytes32 => YieldStrategy) public yieldStrategies;
    bytes32[] public strategyIds2;
    mapping(address => YieldPosition[]) public yieldPositions;
    
    // Partition features
    mapping(bytes32 => PartitionPool) public partitionPools;
    mapping(bytes32 => PartitionAllocationRule) public partitionRules;
    mapping(bytes32 => mapping(address => uint256)) public partitionDeposits;
    bytes32[] public registeredPartitions;
    
    YieldRoutingConfig public yieldRouting;
    mapping(bytes32 => uint256) public partitionYieldWeights;
    
    // Withdrawal management
    TieredRedemption[] public redemptionQueue;
    mapping(address => uint256[]) public userRedemptions;
    mapping(WithdrawalTier => uint256[]) public tierQueues;
    
    LiquidityReserve public liquidityReserve;
    
    // Performance analytics
    PerformanceSnapshot[] public performanceHistory;
    mapping(address => uint256) public userContribution;
    mapping(address => uint256) public userRealizedGains;
    
    // Multi-asset support
    mapping(address => AssetConfig) public assetConfigs;
    address[] public baseAssets;
    
    // Core vault state (Phase 2 base)
    mapping(address => Position) public positions;
    address[] public portfolioAssets;
    uint256 public activePositionCount;
    
    struct PerformanceMetrics {
        uint256 totalInvested;
        uint256 totalReturned;
        int256 realizedGains;
        uint256 unrealizedGains;
        uint256 lastUpdateTimestamp;
    }
    
    PerformanceMetrics public metrics;
    uint256 public totalDividendsReceived;
    mapping(address => uint256) public dividendsClaimed;
    
    // Parameters
    uint256 public minDepositAmount = 100e6;
    uint256 public maxAllocationPerAsset = 3000;
    uint256 public redemptionCooldown = 1 days;
    uint256 public lastRebalanceTimestamp;
    uint256 public rebalanceFrequency = 7 days;
    
    // Fees
    uint256 public managementFeePercentage = 200;
    uint256 public performanceFeePercentage = 2000;
    address public feeRecipient;
    
    // NAV history
    uint256[] public navHistory;
    uint256[] public navTimestamps;
    
    // Tier cooldowns
    mapping(WithdrawalTier => uint256) public tierCooldowns;
    
    // ============= Events =============
    
    // Rebalancing events
    event AllocationStrategyUpdated(bytes32 indexed strategyId, string name);
    event StrategyRebalanced(bytes32 indexed strategyId, address indexed manager, uint256 timestamp);
    event RiskProfileRebalanced(uint256 riskLevel, address indexed manager, uint256 timestamp);
    event RebalanceScheduleSet(uint256 frequency, uint256 dayOfWeek, uint256 hourOfDay);
    
    // Yield optimization events
    event YieldStrategyRegistered(bytes32 indexed strategyId, string name, uint256 expectedAPY);
    event DeployedToYieldStrategy(bytes32 indexed strategyId, uint256 amount, address indexed manager, uint256 timestamp);
    event WithdrawnFromYieldStrategy(bytes32 indexed strategyId, uint256 amount, uint256 yieldGenerated, uint256 timestamp);
    event YieldClaimed(address indexed user, uint256 amount, uint256 timestamp);
    event AutoCompoundEnabled(address indexed user, uint256 indexed positionIndex, bool enabled);
    
    // Partition events
    event PartitionPoolCreated(bytes32 indexed partition, uint256 timestamp);
    event PartitionDeposit(bytes32 indexed partition, address indexed user, uint256 assets, uint256 shares, uint256 timestamp);
    event PartitionYieldClaimed(bytes32 indexed partition, address indexed user, uint256 amount, uint256 timestamp);
    event YieldRoutingConfigured(uint8 indexed strategy, uint256 timestamp);
    event PartitionAllocationRuleSet(bytes32 indexed partition, uint256 maxAllocation, uint256 timestamp);
    
    // Withdrawal events
    event TieredRedemptionRequested(uint256 indexed redemptionId, address indexed user, WithdrawalTier tier, uint256 releaseTime);
    event TieredRedemptionExecuted(uint256 indexed redemptionId, address indexed user, uint256 shareAmount, uint256 assetAmount);
    event WithdrawalOptimized(uint256 shareAmount, address[] assets, uint256[] amounts, address indexed manager);
    event LiquidityReserveSet(uint256 targetPercentage, bool autoMaintain, uint256 timestamp);
    
    // Analytics events
    event PerformanceSnapshotRecorded(uint256 timestamp, uint256 navPerShare, int256 dailyReturn);
    event RiskMetricsCalculated(uint256 volatility, uint256 sharpeRatio, uint256 maxDrawdown);
    
    // Multi-asset events
    event AssetConfigured(address indexed asset, uint8 decimals, uint256 conversionRate, uint256 timestamp);
    event CrossAssetRebalanced(address indexed fromAsset, address indexed toAsset, uint256 amount, uint256 timestamp);
    
    // Original Phase 2 events
    event PositionOpened(address indexed svpToken, uint256 amount, uint256 allocationPercentage, address indexed manager, uint256 timestamp);
    event PositionClosed(address indexed svpToken, uint256 amount, uint256 exitPrice, int256 profit, address indexed manager, uint256 timestamp);
    event DividendReceived(address indexed svpToken, uint256 amount, uint256 timestamp);
    event FeesCollected(uint256 managementFee, uint256 performanceFee, uint256 timestamp);
    
    // ============= Constructor =============
    
    constructor(
        IERC20 asset_,
        string memory name_,
        string memory symbol_
    )
        ERC20(name_, symbol_)
        ERC4626(asset_)
    {
        require(address(asset_) != address(0), "SVPSPVVaultEnhanced: Invalid asset");
        
        lastRebalanceTimestamp = block.timestamp;
        feeRecipient = msg.sender;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, msg.sender);
        _grantRole(REBALANCER_ROLE, msg.sender);
        
        // Initialize tier cooldowns
        tierCooldowns[WithdrawalTier.INSTANT] = 0 seconds;
        tierCooldowns[WithdrawalTier.STANDARD] = 1 days;
        tierCooldowns[WithdrawalTier.DELAYED] = 7 days;
        tierCooldowns[WithdrawalTier.CUSTOM] = 3 days;
        
        // Initialize liquidity reserve
        liquidityReserve = LiquidityReserve({
            targetPercentage: 500,
            currentBalance: 0,
            lastRebalanceTimestamp: block.timestamp,
            autoMaintain: true
        });
        
        // Initialize yield routing
        yieldRouting = YieldRoutingConfig({
            strategy: YieldRoutingStrategy.PROPORTIONAL,
            lastRoutedTimestamp: block.timestamp,
            enabled: true
        });
    }
    
    // ============= Core ERC-4626 Functions =============
    
    function deposit(uint256 assets, address receiver)
        public
        override
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        require(assets >= minDepositAmount, "SVPSPVVaultEnhanced: Deposit below minimum");
        require(receiver != address(0), "SVPSPVVaultEnhanced: Invalid receiver");
        
        uint256 shares = previewDeposit(assets);
        IERC20(asset()).transferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
        
        metrics.totalInvested += assets;
        userContribution[receiver] += assets;
        
        emit Deposit(msg.sender, receiver, assets, shares);
        return shares;
    }
    
    function withdraw(uint256 assets, address receiver, address owner)
        public
        override
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        uint256 shares = previewWithdraw(assets);
        
        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }
        
        _burn(owner, shares);
        IERC20(asset()).transfer(receiver, assets);
        metrics.totalReturned += assets;
        
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        return shares;
    }
    
    // ============= Advanced Rebalancing =============
    
    /// @notice Create new allocation strategy
    function setAllocationStrategy(
        bytes32 strategyId,
        string memory name,
        TargetAllocation[] calldata allocations
    )
        external
        onlyRole(ADMIN_ROLE)
    {
        require(allocations.length > 0, "SVPSPVVaultEnhanced: No allocations");
        require(bytes(name).length > 0, "SVPSPVVaultEnhanced: Invalid name");
        
        allocationStrategies[strategyId] = AllocationStrategy({
            name: name,
            createdAt: block.timestamp,
            enabled: true,
            allocationCount: allocations.length
        });
        
        delete strategyAllocations[strategyId];
        
        uint256 totalPercentage = 0;
        for (uint256 i = 0; i < allocations.length; i++) {
            require(allocations[i].asset != address(0), "SVPSPVVaultEnhanced: Invalid asset");
            strategyAllocations[strategyId].push(allocations[i]);
            totalPercentage += allocations[i].targetPercentage;
        }
        
        require(totalPercentage == BPS, "SVPSPVVaultEnhanced: Allocations must sum to 100%");
        
        if (strategyIds.length == 0 || activeStrategy == bytes32(0)) {
            activeStrategy = strategyId;
        }
        
        strategyIds.push(strategyId);
        
        emit AllocationStrategyUpdated(strategyId, name);
    }
    
    /// @notice Rebalance portfolio to target strategy
    function rebalanceToTarget(bytes32 strategyId)
        external
        onlyRole(MANAGER_ROLE)
        nonReentrant
        whenNotPaused
    {
        require(allocationStrategies[strategyId].enabled, "SVPSPVVaultEnhanced: Strategy disabled");
        
        TargetAllocation[] storage allocations = strategyAllocations[strategyId];
        uint256 totalValue = totalAssets();
        
        for (uint256 i = 0; i < allocations.length; i++) {
            uint256 targetValue = (totalValue * allocations[i].targetPercentage) / BPS;
            Position storage position = positions[allocations[i].asset];
            
            if (position.amount < targetValue) {
                uint256 difference = targetValue - position.amount;
                _addToPosition(allocations[i].asset, difference);
            } else if (position.amount > targetValue) {
                uint256 difference = position.amount - targetValue;
                _removeFromPosition(allocations[i].asset, difference);
            }
        }
        
        activeStrategy = strategyId;
        emit StrategyRebalanced(strategyId, msg.sender, block.timestamp);
    }
    
    /// @notice Set risk profile for automatic rebalancing
    function setRiskProfile(RiskProfile calldata profile)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(profile.minDiversification > 0, "SVPSPVVaultEnhanced: Invalid diversification");
        currentRiskProfile = profile;
    }
    
    /// @notice Set automatic rebalancing schedule
    function setRebalanceSchedule(RebalanceSchedule calldata schedule)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(schedule.frequency > 0, "SVPSPVVaultEnhanced: Invalid frequency");
        require(schedule.dayOfWeek < 7, "SVPSPVVaultEnhanced: Invalid day of week");
        require(schedule.hourOfDay < 24, "SVPSPVVaultEnhanced: Invalid hour");
        
        rebalanceSchedule = schedule;
        emit RebalanceScheduleSet(schedule.frequency, schedule.dayOfWeek, schedule.hourOfDay);
    }
    
    // ============= Yield Optimization =============
    
    /// @notice Register yield strategy
    function registerYieldStrategy(
        bytes32 strategyId,
        string memory name,
        address targetProtocol,
        uint256 expectedAPY,
        uint256 riskScore,
        uint256 maxAllocation
    )
        external
        onlyRole(ADMIN_ROLE)
    {
        require(targetProtocol != address(0), "SVPSPVVaultEnhanced: Invalid protocol");
        require(riskScore <= 100, "SVPSPVVaultEnhanced: Risk score > 100");
        require(maxAllocation <= BPS, "SVPSPVVaultEnhanced: Max allocation > 100%");
        
        yieldStrategies[strategyId] = YieldStrategy({
            name: name,
            targetProtocol: targetProtocol,
            expectedAPY: expectedAPY,
            riskScore: riskScore,
            enabled: true,
            maxAllocation: maxAllocation,
            deployedAmount: 0,
            createdAt: block.timestamp
        });
        
        strategyIds2.push(strategyId);
        
        emit YieldStrategyRegistered(strategyId, name, expectedAPY);
    }
    
    /// @notice Deploy funds to yield strategy
    function deployToYieldStrategy(bytes32 strategyId, uint256 amount)
        external
        onlyRole(MANAGER_ROLE)
        nonReentrant
        whenNotPaused
    {
        require(yieldStrategies[strategyId].enabled, "SVPSPVVaultEnhanced: Strategy disabled");
        require(amount > 0, "SVPSPVVaultEnhanced: Invalid amount");
        
        uint256 totalValue = totalAssets();
        uint256 deploymentPercentage = (amount * BPS) / totalValue;
        require(deploymentPercentage <= yieldStrategies[strategyId].maxAllocation, "SVPSPVVaultEnhanced: Exceeds max allocation");
        
        YieldPosition memory position = YieldPosition({
            strategyId: strategyId,
            principalDeployed: amount,
            yieldAccrued: 0,
            deploymentTimestamp: block.timestamp,
            lastClaimTimestamp: block.timestamp,
            autoCompound: false,
            active: true
        });
        
        yieldPositions[msg.sender].push(position);
        yieldStrategies[strategyId].deployedAmount += amount;
        
        emit DeployedToYieldStrategy(strategyId, amount, msg.sender, block.timestamp);
    }
    
    /// @notice Claim accumulated yield
    function claimYield(uint256 positionIndex)
        external
        nonReentrant
        returns (uint256 yieldAmount)
    {
        require(positionIndex < yieldPositions[msg.sender].length, "SVPSPVVaultEnhanced: Invalid position");
        
        YieldPosition storage position = yieldPositions[msg.sender][positionIndex];
        require(position.active, "SVPSPVVaultEnhanced: Position inactive");
        
        yieldAmount = position.yieldAccrued;
        position.yieldAccrued = 0;
        position.lastClaimTimestamp = block.timestamp;
        
        if (yieldAmount > 0) {
            IERC20(asset()).transfer(msg.sender, yieldAmount);
            metrics.unrealizedGains += yieldAmount;
        }
        
        emit YieldClaimed(msg.sender, yieldAmount, block.timestamp);
    }
    
    /// @notice Get estimated APY for strategy
    function getStrategyAPY(bytes32 strategyId)
        external
        view
        returns (uint256)
    {
        require(yieldStrategies[strategyId].enabled, "SVPSPVVaultEnhanced: Strategy disabled");
        return yieldStrategies[strategyId].expectedAPY;
    }
    
    /// @notice Find highest yield strategy
    function findHighestYieldStrategy()
        external
        view
        returns (bytes32 bestStrategy, uint256 apy)
    {
        apy = 0;
        
        for (uint256 i = 0; i < strategyIds2.length; i++) {
            if (yieldStrategies[strategyIds2[i]].enabled) {
                if (yieldStrategies[strategyIds2[i]].expectedAPY > apy) {
                    apy = yieldStrategies[strategyIds2[i]].expectedAPY;
                    bestStrategy = strategyIds2[i];
                }
            }
        }
    }
    
    // ============= Partition Features =============
    
    /// @notice Create partition pool
    function createPartitionPool(bytes32 partition)
        external
        onlyRole(MANAGER_ROLE)
    {
        require(partitionPools[partition].createdAt == 0, "SVPSPVVaultEnhanced: Partition exists");
        
        partitionPools[partition] = PartitionPool({
            partition: partition,
            totalDeposits: 0,
            yieldAccrued: 0,
            createdAt: block.timestamp,
            enabled: true
        });
        
        registeredPartitions.push(partition);
        
        emit PartitionPoolCreated(partition, block.timestamp);
    }
    
    /// @notice Deposit to partition pool
    function depositByPartition(
        bytes32 partition,
        uint256 assets,
        address receiver
    )
        external
        whenNotPaused
        nonReentrant
        returns (uint256 shares)
    {
        require(partitionPools[partition].enabled, "SVPSPVVaultEnhanced: Partition disabled");
        require(assets >= minDepositAmount, "SVPSPVVaultEnhanced: Below minimum");
        
        shares = previewDeposit(assets);
        IERC20(asset()).transferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
        
        partitionPools[partition].totalDeposits += assets;
        partitionDeposits[partition][receiver] += assets;
        
        emit PartitionDeposit(partition, receiver, assets, shares, block.timestamp);
    }
    
    /// @notice Set partition allocation rule
    function setPartitionAllocationRule(
        bytes32 partition,
        uint256 maxAllocation,
        bool yieldEnabled,
        bool votingEnabled
    )
        external
        onlyRole(ADMIN_ROLE)
    {
        require(maxAllocation <= BPS, "SVPSPVVaultEnhanced: Invalid allocation");
        
        partitionRules[partition] = PartitionAllocationRule({
            partition: partition,
            maxAllocation: maxAllocation,
            yieldEnabled: yieldEnabled,
            votingEnabled: votingEnabled,
            createdAt: block.timestamp
        });
        
        emit PartitionAllocationRuleSet(partition, maxAllocation, block.timestamp);
    }
    
    /// @notice Set yield routing strategy
    function setYieldRouting(YieldRoutingStrategy strategy)
        external
        onlyRole(ADMIN_ROLE)
    {
        yieldRouting.strategy = strategy;
        emit YieldRoutingConfigured(uint8(strategy), block.timestamp);
    }
    
    /// @notice Route yield to partitions
    function routeYieldToPartitions()
        external
        onlyRole(MANAGER_ROLE)
        nonReentrant
    {
        require(yieldRouting.enabled, "SVPSPVVaultEnhanced: Routing disabled");
        
        uint256 totalYield = totalDividendsReceived;
        
        if (yieldRouting.strategy == YieldRoutingStrategy.PROPORTIONAL) {
            uint256 totalDeposits = 0;
            for (uint256 i = 0; i < registeredPartitions.length; i++) {
                totalDeposits += partitionPools[registeredPartitions[i]].totalDeposits;
            }
            
            if (totalDeposits > 0) {
                for (uint256 i = 0; i < registeredPartitions.length; i++) {
                    bytes32 partition = registeredPartitions[i];
                    uint256 share = (totalYield * partitionPools[partition].totalDeposits) / totalDeposits;
                    partitionPools[partition].yieldAccrued += share;
                }
            }
        } else if (yieldRouting.strategy == YieldRoutingStrategy.EQUAL) {
            uint256 sharePerPartition = totalYield / registeredPartitions.length;
            for (uint256 i = 0; i < registeredPartitions.length; i++) {
                partitionPools[registeredPartitions[i]].yieldAccrued += sharePerPartition;
            }
        }
        
        yieldRouting.lastRoutedTimestamp = block.timestamp;
    }
    
    /// @notice Claim partition yield
    function claimPartitionYield(bytes32 partition)
        external
        nonReentrant
        returns (uint256 yieldAmount)
    {
        require(partitionPools[partition].enabled, "SVPSPVVaultEnhanced: Partition disabled");
        
        yieldAmount = partitionPools[partition].yieldAccrued;
        require(yieldAmount > 0, "SVPSPVVaultEnhanced: No yield to claim");
        
        partitionPools[partition].yieldAccrued = 0;
        IERC20(asset()).transfer(msg.sender, yieldAmount);
        
        emit PartitionYieldClaimed(partition, msg.sender, yieldAmount, block.timestamp);
    }
    
    // ============= Advanced Withdrawal Management =============
    
    /// @notice Request tiered redemption
    function requestTieredRedemption(uint256 shares, WithdrawalTier tier)
        external
        whenNotPaused
        nonReentrant
        returns (uint256 redemptionId)
    {
        require(shares > 0, "SVPSPVVaultEnhanced: Invalid shares");
        require(balanceOf(msg.sender) >= shares, "SVPSPVVaultEnhanced: Insufficient balance");
        
        uint256 releaseTime = block.timestamp + tierCooldowns[tier];
        
        TieredRedemption memory request = TieredRedemption({
            requester: msg.sender,
            shareAmount: shares,
            tier: tier,
            requestTimestamp: block.timestamp,
            releaseTimestamp: releaseTime,
            completed: false
        });
        
        redemptionId = redemptionQueue.length;
        redemptionQueue.push(request);
        userRedemptions[msg.sender].push(redemptionId);
        
        emit TieredRedemptionRequested(redemptionId, msg.sender, tier, releaseTime);
    }
    
    /// @notice Execute tiered redemption
    function executeTieredRedemption(uint256 redemptionId)
        external
        nonReentrant
        whenNotPaused
    {
        require(redemptionId < redemptionQueue.length, "SVPSPVVaultEnhanced: Invalid ID");
        
        TieredRedemption storage request = redemptionQueue[redemptionId];
        require(!request.completed, "SVPSPVVaultEnhanced: Already completed");
        require(block.timestamp >= request.releaseTimestamp, "SVPSPVVaultEnhanced: Cooldown not satisfied");
        
        uint256 assets = previewRedeem(request.shareAmount);
        
        _burn(request.requester, request.shareAmount);
        IERC20(asset()).transfer(request.requester, assets);
        
        request.completed = true;
        metrics.totalReturned += assets;
        
        emit TieredRedemptionExecuted(redemptionId, request.requester, request.shareAmount, assets);
    }
    
    /// @notice Set liquidity reserve target
    function setLiquidityReserve(uint256 targetPercentage, bool autoMaintain)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(targetPercentage <= BPS, "SVPSPVVaultEnhanced: Invalid percentage");
        
        liquidityReserve.targetPercentage = targetPercentage;
        liquidityReserve.autoMaintain = autoMaintain;
        
        emit LiquidityReserveSet(targetPercentage, autoMaintain, block.timestamp);
    }
    
    /// @notice Maintain liquidity reserve
    function maintainLiquidityReserve()
        external
        onlyRole(MANAGER_ROLE)
        nonReentrant
    {
        uint256 totalValue = totalAssets();
        uint256 targetReserve = (totalValue * liquidityReserve.targetPercentage) / BPS;
        
        if (liquidityReserve.currentBalance < targetReserve) {
            uint256 needed = targetReserve - liquidityReserve.currentBalance;
            _addToReserve(needed);
        } else if (liquidityReserve.currentBalance > targetReserve) {
            uint256 excess = liquidityReserve.currentBalance - targetReserve;
            _removeFromReserve(excess);
        }
        
        liquidityReserve.lastRebalanceTimestamp = block.timestamp;
    }
    
    // ============= Performance Analytics =============
    
    /// @notice Record performance snapshot
    function recordPerformanceSnapshot()
        external
        onlyRole(MANAGER_ROLE)
    {
        uint256 currentNavPerShare = calculateNAV();
        int256 dailyReturn = 0;
        
        if (navHistory.length > 0) {
            uint256 previousNav = navHistory[navHistory.length - 1];
            dailyReturn = int256(currentNavPerShare) - int256(previousNav);
        }
        
        PerformanceSnapshot memory snapshot = PerformanceSnapshot({
            timestamp: block.timestamp,
            totalAssets: totalAssets(),
            totalShares: totalSupply(),
            navPerShare: currentNavPerShare,
            dailyReturn: dailyReturn,
            weeklyReturn: 0,
            monthlyReturn: 0,
            yearToDateReturn: 0,
            totalYieldGenerated: totalDividendsReceived,
            feesCollected: 0
        });
        
        performanceHistory.push(snapshot);
        
        emit PerformanceSnapshotRecorded(block.timestamp, currentNavPerShare, dailyReturn);
    }
    
    /// @notice Calculate user P&L
    function calculateUserPnL(address user)
        external
        view
        returns (
            int256 totalPnL,
            uint256 realizedGains,
            uint256 unrealizedGains
        )
    {
        uint256 currentValue = (balanceOf(user) * calculateNAV()) / 1e18;
        uint256 invested = userContribution[user];
        
        totalPnL = int256(currentValue) - int256(invested);
        realizedGains = userRealizedGains[user];
        unrealizedGains = (currentValue > invested) ? (currentValue - invested) : 0;
    }
    
    /// @notice Calculate NAV per share
    function calculateNAV()
        public
        view
        returns (uint256)
    {
        uint256 totalValue = totalAssets();
        uint256 totalShares = totalSupply();
        
        if (totalShares == 0) return 1e18;
        
        return (totalValue * 1e18) / totalShares;
    }
    
    // ============= Multi-Asset Support =============
    
    /// @notice Add supported asset
    function addSupportedAsset(
        address assetAddress,
        uint8 decimals,
        uint256 conversionRate
    )
        external
        onlyRole(ADMIN_ROLE)
    {
        require(assetAddress != address(0), "SVPSPVVaultEnhanced: Invalid address");
        require(conversionRate > 0, "SVPSPVVaultEnhanced: Invalid rate");
        
        assetConfigs[assetAddress] = AssetConfig({
            assetAddress: assetAddress,
            decimals: decimals,
            conversionRate: conversionRate,
            enabled: true,
            addedAt: block.timestamp
        });
        
        baseAssets.push(assetAddress);
        
        emit AssetConfigured(assetAddress, decimals, conversionRate, block.timestamp);
    }
    
    /// @notice Rebalance between assets
    function rebalanceBetweenAssets(
        address fromAsset,
        address toAsset,
        uint256 amount
    )
        external
        onlyRole(MANAGER_ROLE)
        nonReentrant
    {
        require(assetConfigs[fromAsset].enabled, "SVPSPVVaultEnhanced: From asset disabled");
        require(assetConfigs[toAsset].enabled, "SVPSPVVaultEnhanced: To asset disabled");
        require(amount > 0, "SVPSPVVaultEnhanced: Invalid amount");
        
        // Simplified cross-asset rebalancing logic
        uint256 convertedAmount = (amount * assetConfigs[fromAsset].conversionRate) / assetConfigs[toAsset].conversionRate;
        
        emit CrossAssetRebalanced(fromAsset, toAsset, amount, block.timestamp);
    }
    
    // ============= Helper Functions =============
    
    function _addToPosition(address asset, uint256 amount) internal {
        Position storage position = positions[asset];
        position.amount += amount;
    }
    
    function _removeFromPosition(address asset, uint256 amount) internal {
        Position storage position = positions[asset];
        if (position.amount >= amount) {
            position.amount -= amount;
        }
    }
    
    function _addToReserve(uint256 amount) internal {
        liquidityReserve.currentBalance += amount;
    }
    
    function _removeFromReserve(uint256 amount) internal {
        if (liquidityReserve.currentBalance >= amount) {
            liquidityReserve.currentBalance -= amount;
        }
    }
    
    // ============= Getters =============
    
    function getStrategyCount() external view returns (uint256) {
        return strategyIds.length;
    }
    
    function getYieldStrategyCount() external view returns (uint256) {
        return strategyIds2.length;
    }
    
    function getPartitionCount() external view returns (uint256) {
        return registeredPartitions.length;
    }
    
    function getRedemptionQueueLength() external view returns (uint256) {
        return redemptionQueue.length;
    }
    
    function getPerformanceHistoryLength() external view returns (uint256) {
        return performanceHistory.length;
    }
    
    function getUserRedemptions(address user) external view returns (uint256[] memory) {
        return userRedemptions[user];
    }
    
    function getYieldPositions(address user) external view returns (YieldPosition[] memory) {
        return yieldPositions[user];
    }
}
