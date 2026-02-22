// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title VaultMath
 * @notice Mathematical utilities for vault calculations
 * @author Hudu Yusuf (Analys)
 */
library VaultMath {
    /// @notice Basis point constant (100 = 1%)
    uint256 constant BPS = 10000;
    
    /// @notice Scale factor for fixed-point arithmetic
    uint256 constant SCALE = 1e18;
    
    /**
     * @notice Calculate percentage with basis points
     * @param amount Base amount
     * @param percentage Percentage in basis points
     * @return result Calculated percentage of amount
     */
    function calculatePercentage(uint256 amount, uint256 percentage)
        internal
        pure
        returns (uint256)
    {
        return (amount * percentage) / BPS;
    }
    
    /**
     * @notice Calculate basis points from two values
     * @param part The part value
     * @param total The total value
     * @return bps Basis points representation
     */
    function calculateBPS(uint256 part, uint256 total)
        internal
        pure
        returns (uint256)
    {
        if (total == 0) return 0;
        return (part * BPS) / total;
    }
    
    /**
     * @notice Weighted average calculation
     * @param values Array of values
     * @param weights Array of weights (in basis points)
     * @return weighted Weighted average
     */
    function weightedAverage(uint256[] memory values, uint256[] memory weights)
        internal
        pure
        returns (uint256)
    {
        require(values.length == weights.length, "VaultMath: Length mismatch");
        require(values.length > 0, "VaultMath: Empty arrays");
        
        uint256 totalWeight = 0;
        uint256 weightedSum = 0;
        
        for (uint256 i = 0; i < values.length; i++) {
            weightedSum += values[i] * weights[i];
            totalWeight += weights[i];
        }
        
        if (totalWeight == 0) return 0;
        return weightedSum / totalWeight;
    }
    
    /**
     * @notice Calculate allocation drift
     * @param currentAmount Current position size
     * @param targetAmount Target position size
     * @return drift Absolute drift in basis points
     */
    function calculateDrift(uint256 currentAmount, uint256 targetAmount)
        internal
        pure
        returns (uint256)
    {
        if (targetAmount == 0) return type(uint256).max;
        
        if (currentAmount > targetAmount) {
            return ((currentAmount - targetAmount) * BPS) / targetAmount;
        } else {
            return ((targetAmount - currentAmount) * BPS) / targetAmount;
        }
    }
    
    /**
     * @notice Check if drift exceeds tolerance
     * @param currentAmount Current position size
     * @param targetAmount Target position size
     * @param tolerance Tolerance in basis points
     * @return exceedsTolerance True if drift exceeds tolerance
     */
    function isDriftExcessive(
        uint256 currentAmount,
        uint256 targetAmount,
        uint256 tolerance
    )
        internal
        pure
        returns (bool)
    {
        uint256 drift = calculateDrift(currentAmount, targetAmount);
        return drift > tolerance;
    }
    
    /**
     * @notice Calculate compounded return
     * @param principal Initial investment
     * @param rate APY in basis points (10000 = 100%)
     * @param periods Number of compounding periods
     * @return compounded Compounded value
     */
    function compoundReturn(
        uint256 principal,
        uint256 rate,
        uint256 periods
    )
        internal
        pure
        returns (uint256)
    {
        uint256 result = principal;
        
        for (uint256 i = 0; i < periods; i++) {
            result = result + (result * rate) / BPS;
        }
        
        return result;
    }
    
    /**
     * @notice Calculate annualized return from periodic return
     * @param periodicReturn Return for one period
     * @param periodsPerYear Number of periods in a year
     * @return annualizedReturn Annualized return in basis points
     */
    function annualizeReturn(uint256 periodicReturn, uint256 periodsPerYear)
        internal
        pure
        returns (uint256)
    {
        if (periodsPerYear == 0) return 0;
        return periodicReturn * periodsPerYear;
    }
    
    /**
     * @notice Calculate Sharpe ratio (simplified)
     * @param periodReturns Array of periodic returns
     * @param riskFreeRate Risk-free rate in basis points
     * @return sharpeRatio Sharpe ratio scaled by 1e18
     */
    function calculateSharpeRatio(
        int256[] memory periodReturns,
        uint256 riskFreeRate
    )
        internal
        pure
        returns (uint256)
    {
        if (periodReturns.length == 0) return 0;
        
        // Calculate mean return
        int256 sum = 0;
        for (uint256 i = 0; i < periodReturns.length; i++) {
            sum += periodReturns[i];
        }
        int256 meanReturn = sum / int256(periodReturns.length);
        
        // Calculate standard deviation
        int256 varianceSum = 0;
        for (uint256 i = 0; i < periodReturns.length; i++) {
            int256 diff = periodReturns[i] - meanReturn;
            varianceSum += diff * diff;
        }
        
        uint256 variance = uint256(varianceSum) / periodReturns.length;
        uint256 stdDev = sqrt(variance);
        
        // Sharpe ratio = (mean return - risk free rate) / std dev
        if (stdDev == 0) return 0;
        
        int256 excessReturn = meanReturn - int256(riskFreeRate);
        if (excessReturn <= 0) return 0;
        
        return (uint256(excessReturn) * SCALE) / stdDev;
    }
    
    /**
     * @notice Calculate maximum drawdown
     * @param prices Array of prices over time
     * @return maxDrawdown Maximum drawdown in basis points
     */
    function calculateMaxDrawdown(uint256[] memory prices)
        internal
        pure
        returns (uint256)
    {
        if (prices.length < 2) return 0;
        
        uint256 peak = prices[0];
        uint256 maxDD = 0;
        
        for (uint256 i = 1; i < prices.length; i++) {
            if (prices[i] > peak) {
                peak = prices[i];
            }
            
            if (prices[i] < peak) {
                uint256 dd = ((peak - prices[i]) * BPS) / peak;
                if (dd > maxDD) {
                    maxDD = dd;
                }
            }
        }
        
        return maxDD;
    }
    
    /**
     * @notice Calculate concentration risk (Herfindahl index)
     * @param allocations Array of allocation percentages (in basis points)
     * @return concentration Concentration index (0-10000)
     */
    function calculateConcentration(uint256[] memory allocations)
        internal
        pure
        returns (uint256)
    {
        uint256 sumOfSquares = 0;
        
        for (uint256 i = 0; i < allocations.length; i++) {
            uint256 allocation = allocations[i];
            sumOfSquares += (allocation * allocation) / BPS;
        }
        
        return sumOfSquares;
    }
    
    /**
     * @notice Integer square root using Newton's method
     * @param x Value to sqrt
     * @return y Square root
     */
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        
        return y;
    }
    
    /**
     * @notice Calculate time-weighted average price
     * @param prices Array of prices
     * @param durations Array of durations for each price
     * @return twap Time-weighted average price
     */
    function calculateTWAP(
        uint256[] memory prices,
        uint256[] memory durations
    )
        internal
        pure
        returns (uint256)
    {
        require(prices.length == durations.length, "VaultMath: Length mismatch");
        require(prices.length > 0, "VaultMath: Empty arrays");
        
        uint256 weightedPrice = 0;
        uint256 totalDuration = 0;
        
        for (uint256 i = 0; i < prices.length; i++) {
            weightedPrice += prices[i] * durations[i];
            totalDuration += durations[i];
        }
        
        if (totalDuration == 0) return 0;
        return weightedPrice / totalDuration;
    }
    
    /**
     * @notice Check if value is within tolerance range
     * @param value Current value
     * @param target Target value
     * @param toleranceBps Tolerance in basis points
     * @return isWithinTolerance True if within tolerance
     */
    function isWithinTolerance(
        uint256 value,
        uint256 target,
        uint256 toleranceBps
    )
        internal
        pure
        returns (bool)
    {
        if (target == 0) return value == 0;
        
        uint256 upper = target + (target * toleranceBps) / BPS;
        uint256 lower = target > (target * toleranceBps) / BPS
            ? target - (target * toleranceBps) / BPS
            : 0;
        
        return value >= lower && value <= upper;
    }
}
