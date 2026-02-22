// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title SVPSPVVault
 * @notice Special Purpose Vehicle vault for capital pooling (ERC-4626)
 * @dev Investors deposit stablecoin, mint SPV shares, vault invests in SVP tokens
 * @author Hudu Yusuf (Analys)
 */
contract SVPSPVVault is ERC4626, AccessControl, ReentrancyGuard, Pausable {
    // ============= Constants =============
    
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    /// @notice Basis point divisor (100 = 1%)
    uint256 public constant BPS = 10000;
    
    // ============= Data Structures =============
    
    /// @notice Portfolio position in SVP asset
    struct Position {
        address svpToken;              // SVP token address
        uint256 amount;                // Amount of SVP tokens held
        uint256 allocationPercentage;  // Allocation % (in basis points)
        uint256 entryPrice;            // Entry price when acquired
        uint256 currentValue;          // Current estimated value
        uint256 acquisitionBlock;      // Block when acquired
    }
    
    /// @notice Redemption request
    struct RedemptionRequest {
        address requester;             // Who requested redemption
        uint256 shareAmount;           // Number of shares to redeem
        uint256 requestTimestamp;      // When requested
        bool completed;                // Has redemption been completed
        uint256 completionTimestamp;   // When completed
    }
    
    // ============= State Variables =============
    
    /// @notice Performance tracking
    struct PerformanceMetrics {
        uint256 totalInvested;         // Total capital invested
        uint256 totalReturned;         // Total capital returned
        uint256 realizedGains;         // Realized gains/losses
        uint256 unrealizedGains;       // Unrealized gains/losses
        uint256 lastUpdateTimestamp;   // Last metrics update
    }
    
    /// @notice Portfolio positions
    mapping(address => Position) public positions;
    address[] public portfolioAssets;
    
    /// @notice Active positions count
    uint256 public activePositionCount;
    
    /// @notice Redemption requests queue
    RedemptionRequest[] public redemptionQueue;
    
    /// @notice Pending redemptions
    mapping(address => uint256[]) public userRedemptions;
    
    /// @notice Performance metrics
    PerformanceMetrics public metrics;
    
    /// @notice Vault parameters
    uint256 public minDepositAmount = 100e6;    // 100 USDC
    uint256 public maxAllocationPerAsset = 3000; // 30% max per asset
    uint256 public redemptionCooldown = 1 days;  // Min time between redemption and execution
    uint256 public lastRebalanceTimestamp;
    uint256 public rebalanceFrequency = 7 days;  // Weekly rebalancing
    
    /// @notice Fee parameters
    uint256 public managementFeePercentage = 200;  // 2% annual (in bps)
    uint256 public performanceFeePercentage = 2000; // 20% of profits (in bps)
    address public feeRecipient;
    
    /// @notice Dividend tracking
    uint256 public totalDividendsReceived;
    mapping(address => uint256) public dividendsClaimed;
    
    /// @notice Net Asset Value (NAV) per share history
    uint256[] public navHistory;
    uint256[] public navTimestamps;
    
    // ============= Events =============
    
    /// @notice Emitted when position is opened
    event PositionOpened(
        address indexed svpToken,
        uint256 amount,
        uint256 allocationPercentage,
        address indexed manager,
        uint256 timestamp
    );
    
    /// @notice Emitted when position is closed
    event PositionClosed(
        address indexed svpToken,
        uint256 amount,
        uint256 exitPrice,
        int256 profit,
        address indexed manager,
        uint256 timestamp
    );
    
    /// @notice Emitted when position is rebalanced
    event PositionRebalanced(
        address indexed svpToken,
        uint256 oldAmount,
        uint256 newAmount,
        address indexed manager,
        uint256 timestamp
    );
    
    /// @notice Emitted when dividends are received
    event DividendReceived(
        address indexed svpToken,
        uint256 amount,
        uint256 timestamp
    );
    
    /// @notice Emitted when redemption is requested
    event RedemptionRequested(
        uint256 indexed redemptionId,
        address indexed requester,
        uint256 shareAmount,
        uint256 timestamp
    );
    
    /// @notice Emitted when redemption is executed
    event RedemptionExecuted(
        uint256 indexed redemptionId,
        address indexed requester,
        uint256 shareAmount,
        uint256 assetAmount,
        uint256 timestamp
    );
    
    /// @notice Emitted when NAV is calculated
    event NAVCalculated(uint256 nav, uint256 timestamp);
    
    /// @notice Emitted when fees are collected
    event FeesCollected(uint256 managementFee, uint256 performanceFee, uint256 timestamp);
    
    /// @notice Emitted when parameters are updated
    event ParametersUpdated(
        uint256 minDeposit,
        uint256 maxAllocation,
        uint256 managementFee,
        uint256 performanceFee,
        address indexed admin,
        uint256 timestamp
    );
    
    // ============= Constructor =============
    
    /**
     * @notice Initialize SVP SPV Vault
     * @param asset_ Underlying stablecoin asset (USDC, DAI, USDT)
     * @param name_ Vault name
     * @param symbol_ Vault symbol
     */
    constructor(
        IERC20 asset_,
        string memory name_,
        string memory symbol_
    )
        ERC20(name_, symbol_)
        ERC4626(asset_)
    {
        require(address(asset_) != address(0), "SVPSPVVault: Invalid asset");
        
        lastRebalanceTimestamp = block.timestamp;
        feeRecipient = msg.sender;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, msg.sender);
    }
    
    // ============= ERC-4626 Core Functions =============
    
    /**
     * @notice Deposit stablecoin to receive vault shares
     * @param assets Amount of stablecoin to deposit
     * @param receiver Address to receive shares
     * @return shares Number of shares minted
     */
    function deposit(uint256 assets, address receiver)
        public
        override
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        require(assets >= minDepositAmount, "SVPSPVVault: Deposit below minimum");
        require(receiver != address(0), "SVPSPVVault: Invalid receiver");
        
        uint256 shares = previewDeposit(assets);
        
        // Transfer stablecoin from user
        IERC20(asset()).transferFrom(msg.sender, address(this), assets);
        
        // Mint shares
        _mint(receiver, shares);
        
        // Update metrics
        metrics.totalInvested += assets;
        
        emit Deposit(msg.sender, receiver, assets, shares);
        
        return shares;
    }
    
    /**
     * @notice Withdraw stablecoin by burning shares
     * @param assets Amount of stablecoin to withdraw
     * @param receiver Address to receive stablecoin
     * @param owner Shares owner
     * @return shares Number of shares burned
     */
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
        
        // Burn shares
        _burn(owner, shares);
        
        // Transfer stablecoin to receiver
        IERC20(asset()).transfer(receiver, assets);
        
        // Update metrics
        metrics.totalReturned += assets;
        
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        
        return shares;
    }
    
    /**
     * @notice Redeem shares for stablecoin (with cooldown)
     * @param shares Number of shares to redeem
     * @return redemptionId ID for redemption request
     */
    function requestRedemption(uint256 shares)
        external
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        require(shares > 0, "SVPSPVVault: Shares must be positive");
        require(balanceOf(msg.sender) >= shares, "SVPSPVVault: Insufficient shares");
        
        uint256 assets = previewRedeem(shares);
        
        RedemptionRequest memory request = RedemptionRequest({
            requester: msg.sender,
            shareAmount: shares,
            requestTimestamp: block.timestamp,
            completed: false,
            completionTimestamp: 0
        });
        
        uint256 redemptionId = redemptionQueue.length;
        redemptionQueue.push(request);
        userRedemptions[msg.sender].push(redemptionId);
        
        emit RedemptionRequested(redemptionId, msg.sender, shares, block.timestamp);
        
        return redemptionId;
    }
    
    /**
     * @notice Execute pending redemption request
     * @param redemptionId ID of redemption request
     */
    function executeRedemption(uint256 redemptionId)
        external
        whenNotPaused
        nonReentrant
    {
        require(redemptionId < redemptionQueue.length, "SVPSPVVault: Invalid redemption ID");
        
        RedemptionRequest storage request = redemptionQueue[redemptionId];
        require(!request.completed, "SVPSPVVault: Redemption already completed");
        require(
            block.timestamp >= request.requestTimestamp + redemptionCooldown,
            "SVPSPVVault: Cooldown period not satisfied"
        );
        
        uint256 assets = previewRedeem(request.shareAmount);
        
        // Burn shares
        _burn(request.requester, request.shareAmount);
        
        // Transfer stablecoin
        IERC20(asset()).transfer(request.requester, assets);
        
        // Mark as completed
        request.completed = true;
        request.completionTimestamp = block.timestamp;
        
        metrics.totalReturned += assets;
        
        emit RedemptionExecuted(
            redemptionId,
            request.requester,
            request.shareAmount,
            assets,
            block.timestamp
        );
    }
    
    // ============= Portfolio Management =============
    
    /**
     * @notice Open new position in SVP token
     * @param svpToken SVP token to invest in
     * @param amount Amount of stablecoin to allocate
     */
    function openPosition(address svpToken, uint256 amount)
        external
        onlyRole(MANAGER_ROLE)
        whenNotPaused
        nonReentrant
    {
        require(svpToken != address(0), "SVPSPVVault: Invalid token");
        require(amount > 0, "SVPSPVVault: Amount must be positive");
        require(amount <= IERC20(asset()).balanceOf(address(this)), "SVPSPVVault: Insufficient balance");
        
        // Check allocation limit
        uint256 newAllocation = (amount * BPS) / totalAssets();
        require(newAllocation <= maxAllocationPerAsset, "SVPSPVVault: Allocation exceeds maximum");
        
        Position storage position = positions[svpToken];
        
        if (position.amount == 0) {
            // New position
            portfolioAssets.push(svpToken);
            activePositionCount++;
        }
        
        // Update position (simplified - would need actual token purchase logic)
        position.svpToken = svpToken;
        position.amount += amount;
        position.allocationPercentage = (amount * BPS) / totalAssets();
        position.entryPrice = _getTokenPrice(svpToken);
        position.acquisitionBlock = block.number;
        
        // Transfer stablecoin to position (in production, would swap for SVP token)
        IERC20(asset()).transfer(svpToken, amount);
        
        emit PositionOpened(svpToken, amount, position.allocationPercentage, msg.sender, block.timestamp);
    }
    
    /**
     * @notice Close existing position
     * @param svpToken SVP token to exit
     */
    function closePosition(address svpToken)
        external
        onlyRole(MANAGER_ROLE)
        whenNotPaused
        nonReentrant
    {
        require(svpToken != address(0), "SVPSPVVault: Invalid token");
        Position storage position = positions[svpToken];
        require(position.amount > 0, "SVPSPVVault: No position to close");
        
        uint256 exitPrice = _getTokenPrice(svpToken);
        uint256 oldAmount = position.amount;
        int256 profit = int256((oldAmount * exitPrice) / 1e18) - int256(oldAmount);
        
        // Update metrics
        if (profit > 0) {
            metrics.unrealizedGains += uint256(profit);
        } else {
            metrics.unrealizedGains -= uint256(-profit);
        }
        
        // Clear position
        delete positions[svpToken];
        activePositionCount--;
        
        // Remove from portfolio
        for (uint256 i = 0; i < portfolioAssets.length; i++) {
            if (portfolioAssets[i] == svpToken) {
                portfolioAssets[i] = portfolioAssets[portfolioAssets.length - 1];
                portfolioAssets.pop();
                break;
            }
        }
        
        emit PositionClosed(svpToken, oldAmount, exitPrice, profit, msg.sender, block.timestamp);
    }
    
    /**
     * @notice Rebalance portfolio allocation
     */
    function rebalance()
        external
        onlyRole(MANAGER_ROLE)
        whenNotPaused
        nonReentrant
    {
        require(
            block.timestamp >= lastRebalanceTimestamp + rebalanceFrequency,
            "SVPSPVVault: Rebalancing too frequent"
        );
        
        uint256 totalValue = totalAssets();
        
        // Rebalance each position
        for (uint256 i = 0; i < portfolioAssets.length; i++) {
            address asset_ = portfolioAssets[i];
            Position storage position = positions[asset_];
            
            uint256 currentValue = _getPositionValue(asset_);
            uint256 newAllocation = (currentValue * BPS) / totalValue;
            
            uint256 oldAmount = position.amount;
            position.amount = currentValue;
            position.allocationPercentage = newAllocation;
            
            emit PositionRebalanced(asset_, oldAmount, position.amount, msg.sender, block.timestamp);
        }
        
        lastRebalanceTimestamp = block.timestamp;
    }
    
    // ============= Dividend & Yield Management =============
    
    /**
     * @notice Record dividend received from position
     * @param svpToken Token that paid dividend
     * @param amount Dividend amount
     */
    function receiveDividend(address svpToken, uint256 amount)
        external
        onlyRole(MANAGER_ROLE)
        whenNotPaused
    {
        require(svpToken != address(0), "SVPSPVVault: Invalid token");
        require(amount > 0, "SVPSPVVault: Amount must be positive");
        
        totalDividendsReceived += amount;
        
        emit DividendReceived(svpToken, amount, block.timestamp);
    }
    
    /**
     * @notice Calculate NAV per share
     * @return NAV per share
     */
    function calculateNAV() public returns (uint256) {
        uint256 totalValue = totalAssets();
        uint256 totalShares = totalSupply();
        
        if (totalShares == 0) return 1e18;
        
        uint256 nav = (totalValue * 1e18) / totalShares;
        
        navHistory.push(nav);
        navTimestamps.push(block.timestamp);
        
        emit NAVCalculated(nav, block.timestamp);
        
        return nav;
    }
    
    /**
     * @notice Collect management and performance fees
     */
    function collectFees()
        external
        onlyRole(ADMIN_ROLE)
        whenNotPaused
        nonReentrant
    {
        uint256 totalValue = totalAssets();
        uint256 timeSinceLastUpdate = block.timestamp - metrics.lastUpdateTimestamp;
        
        // Management fee (annual, calculated daily)
        uint256 managementFee = (totalValue * managementFeePercentage * timeSinceLastUpdate) / (BPS * 365 days);
        
        // Performance fee (on profits)
        uint256 unrealizedGains = metrics.unrealizedGains;
        uint256 performanceFee = (unrealizedGains * performanceFeePercentage) / BPS;
        
        if (managementFee > 0 || performanceFee > 0) {
            IERC20(asset()).transfer(feeRecipient, managementFee + performanceFee);
            metrics.lastUpdateTimestamp = block.timestamp;
            
            emit FeesCollected(managementFee, performanceFee, block.timestamp);
        }
    }
    
    // ============= View Functions =============
    
    /**
     * @notice Get total assets under management
     * @return Total assets
     */
    function totalAssets() public view override returns (uint256) {
        return IERC20(asset()).balanceOf(address(this));
    }
    
    /**
     * @notice Get portfolio asset count
     * @return Number of positions
     */
    function getPortfolioAssetCount() external view returns (uint256) {
        return portfolioAssets.length;
    }
    
    /**
     * @notice Get portfolio asset at index
     * @param index Position index
     * @return Asset address
     */
    function getPortfolioAsset(uint256 index) external view returns (address) {
        require(index < portfolioAssets.length, "SVPSPVVault: Index out of range");
        return portfolioAssets[index];
    }
    
    /**
     * @notice Get position details
     * @param svpToken Token address
     * @return Position data
     */
    function getPosition(address svpToken)
        external
        view
        returns (Position memory)
    {
        return positions[svpToken];
    }
    
    /**
     * @notice Get redemption request details
     * @param redemptionId Request ID
     * @return Redemption request data
     */
    function getRedemptionRequest(uint256 redemptionId)
        external
        view
        returns (RedemptionRequest memory)
    {
        require(redemptionId < redemptionQueue.length, "SVPSPVVault: Invalid ID");
        return redemptionQueue[redemptionId];
    }
    
    /**
     * @notice Get user's redemption requests
     * @param user User address
     * @return Array of redemption IDs
     */
    function getUserRedemptions(address user)
        external
        view
        returns (uint256[] memory)
    {
        return userRedemptions[user];
    }
    
    /**
     * @notice Get performance metrics
     * @return Metrics data
     */
    function getMetrics() external view returns (PerformanceMetrics memory) {
        return metrics;
    }
    
    /**
     * @notice Get NAV history length
     * @return History length
     */
    function getNavHistoryLength() external view returns (uint256) {
        return navHistory.length;
    }
    
    // ============= Internal Helper Functions =============
    
    /**
     * @notice Get SVP token price (placeholder)
     * @param svpToken Token address
     * @return Price in wei
     */
    function _getTokenPrice(address svpToken) internal view returns (uint256) {
        // In production, would call valuation engine
        // For now, return 1e18 as placeholder
        return 1e18;
    }
    
    /**
     * @notice Get position current value
     * @param svpToken Token address
     * @return Current value
     */
    function _getPositionValue(address svpToken) internal view returns (uint256) {
        Position memory position = positions[svpToken];
        uint256 price = _getTokenPrice(svpToken);
        return (position.amount * price) / 1e18;
    }
    
    // ============= Admin Functions =============
    
    /**
     * @notice Update vault parameters
     * @param minDeposit New minimum deposit
     * @param maxAllocation New max allocation per asset
     * @param mgmtFee New management fee
     * @param perfFee New performance fee
     */
    function setParameters(
        uint256 minDeposit,
        uint256 maxAllocation,
        uint256 mgmtFee,
        uint256 perfFee
    )
        external
        onlyRole(ADMIN_ROLE)
    {
        require(minDeposit > 0, "SVPSPVVault: Min deposit must be positive");
        require(maxAllocation <= BPS, "SVPSPVVault: Max allocation exceeds 100%");
        require(mgmtFee <= BPS, "SVPSPVVault: Management fee exceeds 100%");
        require(perfFee <= BPS, "SVPSPVVault: Performance fee exceeds 100%");
        
        minDepositAmount = minDeposit;
        maxAllocationPerAsset = maxAllocation;
        managementFeePercentage = mgmtFee;
        performanceFeePercentage = perfFee;
        
        emit ParametersUpdated(
            minDeposit,
            maxAllocation,
            mgmtFee,
            perfFee,
            msg.sender,
            block.timestamp
        );
    }
    
    /**
     * @notice Pause vault
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpause vault
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}
