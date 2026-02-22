// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title SVPValuationEngine
 * @notice Core on-chain intrinsic valuation engine for SVP Protocol
 * @dev Implements UUPS upgradeable pattern for modular algorithm updates
 * @author Hudu Yusuf (Analys)
 */
contract SVPValuationEngine is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    // ============= Constants =============
    
    bytes32 public constant REPORTER_ROLE = keccak256("REPORTER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    /// @notice Base unit for fixed-point arithmetic (1e18)
    uint256 public constant BASE_UNIT = 1e18;
    
    /// @notice Maximum allowed risk factor (prevents division by zero)
    uint256 public constant MAX_RISK_FACTOR = 1e19;
    
    /// @notice Minimum allowed risk factor
    uint256 public constant MIN_RISK_FACTOR = 1e16;
    
    /// @notice Maximum growth rate (10,000% = 100x)
    uint256 public constant MAX_GROWTH_RATE = 100 * BASE_UNIT;
    
    // ============= Data Structures =============
    
    /// @notice Financial metrics for an asset
    struct FinancialData {
        uint256 revenue;           // Annual revenue in wei
        uint256 growthRate;        // Annual growth rate (1e18 = 100%)
        uint256 assetValue;        // Total assets value in wei
        uint256 liabilities;       // Total liabilities in wei
        uint256 riskFactor;        // Risk multiplier (1e18 = neutral, >1 = riskier)
        uint256 lastUpdated;       // Timestamp of last update
        bool isApproved;           // Admin approval flag
    }
    
    /// @notice Valuation snapshot
    struct Valuation {
        uint256 intrinsicValue;    // Calculated intrinsic value in wei
        uint256 netAssets;         // Net asset value component
        uint256 revenueValue;      // Revenue-based value component
        uint256 lastCalculated;    // Timestamp of calculation
        uint256 blockNumber;       // Block number for historical tracking
    }
    
    // ============= State Variables =============
    
    /// @notice Financial data per asset
    mapping(address => FinancialData) public financials;
    
    /// @notice Valuation snapshots per asset
    mapping(address => Valuation) public valuations;
    
    /// @notice Historical valuations per asset (for analytics)
    mapping(address => Valuation[]) public valuationHistory;
    
    /// @notice External valuation module (allows algorithm updates)
    address public valuationModule;
    
    /// @notice Maximum historical records to keep per asset
    uint256 public maxHistoryLength = 365;
    
    /// @notice Last update timestamp per asset (rate limiting)
    mapping(address => uint256) public lastUpdateTime;
    
    /// @notice Update frequency rate limit (minimum seconds between updates)
    uint256 public updateFrequency = 1 days;
    
    // ============= Events =============
    
    /// @notice Emitted when financial data is submitted
    event FinancialDataSubmitted(
        address indexed asset,
        uint256 revenue,
        uint256 growthRate,
        uint256 assetValue,
        uint256 liabilities,
        uint256 riskFactor,
        address indexed reporter,
        uint256 timestamp
    );
    
    /// @notice Emitted when financial data is approved by admin
    event FinancialDataApproved(address indexed asset, address indexed admin, uint256 timestamp);
    
    /// @notice Emitted when financial data is rejected
    event FinancialDataRejected(address indexed asset, string reason, address indexed admin, uint256 timestamp);
    
    /// @notice Emitted when intrinsic value is calculated
    event IntrinsicValueCalculated(
        address indexed asset,
        uint256 intrinsicValue,
        uint256 netAssets,
        uint256 revenueValue,
        uint256 timestamp
    );
    
    /// @notice Emitted when valuation module is changed
    event ValuationModuleChanged(address indexed newModule, address indexed admin, uint256 timestamp);
    
    /// @notice Emitted when update frequency is changed
    event UpdateFrequencyChanged(uint256 newFrequency, address indexed admin, uint256 timestamp);
    
    /// @notice Emitted when max history length is changed
    event MaxHistoryLengthChanged(uint256 newLength, address indexed admin, uint256 timestamp);
    
    // ============= Initialization =============
    
    /**
     * @notice Initialize the valuation engine
     * @dev Called once via proxy
     */
    function initialize() public initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        
        // Grant roles to deployer
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }
    
    // ============= Core Valuation Functions =============
    
    /**
     * @notice Submit financial data for an asset (reporter-only)
     * @param asset Address representing the asset
     * @param revenue Annual revenue in wei
     * @param growthRate Annual growth rate (1e18 = 100%)
     * @param assetValue Total asset value in wei
     * @param liabilities Total liabilities in wei
     * @param riskFactor Risk adjustment factor (1e18 = neutral)
     */
    function submitFinancialData(
        address asset,
        uint256 revenue,
        uint256 growthRate,
        uint256 assetValue,
        uint256 liabilities,
        uint256 riskFactor
    )
        external
        onlyRole(REPORTER_ROLE)
        whenNotPaused
        nonReentrant
    {
        require(asset != address(0), "SVPValuationEngine: Invalid asset address");
        require(revenue > 0, "SVPValuationEngine: Revenue must be positive");
        require(growthRate <= MAX_GROWTH_RATE, "SVPValuationEngine: Growth rate too high");
        require(riskFactor >= MIN_RISK_FACTOR && riskFactor <= MAX_RISK_FACTOR, "SVPValuationEngine: Invalid risk factor");
        require(assetValue > 0, "SVPValuationEngine: Asset value must be positive");
        
        // Rate limiting check
        require(
            block.timestamp >= lastUpdateTime[asset] + updateFrequency,
            "SVPValuationEngine: Update frequency exceeded"
        );
        
        // Update financial data
        financials[asset] = FinancialData({
            revenue: revenue,
            growthRate: growthRate,
            assetValue: assetValue,
            liabilities: liabilities,
            riskFactor: riskFactor,
            lastUpdated: block.timestamp,
            isApproved: false  // Requires admin approval
        });
        
        lastUpdateTime[asset] = block.timestamp;
        
        emit FinancialDataSubmitted(
            asset,
            revenue,
            growthRate,
            assetValue,
            liabilities,
            riskFactor,
            msg.sender,
            block.timestamp
        );
    }
    
    /**
     * @notice Admin approves submitted financial data
     * @param asset Address of asset
     */
    function approveFinancialData(address asset)
        external
        onlyRole(ADMIN_ROLE)
        whenNotPaused
    {
        require(asset != address(0), "SVPValuationEngine: Invalid asset address");
        FinancialData storage data = financials[asset];
        require(data.revenue > 0, "SVPValuationEngine: No data to approve");
        
        data.isApproved = true;
        
        emit FinancialDataApproved(asset, msg.sender, block.timestamp);
    }
    
    /**
     * @notice Admin rejects submitted financial data
     * @param asset Address of asset
     * @param reason Reason for rejection
     */
    function rejectFinancialData(address asset, string calldata reason)
        external
        onlyRole(ADMIN_ROLE)
        whenNotPaused
    {
        require(asset != address(0), "SVPValuationEngine: Invalid asset address");
        delete financials[asset];
        
        emit FinancialDataRejected(asset, reason, msg.sender, block.timestamp);
    }
    
    /**
     * @notice Calculate intrinsic value for an asset (core valuation logic)
     * @param asset Address of asset to value
     * @return intrinsicValue Calculated intrinsic value in wei
     */
    function calculateIntrinsicValue(address asset)
        external
        onlyRole(ADMIN_ROLE)
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        require(asset != address(0), "SVPValuationEngine: Invalid asset address");
        
        FinancialData memory data = financials[asset];
        require(data.revenue > 0, "SVPValuationEngine: No approved data");
        require(data.isApproved, "SVPValuationEngine: Data not approved");
        
        uint256 intrinsicValue;
        uint256 netAssets;
        uint256 revenueValue;
        
        if (address(valuationModule) != address(0)) {
            // Use external valuation module if set
            intrinsicValue = _callValuationModule(asset, data);
            // For history, calculate components manually
            netAssets = data.assetValue > data.liabilities
                ? data.assetValue - data.liabilities
                : 0;
            revenueValue = intrinsicValue > netAssets
                ? intrinsicValue - netAssets
                : 0;
        } else {
            // Use default valuation formula
            (intrinsicValue, netAssets, revenueValue) = _calculateDefaultValuation(data);
        }
        
        // Store valuation
        Valuation memory valuation = Valuation({
            intrinsicValue: intrinsicValue,
            netAssets: netAssets,
            revenueValue: revenueValue,
            lastCalculated: block.timestamp,
            blockNumber: block.number
        });
        
        valuations[asset] = valuation;
        
        // Store in history
        valuationHistory[asset].push(valuation);
        
        // Trim history if too long
        if (valuationHistory[asset].length > maxHistoryLength) {
            // Shift array down (inefficient, consider different approach in production)
            for (uint256 i = 0; i < valuationHistory[asset].length - 1; i++) {
                valuationHistory[asset][i] = valuationHistory[asset][i + 1];
            }
            valuationHistory[asset].pop();
        }
        
        emit IntrinsicValueCalculated(
            asset,
            intrinsicValue,
            netAssets,
            revenueValue,
            block.timestamp
        );
        
        return intrinsicValue;
    }
    
    // ============= Internal Valuation Logic =============
    
    /**
     * @notice Calculate valuation using default formula
     * @param data Financial data for asset
     * @return intrinsicValue Total intrinsic value
     * @return netAssets Net asset value component
     * @return revenueValue Revenue-based value component
     */
    function _calculateDefaultValuation(FinancialData memory data)
        internal
        pure
        returns (uint256 intrinsicValue, uint256 netAssets, uint256 revenueValue)
    {
        // Net Assets Component
        // NetAssets = Max(0, Assets - Liabilities)
        netAssets = data.assetValue > data.liabilities
            ? data.assetValue - data.liabilities
            : 0;
        
        // Revenue Value Component
        // RevenueValue = (Revenue × GrowthMultiplier) / RiskFactor
        // where GrowthMultiplier = 1 + GrowthRate
        uint256 growthMultiplier = BASE_UNIT + data.growthRate;
        uint256 baseRevenueValue = (data.revenue * growthMultiplier) / BASE_UNIT;
        revenueValue = (baseRevenueValue * BASE_UNIT) / data.riskFactor;
        
        // Total Intrinsic Value
        intrinsicValue = netAssets + revenueValue;
    }
    
    /**
     * @notice Call external valuation module
     * @param asset Asset address
     * @param data Financial data
     * @return intrinsicValue Valuation from module
     */
    function _callValuationModule(address asset, FinancialData memory data)
        internal
        view
        returns (uint256)
    {
        // In production, would implement proper interface call with error handling
        // For now, return default calculation as fallback
        (uint256 value, , ) = _calculateDefaultValuation(data);
        return value;
    }
    
    // ============= View Functions =============
    
    /**
     * @notice Get current intrinsic value of an asset
     * @param asset Address of asset
     * @return Current intrinsic value in wei
     */
    function getIntrinsicValue(address asset) external view returns (uint256) {
        return valuations[asset].intrinsicValue;
    }
    
    /**
     * @notice Get current valuation snapshot
     * @param asset Address of asset
     * @return Current valuation data
     */
    function getValuation(address asset) external view returns (Valuation memory) {
        return valuations[asset];
    }
    
    /**
     * @notice Get financial data for an asset
     * @param asset Address of asset
     * @return Financial data
     */
    function getFinancialData(address asset) external view returns (FinancialData memory) {
        return financials[asset];
    }
    
    /**
     * @notice Get valuation history length
     * @param asset Address of asset
     * @return Number of historical valuations
     */
    function getValuationHistoryLength(address asset) external view returns (uint256) {
        return valuationHistory[asset].length;
    }
    
    /**
     * @notice Get historical valuation at index
     * @param asset Address of asset
     * @param index History index
     * @return Historical valuation
     */
    function getValuationAtIndex(address asset, uint256 index)
        external
        view
        returns (Valuation memory)
    {
        require(index < valuationHistory[asset].length, "SVPValuationEngine: Index out of range");
        return valuationHistory[asset][index];
    }
    
    // ============= Admin Functions =============
    
    /**
     * @notice Set external valuation module
     * @param newModule Address of new valuation module
     */
    function setValuationModule(address newModule)
        external
        onlyRole(ADMIN_ROLE)
    {
        valuationModule = newModule;
        emit ValuationModuleChanged(newModule, msg.sender, block.timestamp);
    }
    
    /**
     * @notice Set minimum update frequency
     * @param newFrequency Minimum seconds between updates
     */
    function setUpdateFrequency(uint256 newFrequency)
        external
        onlyRole(ADMIN_ROLE)
    {
        updateFrequency = newFrequency;
        emit UpdateFrequencyChanged(newFrequency, msg.sender, block.timestamp);
    }
    
    /**
     * @notice Set maximum history length
     * @param newLength Maximum number of historical valuations to keep
     */
    function setMaxHistoryLength(uint256 newLength)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(newLength > 0, "SVPValuationEngine: History length must be positive");
        maxHistoryLength = newLength;
        emit MaxHistoryLengthChanged(newLength, msg.sender, block.timestamp);
    }
    
    /**
     * @notice Emergency pause function
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @notice Emergency unpause function
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    
    // ============= Upgrade Authorization =============
    
    /**
     * @notice Authorize upgrade to new implementation
     * @param newImplementation Address of new implementation
     */
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}
}
