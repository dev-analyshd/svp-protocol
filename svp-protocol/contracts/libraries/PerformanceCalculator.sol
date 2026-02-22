// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title PerformanceCalculator
 * @notice Library for performance metrics and analytics calculations
 * @author Hudu Yusuf (Analys)
 */
library PerformanceCalculator {
    /// @notice Basis point constant
    uint256 constant BPS = 10000;
    
    /// @notice Scale factor for fixed-point arithmetic
    uint256 constant SCALE = 1e18;
    
    /// @notice Performance period enum
    enum Period {
        DAILY,
        WEEKLY,
        MONTHLY,
        QUARTERLY,
        YEARLY
    }
    
    /**
     * @notice Calculate simple return
     * @param startValue Starting portfolio value
     * @param endValue Ending portfolio value
     * @return returnBps Return in basis points
     */
    function calculateSimpleReturn(uint256 startValue, uint256 endValue)
        internal
        pure
        returns (int256)
    {
        if (startValue == 0) return 0;
        
        int256 change = int256(endValue) - int256(startValue);
        return (change * int256(BPS)) / int256(startValue);
    }
    
    /**
     * @notice Calculate logarithmic return
     * @param startValue Starting portfolio value
     * @param endValue Ending portfolio value
     * @return logReturn Logarithmic return
     */
    function calculateLogReturn(uint256 startValue, uint256 endValue)
        internal
        pure
        returns (int256)
    {
        if (startValue == 0 || endValue == 0) return 0;
        
        // Simplified log return calculation
        // ln(endValue / startValue)
        if (endValue >= startValue) {
            uint256 ratio = (endValue * SCALE) / startValue;
            return int256(ln(ratio));
        } else {
            uint256 ratio = (startValue * SCALE) / endValue;
            return -int256(ln(ratio));
        }
    }
    
    /**
     * @notice Calculate cumulative return from periodic returns
     * @param periodReturns Array of periodic returns (in basis points)
     * @return cumulativeReturn Cumulative return in basis points
     */
    function calculateCumulativeReturn(int256[] memory periodReturns)
        internal
        pure
        returns (int256)
    {
        int256 cumReturn = int256(BPS); // Start at 100%
        
        for (uint256 i = 0; i < periodReturns.length; i++) {
            cumReturn = cumReturn + (cumReturn * periodReturns[i]) / int256(BPS);
        }
        
        return cumReturn - int256(BPS); // Return excess return
    }
    
    /**
     * @notice Calculate money-weighted return (internal rate of return)
     * @param cashFlows Array of cash flows
     * @param timestamps Array of flow timestamps
     * @param startDate Start date timestamp
     * @param endDate End date timestamp
     * @return mwr Money-weighted return (simplified)
     */
    function calculateMoneyWeightedReturn(
        int256[] memory cashFlows,
        uint256[] memory timestamps,
        uint256 startDate,
        uint256 endDate
    )
        internal
        pure
        returns (int256)
    {
        require(cashFlows.length == timestamps.length, "PerformanceCalculator: Length mismatch");
        
        if (cashFlows.length == 0) return 0;
        
        // Simplified MWR calculation
        // In practice, this would require iterative IRR calculation
        int256 totalFlows = 0;
        uint256 totalDuration = endDate - startDate;
        
        for (uint256 i = 0; i < cashFlows.length; i++) {
            uint256 timeToEnd = endDate > timestamps[i] ? endDate - timestamps[i] : 0;
            uint256 weight = timeToEnd * SCALE / totalDuration;
            totalFlows += cashFlows[i] * int256(weight) / int256(SCALE);
        }
        
        return totalFlows;
    }
    
    /**
     * @notice Calculate time-weighted return
     * @param navValues Net asset value at each period end
     * @param cashFlows Cash flows at each period start
     * @return twr Time-weighted return
     */
    function calculateTimeWeightedReturn(
        uint256[] memory navValues,
        int256[] memory cashFlows
    )
        internal
        pure
        returns (int256)
    {
        require(navValues.length >= 2, "PerformanceCalculator: Need at least 2 NAV values");
        
        int256 cumReturn = int256(SCALE);
        
        for (uint256 i = 0; i < navValues.length - 1; i++) {
            uint256 prevNAV = navValues[i];
            uint256 currNAV = navValues[i + 1];
            
            // Adjust for cash flows
            int256 adjustment = 0;
            if (i < cashFlows.length && cashFlows[i] > 0) {
                adjustment = int256((uint256(cashFlows[i]) * SCALE) / prevNAV);
            }
            
            int256 periodReturn = int256((currNAV * SCALE) / prevNAV) + adjustment;
            cumReturn = (cumReturn * periodReturn) / int256(SCALE);
        }
        
        return cumReturn - int256(SCALE);
    }
    
    /**
     * @notice Calculate volatility from returns
     * @param periodReturns Array of periodic returns
     * @return volatility Standard deviation of returns
     */
    function calculateVolatility(int256[] memory periodReturns)
        internal
        pure
        returns (uint256)
    {
        if (periodReturns.length < 2) return 0;
        
        // Calculate mean
        int256 sum = 0;
        for (uint256 i = 0; i < periodReturns.length; i++) {
            sum += periodReturns[i];
        }
        int256 mean = sum / int256(periodReturns.length);
        
        // Calculate variance
        int256 varianceSum = 0;
        for (uint256 i = 0; i < periodReturns.length; i++) {
            int256 diff = periodReturns[i] - mean;
            varianceSum += diff * diff;
        }
        uint256 variance = uint256(varianceSum) / periodReturns.length;
        
        // Return standard deviation
        return sqrt(variance);
    }
    
    /**
     * @notice Calculate Sortino ratio (downside volatility)
     * @param periodReturns Array of periodic returns
     * @param riskFreeRate Risk-free rate in basis points
     * @return sortino Sortino ratio
     */
    function calculateSortino(int256[] memory periodReturns, int256 riskFreeRate)
        internal
        pure
        returns (int256)
    {
        if (periodReturns.length < 2) return 0;
        
        // Calculate mean return
        int256 sum = 0;
        for (uint256 i = 0; i < periodReturns.length; i++) {
            sum += periodReturns[i];
        }
        int256 meanReturn = sum / int256(periodReturns.length);
        
        // Calculate downside variance (only negative returns)
        int256 downsideVarianceSum = 0;
        for (uint256 i = 0; i < periodReturns.length; i++) {
            if (periodReturns[i] < riskFreeRate) {
                int256 diff = periodReturns[i] - riskFreeRate;
                downsideVarianceSum += diff * diff;
            }
        }
        
        uint256 downsideVariance = uint256(downsideVarianceSum) / periodReturns.length;
        uint256 downside = sqrt(downsideVariance);
        
        if (downside == 0) return 0;
        
        int256 excessReturn = meanReturn - riskFreeRate;
        return (excessReturn * int256(SCALE)) / int256(downside);
    }
    
    /**
     * @notice Calculate Calmar ratio (return / max drawdown)
     * @param returnBps Return in basis points
     * @param maxDrawdown Maximum drawdown in basis points
     * @return calmar Calmar ratio
     */
    function calculateCalmar(int256 returnBps, uint256 maxDrawdown)
        internal
        pure
        returns (int256)
    {
        if (maxDrawdown == 0) return 0;
        
        return (returnBps * int256(SCALE)) / int256(maxDrawdown);
    }
    
    /**
     * @notice Calculate information ratio
     * @param portfolioReturns Array of portfolio returns
     * @param benchmarkReturns Array of benchmark returns
     * @param riskFreeRate Risk-free rate
     * @return informationRatio Information ratio
     */
    function calculateInformationRatio(
        int256[] memory portfolioReturns,
        int256[] memory benchmarkReturns,
        int256 riskFreeRate
    )
        internal
        pure
        returns (int256)
    {
        require(portfolioReturns.length == benchmarkReturns.length, "PerformanceCalculator: Length mismatch");
        
        if (portfolioReturns.length == 0) return 0;
        
        // Calculate tracking error (std dev of active returns)
        int256[] memory activeReturns = new int256[](portfolioReturns.length);
        for (uint256 i = 0; i < portfolioReturns.length; i++) {
            activeReturns[i] = portfolioReturns[i] - benchmarkReturns[i];
        }
        
        uint256 trackingError = calculateVolatility(activeReturns);
        if (trackingError == 0) return 0;
        
        // Calculate excess returns
        int256 portfolioSum = 0;
        int256 benchmarkSum = 0;
        for (uint256 i = 0; i < portfolioReturns.length; i++) {
            portfolioSum += portfolioReturns[i] - riskFreeRate;
            benchmarkSum += benchmarkReturns[i] - riskFreeRate;
        }
        
        int256 excessReturn = portfolioSum - benchmarkSum;
        return (excessReturn * int256(SCALE)) / int256(trackingError);
    }
    
    /**
     * @notice Calculate beta (correlation with market)
     * @param assetReturns Asset returns
     * @param marketReturns Market returns
     * @return beta Beta coefficient
     */
    function calculateBeta(
        int256[] memory assetReturns,
        int256[] memory marketReturns
    )
        internal
        pure
        returns (int256)
    {
        require(assetReturns.length == marketReturns.length, "PerformanceCalculator: Length mismatch");
        
        if (assetReturns.length == 0) return 0;
        
        // Calculate mean returns
        int256 assetSum = 0;
        int256 marketSum = 0;
        for (uint256 i = 0; i < assetReturns.length; i++) {
            assetSum += assetReturns[i];
            marketSum += marketReturns[i];
        }
        int256 assetMean = assetSum / int256(assetReturns.length);
        int256 marketMean = marketSum / int256(marketReturns.length);
        
        // Calculate covariance and market variance
        int256 covariance = 0;
        int256 marketVariance = 0;
        for (uint256 i = 0; i < assetReturns.length; i++) {
            int256 assetDiff = assetReturns[i] - assetMean;
            int256 marketDiff = marketReturns[i] - marketMean;
            covariance += assetDiff * marketDiff;
            marketVariance += marketDiff * marketDiff;
        }
        
        if (marketVariance == 0) return 0;
        
        return (covariance * int256(SCALE)) / (marketVariance);
    }
    
    /**
     * @notice Calculate alpha (Jensen's alpha)
     * @param portfolioReturn Portfolio return
     * @param riskFreeRate Risk-free rate
     * @param beta Portfolio beta
     * @param marketReturn Market return
     * @return alpha Jensen's alpha
     */
    function calculateAlpha(
        int256 portfolioReturn,
        int256 riskFreeRate,
        int256 beta,
        int256 marketReturn
    )
        internal
        pure
        returns (int256)
    {
        int256 expectedReturn = riskFreeRate + (beta * (marketReturn - riskFreeRate)) / int256(SCALE);
        return portfolioReturn - expectedReturn;
    }
    
    /**
     * @notice Calculate profit factor
     * @param grossProfit Total profit from winning trades
     * @param grossLoss Total loss from losing trades
     * @return profitFactor Profit factor
     */
    function calculateProfitFactor(uint256 grossProfit, uint256 grossLoss)
        internal
        pure
        returns (uint256)
    {
        if (grossLoss == 0) return type(uint256).max;
        return (grossProfit * SCALE) / grossLoss;
    }
    
    /**
     * @notice Calculate Omega ratio
     * @param periodReturns Array of returns
     * @param threshold Return threshold
     * @return omega Omega ratio
     */
    function calculateOmega(int256[] memory periodReturns, int256 threshold)
        internal
        pure
        returns (int256)
    {
        if (periodReturns.length == 0) return 0;
        
        int256 gainSum = 0;
        int256 lossSum = 0;
        
        for (uint256 i = 0; i < periodReturns.length; i++) {
            if (periodReturns[i] > threshold) {
                gainSum += periodReturns[i] - threshold;
            } else {
                lossSum += threshold - periodReturns[i];
            }
        }
        
        if (lossSum == 0) return type(int256).max;
        
        return (gainSum * int256(SCALE)) / lossSum;
    }
    
    // ============= Internal Math Functions =============
    
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
    
    function ln(uint256 x) internal pure returns (int256) {
        require(x > 0, "PerformanceCalculator: ln of non-positive");
        
        int256 result = 0;
        int256 exponent = int256(SCALE);
        
        while (x > 2 * SCALE) {
            x = x / 2;
            result += 693147; // ln(2) with reduced precision
        }
        
        while (x < SCALE) {
            x = x * 2;
            result -= 693147;
        }
        
        return result;
    }
}
