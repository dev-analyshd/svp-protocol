// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title PerformanceYieldCalculator
 * @notice Calculates performance-based yield for vault investors
 * @dev Tracks performance metrics and calculates yield bonuses
 * @author Hudu Yusuf (Analys)
 */
contract PerformanceYieldCalculator is AccessControl, ReentrancyGuard {
    // ============= Constants & Roles =============
    
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant CALCULATOR_ROLE = keccak256("CALCULATOR_ROLE");
    
    uint256 public constant BASIS_POINTS = 10000;  // 100% = 10000 BPS
    
    // ============= Data Structures =============
    
    struct PerformanceMetrics {
        uint256 startValue;
        uint256 currentValue;
        uint256 totalReturn;
        uint256 yieldPercentage;
        uint256 startBlock;
        uint256 lastUpdateBlock;
        uint256 updateTimestamp;
        bool isOutperformer;
    }
    
    struct YieldBonus {
        uint256 baseYield;
        uint256 performanceBonus;
        uint256 totalYield;
        uint256 multiplier;  // In BPS (e.g., 11000 = 1.1x)
        uint256 timestamp;
        bool claimed;
    }
    
    struct HolderPerformance {
        uint256 totalYield;
        uint256 totalBonus;
        uint256 claimedYield;
        uint256 performanceScore;
        uint256 outperformanceDays;
        uint256 lastCalculationBlock;
    }
    
    struct BenchmarkData {
        uint256 benchmarkReturn;
        uint256 vaultReturn;
        uint256 outperformanceGap;
        uint256 timestamp;
    }
    
    // ============= State Variables =============
    
    mapping(address => HolderPerformance) public holderPerformance;
    mapping(address => PerformanceMetrics) public metrics;
    mapping(address => YieldBonus[]) public yieldBonuses;
    mapping(uint256 => BenchmarkData) public benchmarkHistory;  // periodId => data
    
    uint256 public benchmarkReturn;  // Market benchmark return in BPS
    uint256 public performanceBonusRate;  // Bonus multiplier for outperformance in BPS
    uint256 public currentPeriodId;
    uint256 public targetYieldBPS;  // Target yield in basis points
    
    address public vaultAddress;
    uint256 public minOutperformanceGap;  // Minimum gap to trigger bonus (in BPS)
    
    // ============= Events =============
    
    event PerformanceMetricsUpdated(
        address indexed holder,
        uint256 startValue,
        uint256 currentValue,
        uint256 yieldPercentage,
        bool isOutperformer,
        uint256 timestamp
    );
    
    event YieldBonusCalculated(
        address indexed holder,
        uint256 baseYield,
        uint256 bonus,
        uint256 multiplier,
        uint256 timestamp
    );
    
    event BenchmarkUpdated(
        uint256 indexed periodId,
        uint256 benchmarkReturn,
        uint256 vaultReturn,
        uint256 outperformanceGap,
        uint256 timestamp
    );
    
    event PerformanceScoreUpdated(
        address indexed holder,
        uint256 newScore,
        uint256 outperformanceDays,
        uint256 timestamp
    );
    
    event TargetYieldUpdated(
        uint256 oldTarget,
        uint256 newTarget,
        uint256 timestamp
    );
    
    event BonusRateUpdated(
        uint256 oldRate,
        uint256 newRate,
        uint256 timestamp
    );
    
    // ============= Constructor =============
    
    constructor(address _vaultAddress) {
        require(_vaultAddress != address(0), "PerformanceYieldCalculator: Invalid vault");
        
        vaultAddress = _vaultAddress;
        performanceBonusRate = 15000;  // 1.5x multiplier for outperformance
        targetYieldBPS = 800;  // 8% target yield
        minOutperformanceGap = 100;  // 1% minimum outperformance gap
        currentPeriodId = 1;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE, msg.sender);
        _grantRole(CALCULATOR_ROLE, msg.sender);
    }
    
    // ============= Performance Calculation =============
    
    /// @notice Calculate holder performance metrics
    function calculatePerformanceMetrics(
        address holder,
        uint256 startValue,
        uint256 currentValue
    ) external onlyRole(CALCULATOR_ROLE) {
        require(holder != address(0), "PerformanceYieldCalculator: Invalid holder");
        require(startValue > 0, "PerformanceYieldCalculator: Invalid start value");
        require(currentValue > 0, "PerformanceYieldCalculator: Invalid current value");
        
        uint256 totalReturn = currentValue > startValue ? currentValue - startValue : 0;
        uint256 yieldPercentage = (totalReturn * BASIS_POINTS) / startValue;
        bool isOutperformer = yieldPercentage > targetYieldBPS;
        
        metrics[holder] = PerformanceMetrics({
            startValue: startValue,
            currentValue: currentValue,
            totalReturn: totalReturn,
            yieldPercentage: yieldPercentage,
            startBlock: block.number,
            lastUpdateBlock: block.number,
            updateTimestamp: block.timestamp,
            isOutperformer: isOutperformer
        });
        
        // Update holder performance
        HolderPerformance storage hp = holderPerformance[holder];
        hp.totalYield += totalReturn;
        if (isOutperformer) {
            hp.outperformanceDays++;
        }
        hp.lastCalculationBlock = block.number;
        
        // Update performance score
        hp.performanceScore = calculatePerformanceScore(holder);
        
        emit PerformanceMetricsUpdated(
            holder,
            startValue,
            currentValue,
            yieldPercentage,
            isOutperformer,
            block.timestamp
        );
    }
    
    /// @notice Calculate yield bonus for outperformance
    function calculateYieldBonus(address holder)
        external
        onlyRole(CALCULATOR_ROLE)
        returns (uint256 bonusAmount)
    {
        require(holder != address(0), "PerformanceYieldCalculator: Invalid holder");
        
        PerformanceMetrics storage pm = metrics[holder];
        require(pm.startValue > 0, "PerformanceYieldCalculator: No metrics");
        
        uint256 baseYield = pm.totalReturn;
        uint256 multiplier = BASIS_POINTS;  // 1.0x by default
        uint256 bonus = 0;
        
        if (pm.isOutperformer) {
            uint256 outperformanceAmount = pm.totalReturn - (pm.startValue * targetYieldBPS / BASIS_POINTS);
            if (outperformanceAmount > 0) {
                bonus = (outperformanceAmount * (performanceBonusRate - BASIS_POINTS)) / BASIS_POINTS;
                multiplier = performanceBonusRate;
            }
        }
        
        uint256 totalYield = baseYield + bonus;
        
        YieldBonus memory yb = YieldBonus({
            baseYield: baseYield,
            performanceBonus: bonus,
            totalYield: totalYield,
            multiplier: multiplier,
            timestamp: block.timestamp,
            claimed: false
        });
        
        yieldBonuses[holder].push(yb);
        
        HolderPerformance storage hp = holderPerformance[holder];
        hp.totalBonus += bonus;
        
        bonusAmount = bonus;
        
        emit YieldBonusCalculated(holder, baseYield, bonus, multiplier, block.timestamp);
        return bonusAmount;
    }
    
    /// @notice Calculate performance score (0-100)
    function calculatePerformanceScore(address holder) public view returns (uint256) {
        PerformanceMetrics memory pm = metrics[holder];
        if (pm.startValue == 0) return 0;
        
        // Score based on yield percentage vs target
        uint256 score;
        if (pm.yieldPercentage >= targetYieldBPS * 2) {
            score = 100;  // Excellent
        } else if (pm.yieldPercentage >= targetYieldBPS) {
            score = 80 + (pm.yieldPercentage - targetYieldBPS) / 50;
        } else if (pm.yieldPercentage >= targetYieldBPS / 2) {
            score = 50 + (pm.yieldPercentage / 50);
        } else {
            score = (pm.yieldPercentage * 50) / targetYieldBPS;
        }
        
        return score > 100 ? 100 : score;
    }
    
    // ============= Benchmark Management =============
    
    /// @notice Update benchmark data for period
    function updateBenchmark(
        uint256 benchmarkReturnBPS,
        uint256 vaultReturnBPS
    ) external onlyRole(ORACLE_ROLE) {
        require(benchmarkReturnBPS < BASIS_POINTS * 10, "PerformanceYieldCalculator: Invalid benchmark");
        require(vaultReturnBPS < BASIS_POINTS * 10, "PerformanceYieldCalculator: Invalid vault return");
        
        uint256 outperformanceGap = vaultReturnBPS > benchmarkReturnBPS 
            ? vaultReturnBPS - benchmarkReturnBPS 
            : 0;
        
        benchmarkReturn = benchmarkReturnBPS;
        
        benchmarkHistory[currentPeriodId] = BenchmarkData({
            benchmarkReturn: benchmarkReturnBPS,
            vaultReturn: vaultReturnBPS,
            outperformanceGap: outperformanceGap,
            timestamp: block.timestamp
        });
        
        emit BenchmarkUpdated(
            currentPeriodId,
            benchmarkReturnBPS,
            vaultReturnBPS,
            outperformanceGap,
            block.timestamp
        );
        
        currentPeriodId++;
    }
    
    /// @notice Get benchmark data for period
    function getBenchmarkData(uint256 periodId) 
        external 
        view 
        returns (BenchmarkData memory) 
    {
        return benchmarkHistory[periodId];
    }
    
    // ============= Yield Bonus Claims =============
    
    /// @notice Get unclaimed yield bonuses for holder
    function getUnclaimedBonuses(address holder) 
        external 
        view 
        returns (YieldBonus[] memory) 
    {
        YieldBonus[] storage bonuses = yieldBonuses[holder];
        uint256 count = 0;
        
        for (uint256 i = 0; i < bonuses.length; i++) {
            if (!bonuses[i].claimed) {
                count++;
            }
        }
        
        YieldBonus[] memory unclaimed = new YieldBonus[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < bonuses.length; i++) {
            if (!bonuses[i].claimed) {
                unclaimed[index] = bonuses[i];
                index++;
            }
        }
        
        return unclaimed;
    }
    
    /// @notice Get total unclaimed bonus amount
    function getTotalUnclaimedBonus(address holder) public view returns (uint256) {
        YieldBonus[] storage bonuses = yieldBonuses[holder];
        uint256 total = 0;
        
        for (uint256 i = 0; i < bonuses.length; i++) {
            if (!bonuses[i].claimed) {
                total += bonuses[i].totalYield;
            }
        }
        
        return total;
    }
    
    /// @notice Mark bonuses as claimed
    function markBonusesClaimed(address holder) 
        external 
        onlyRole(CALCULATOR_ROLE) 
    {
        YieldBonus[] storage bonuses = yieldBonuses[holder];
        
        for (uint256 i = 0; i < bonuses.length; i++) {
            if (!bonuses[i].claimed) {
                bonuses[i].claimed = true;
                holderPerformance[holder].claimedYield += bonuses[i].totalYield;
            }
        }
    }
    
    // ============= View Functions =============
    
    /// @notice Get holder's performance metrics
    function getMetrics(address holder) external view returns (PerformanceMetrics memory) {
        return metrics[holder];
    }
    
    /// @notice Get holder's performance record
    function getPerformanceRecord(address holder) 
        external 
        view 
        returns (HolderPerformance memory) 
    {
        return holderPerformance[holder];
    }
    
    /// @notice Get yield bonus count for holder
    function getYieldBonusCount(address holder) external view returns (uint256) {
        return yieldBonuses[holder].length;
    }
    
    /// @notice Get specific yield bonus
    function getYieldBonusAt(address holder, uint256 index) 
        external 
        view 
        returns (YieldBonus memory) 
    {
        require(index < yieldBonuses[holder].length, "PerformanceYieldCalculator: Invalid index");
        return yieldBonuses[holder][index];
    }
    
    // ============= Admin Functions =============
    
    /// @notice Update target yield percentage
    function setTargetYield(uint256 newTargetBPS) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newTargetBPS > 0 && newTargetBPS < BASIS_POINTS * 10, "PerformanceYieldCalculator: Invalid target");
        uint256 oldTarget = targetYieldBPS;
        targetYieldBPS = newTargetBPS;
        
        emit TargetYieldUpdated(oldTarget, newTargetBPS, block.timestamp);
    }
    
    /// @notice Update performance bonus rate
    function setPerformanceBonusRate(uint256 newRateBPS) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newRateBPS >= BASIS_POINTS && newRateBPS < BASIS_POINTS * 3, "PerformanceYieldCalculator: Invalid rate");
        uint256 oldRate = performanceBonusRate;
        performanceBonusRate = newRateBPS;
        
        emit BonusRateUpdated(oldRate, newRateBPS, block.timestamp);
    }
    
    /// @notice Set minimum outperformance gap to trigger bonus
    function setMinOutperformanceGap(uint256 gapBPS) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(gapBPS < BASIS_POINTS, "PerformanceYieldCalculator: Invalid gap");
        minOutperformanceGap = gapBPS;
    }
}
