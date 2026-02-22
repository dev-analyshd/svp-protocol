// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title MultiAssetRevenueRouter
 * @notice Routes revenue from multiple sources to dividend pools
 * @dev Supports multiple payment tokens and revenue sources
 * @author Hudu Yusuf (Analys)
 */
contract MultiAssetRevenueRouter is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    
    // ============= Constants & Roles =============
    
    bytes32 public constant SOURCE_ROLE = keccak256("SOURCE_ROLE");
    bytes32 public constant ROUTER_ROLE = keccak256("ROUTER_ROLE");
    bytes32 public constant PAYMENT_TOKEN_ROLE = keccak256("PAYMENT_TOKEN_ROLE");
    
    uint256 public constant BASIS_POINTS = 10000;
    
    // ============= Data Structures =============
    
    enum RevenueSourceType {
        VAULT_YIELD,
        PROTOCOL_FEES,
        LIQUIDATIONS,
        PERFORMANCE_FEES,
        EXTERNAL
    }
    
    struct RevenueSource {
        address sourceAddress;
        RevenueSourceType sourceType;
        bool isActive;
        uint256 totalReceived;
        uint256 lastUpdateBlock;
        uint256 lastUpdateTimestamp;
        string description;
    }
    
    struct RoutingRule {
        address targetPool;
        uint256 allocationBPS;  // In basis points
        bool isActive;
    }
    
    struct PaymentToken {
        address tokenAddress;
        bool isActive;
        uint256 totalVolume;
        uint8 decimals;
        uint256 minAmount;  // Minimum amount to route
    }
    
    struct RevenueRecord {
        address token;
        address source;
        uint256 amount;
        uint256 timestamp;
        RevenueSourceType sourceType;
        bytes metadata;
    }
    
    struct AllocationRecord {
        address token;
        address pool;
        uint256 amount;
        uint256 timestamp;
        uint256 basisPoints;
    }
    
    // ============= State Variables =============
    
    mapping(address => RevenueSource) public revenueSources;  // source address => data
    mapping(address => RoutingRule[]) public routingRules;  // source => routing rules
    mapping(address => PaymentToken) public paymentTokens;  // token => data
    mapping(address => bool) public approvedPools;
    
    RevenueRecord[] public revenueHistory;
    AllocationRecord[] public allocationHistory;
    
    address[] public registeredSources;
    address[] public registeredTokens;
    
    uint256 public totalRevenueReceived;
    uint256 public totalRevenueRouted;
    
    address public dividendDistributor;
    uint256 public feePercentageBPS;  // Fee taken by protocol
    address public feeCollector;
    
    // ============= Events =============
    
    event RevenueSourceRegistered(
        address indexed source,
        RevenueSourceType sourceType,
        string description,
        uint256 timestamp
    );
    
    event RevenueSourceDeactivated(
        address indexed source,
        uint256 timestamp
    );
    
    event PaymentTokenRegistered(
        address indexed token,
        uint8 decimals,
        uint256 minAmount,
        uint256 timestamp
    );
    
    event PaymentTokenDeactivated(
        address indexed token,
        uint256 timestamp
    );
    
    event RoutingRuleAdded(
        address indexed source,
        address indexed pool,
        uint256 allocationBPS,
        uint256 timestamp
    );
    
    event RoutingRuleUpdated(
        address indexed source,
        uint256 ruleIndex,
        uint256 oldBPS,
        uint256 newBPS,
        uint256 timestamp
    );
    
    event RevenueReceived(
        address indexed source,
        address indexed token,
        uint256 amount,
        RevenueSourceType sourceType,
        uint256 timestamp
    );
    
    event RevenueRouted(
        address indexed token,
        address indexed source,
        address indexed pool,
        uint256 amount,
        uint256 basisPoints,
        uint256 timestamp
    );
    
    event FeeCollected(
        address indexed token,
        uint256 amount,
        uint256 timestamp
    );
    
    event PoolApproved(address indexed pool, uint256 timestamp);
    event PoolRemoved(address indexed pool, uint256 timestamp);
    
    // ============= Constructor =============
    
    constructor(address _dividendDistributor) {
        require(_dividendDistributor != address(0), "MultiAssetRevenueRouter: Invalid distributor");
        
        dividendDistributor = _dividendDistributor;
        feePercentageBPS = 500;  // 5% protocol fee
        feeCollector = msg.sender;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(SOURCE_ROLE, msg.sender);
        _grantRole(ROUTER_ROLE, msg.sender);
        _grantRole(PAYMENT_TOKEN_ROLE, msg.sender);
    }
    
    // ============= Revenue Source Management =============
    
    /// @notice Register a new revenue source
    function registerRevenueSource(
        address sourceAddress,
        RevenueSourceType sourceType,
        string calldata description
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(sourceAddress != address(0), "MultiAssetRevenueRouter: Invalid source");
        require(bytes(description).length > 0, "MultiAssetRevenueRouter: Empty description");
        
        revenueSources[sourceAddress] = RevenueSource({
            sourceAddress: sourceAddress,
            sourceType: sourceType,
            isActive: true,
            totalReceived: 0,
            lastUpdateBlock: block.number,
            lastUpdateTimestamp: block.timestamp,
            description: description
        });
        
        registeredSources.push(sourceAddress);
        
        emit RevenueSourceRegistered(sourceAddress, sourceType, description, block.timestamp);
    }
    
    /// @notice Deactivate a revenue source
    function deactivateRevenueSource(address sourceAddress) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(revenueSources[sourceAddress].sourceAddress != address(0), "MultiAssetRevenueRouter: Source not found");
        revenueSources[sourceAddress].isActive = false;
        
        emit RevenueSourceDeactivated(sourceAddress, block.timestamp);
    }
    
    /// @notice Get revenue source data
    function getRevenueSource(address sourceAddress) 
        external 
        view 
        returns (RevenueSource memory) 
    {
        return revenueSources[sourceAddress];
    }
    
    // ============= Payment Token Management =============
    
    /// @notice Register a payment token
    function registerPaymentToken(
        address tokenAddress,
        uint8 decimals,
        uint256 minAmount
    ) external onlyRole(PAYMENT_TOKEN_ROLE) {
        require(tokenAddress != address(0), "MultiAssetRevenueRouter: Invalid token");
        
        paymentTokens[tokenAddress] = PaymentToken({
            tokenAddress: tokenAddress,
            isActive: true,
            totalVolume: 0,
            decimals: decimals,
            minAmount: minAmount
        });
        
        registeredTokens.push(tokenAddress);
        
        emit PaymentTokenRegistered(tokenAddress, decimals, minAmount, block.timestamp);
    }
    
    /// @notice Deactivate a payment token
    function deactivatePaymentToken(address tokenAddress) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(paymentTokens[tokenAddress].tokenAddress != address(0), "MultiAssetRevenueRouter: Token not found");
        paymentTokens[tokenAddress].isActive = false;
        
        emit PaymentTokenDeactivated(tokenAddress, block.timestamp);
    }
    
    /// @notice Get payment token info
    function getPaymentToken(address tokenAddress) 
        external 
        view 
        returns (PaymentToken memory) 
    {
        return paymentTokens[tokenAddress];
    }
    
    // ============= Routing Rules =============
    
    /// @notice Add routing rule for source to pool
    function addRoutingRule(
        address sourceAddress,
        address poolAddress,
        uint256 allocationBPS
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(revenueSources[sourceAddress].sourceAddress != address(0), "MultiAssetRevenueRouter: Source not found");
        require(approvedPools[poolAddress], "MultiAssetRevenueRouter: Pool not approved");
        require(allocationBPS > 0 && allocationBPS <= BASIS_POINTS, "MultiAssetRevenueRouter: Invalid allocation");
        
        routingRules[sourceAddress].push(RoutingRule({
            targetPool: poolAddress,
            allocationBPS: allocationBPS,
            isActive: true
        }));
        
        emit RoutingRuleAdded(sourceAddress, poolAddress, allocationBPS, block.timestamp);
    }
    
    /// @notice Update routing rule allocation
    function updateRoutingRule(
        address sourceAddress,
        uint256 ruleIndex,
        uint256 newAllocationBPS
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        RoutingRule[] storage rules = routingRules[sourceAddress];
        require(ruleIndex < rules.length, "MultiAssetRevenueRouter: Invalid rule index");
        require(newAllocationBPS > 0 && newAllocationBPS <= BASIS_POINTS, "MultiAssetRevenueRouter: Invalid allocation");
        
        uint256 oldBPS = rules[ruleIndex].allocationBPS;
        rules[ruleIndex].allocationBPS = newAllocationBPS;
        
        emit RoutingRuleUpdated(sourceAddress, ruleIndex, oldBPS, newAllocationBPS, block.timestamp);
    }
    
    /// @notice Get routing rules for source
    function getRoutingRules(address sourceAddress) 
        external 
        view 
        returns (RoutingRule[] memory) 
    {
        return routingRules[sourceAddress];
    }
    
    // ============= Pool Management =============
    
    /// @notice Approve a dividend pool
    function approvePool(address poolAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(poolAddress != address(0), "MultiAssetRevenueRouter: Invalid pool");
        approvedPools[poolAddress] = true;
        
        emit PoolApproved(poolAddress, block.timestamp);
    }
    
    /// @notice Remove pool approval
    function removePool(address poolAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        approvedPools[poolAddress] = false;
        
        emit PoolRemoved(poolAddress, block.timestamp);
    }
    
    /// @notice Check if pool is approved
    function isPoolApproved(address poolAddress) external view returns (bool) {
        return approvedPools[poolAddress];
    }
    
    // ============= Revenue Reception & Routing =============
    
    /// @notice Receive revenue from a registered source
    function receiveRevenue(
        address token,
        uint256 amount,
        bytes calldata metadata
    ) external onlyRole(SOURCE_ROLE) nonReentrant whenNotPaused {
        require(revenueSources[msg.sender].isActive, "MultiAssetRevenueRouter: Source not active");
        require(paymentTokens[token].isActive, "MultiAssetRevenueRouter: Token not active");
        require(amount >= paymentTokens[token].minAmount, "MultiAssetRevenueRouter: Amount too small");
        
        // Transfer token from sender
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        // Update source metrics
        revenueSources[msg.sender].totalReceived += amount;
        revenueSources[msg.sender].lastUpdateBlock = block.number;
        revenueSources[msg.sender].lastUpdateTimestamp = block.timestamp;
        
        // Update global metrics
        totalRevenueReceived += amount;
        paymentTokens[token].totalVolume += amount;
        
        // Record revenue
        revenueHistory.push(RevenueRecord({
            token: token,
            source: msg.sender,
            amount: amount,
            timestamp: block.timestamp,
            sourceType: revenueSources[msg.sender].sourceType,
            metadata: metadata
        }));
        
        emit RevenueReceived(
            msg.sender,
            token,
            amount,
            revenueSources[msg.sender].sourceType,
            block.timestamp
        );
        
        // Route revenue to pools
        _routeRevenue(msg.sender, token, amount);
    }
    
    /// @notice Internal function to route revenue
    function _routeRevenue(
        address source,
        address token,
        uint256 amount
    ) internal {
        RoutingRule[] storage rules = routingRules[source];
        require(rules.length > 0, "MultiAssetRevenueRouter: No routing rules");
        
        // Calculate and collect fee
        uint256 feeAmount = (amount * feePercentageBPS) / BASIS_POINTS;
        if (feeAmount > 0) {
            IERC20(token).safeTransfer(feeCollector, feeAmount);
            emit FeeCollected(token, feeAmount, block.timestamp);
        }
        
        uint256 amountToRoute = amount - feeAmount;
        
        // Route to each active pool
        for (uint256 i = 0; i < rules.length; i++) {
            if (rules[i].isActive && approvedPools[rules[i].targetPool]) {
                uint256 poolAmount = (amountToRoute * rules[i].allocationBPS) / BASIS_POINTS;
                
                if (poolAmount > 0) {
                    IERC20(token).safeTransfer(rules[i].targetPool, poolAmount);
                    totalRevenueRouted += poolAmount;
                    
                    allocationHistory.push(AllocationRecord({
                        token: token,
                        pool: rules[i].targetPool,
                        amount: poolAmount,
                        timestamp: block.timestamp,
                        basisPoints: rules[i].allocationBPS
                    }));
                    
                    emit RevenueRouted(
                        token,
                        source,
                        rules[i].targetPool,
                        poolAmount,
                        rules[i].allocationBPS,
                        block.timestamp
                    );
                }
            }
        }
    }
    
    // ============= View Functions =============
    
    /// @notice Get revenue history length
    function getRevenueHistoryLength() external view returns (uint256) {
        return revenueHistory.length;
    }
    
    /// @notice Get revenue record at index
    function getRevenueRecord(uint256 index) 
        external 
        view 
        returns (RevenueRecord memory) 
    {
        require(index < revenueHistory.length, "MultiAssetRevenueRouter: Invalid index");
        return revenueHistory[index];
    }
    
    /// @notice Get allocation history length
    function getAllocationHistoryLength() external view returns (uint256) {
        return allocationHistory.length;
    }
    
    /// @notice Get allocation record at index
    function getAllocationRecord(uint256 index) 
        external 
        view 
        returns (AllocationRecord memory) 
    {
        require(index < allocationHistory.length, "MultiAssetRevenueRouter: Invalid index");
        return allocationHistory[index];
    }
    
    /// @notice Get registered sources count
    function getSourcesCount() external view returns (uint256) {
        return registeredSources.length;
    }
    
    /// @notice Get registered tokens count
    function getTokensCount() external view returns (uint256) {
        return registeredTokens.length;
    }
    
    // ============= Admin Functions =============
    
    /// @notice Update fee percentage
    function setFeePercentage(uint256 newFeeBPS) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newFeeBPS < BASIS_POINTS, "MultiAssetRevenueRouter: Invalid fee");
        feePercentageBPS = newFeeBPS;
    }
    
    /// @notice Update fee collector address
    function setFeeCollector(address newCollector) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newCollector != address(0), "MultiAssetRevenueRouter: Invalid collector");
        feeCollector = newCollector;
    }
    
    /// @notice Pause revenue routing
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    /// @notice Unpause revenue routing
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    /// @notice Emergency token recovery
    function recoverToken(address token, uint256 amount) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(token != address(0), "MultiAssetRevenueRouter: Invalid token");
        IERC20(token).safeTransfer(msg.sender, amount);
    }
}
