// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title SVPDividendDistributor
 * @notice Handles automated dividend/revenue distribution to token holders
 * @dev Pro-rata distribution based on token balance
 * @author Hudu Yusuf (Analys)
 */
contract SVPDividendDistributor is AccessControl, ReentrancyGuard, Pausable {
    // ============= Constants =============
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    
    // ============= Data Structures =============
    
    /// @notice Dividend distribution record
    struct Distribution {
        uint256 id;                    // Distribution ID
        IERC20 rewardToken;            // Token being distributed
        uint256 totalAmount;           // Total amount distributed
        uint256 timestamp;             // Distribution timestamp
        string description;            // Distribution description
    }
    
    /// @notice User dividend claim record
    struct ClaimRecord {
        uint256 amount;                // Amount claimed
        uint256 claimTimestamp;        // When claimed
        uint256 distributionId;        // Which distribution
    }
    
    // ============= State Variables =============
    
    /// @notice SVP token (receives dividends from)
    IERC20 public svpToken;
    
    /// @notice Reward token (distributed to holders)
    IERC20 public rewardToken;
    
    /// @notice Total dividends deposited
    uint256 public totalDividends;
    
    /// @notice Total dividends claimed
    uint256 public totalClaimed;
    
    /// @notice Dividend distributions history
    Distribution[] public distributions;
    
    /// @notice Amount claimed per user per distribution
    mapping(address => mapping(uint256 => ClaimRecord)) public claims;
    
    /// @notice Total claimed per user
    mapping(address => uint256) public userTotalClaimed;
    
    /// @notice Distribution snapshots for voting power
    mapping(uint256 => uint256) public snapshotIdForDistribution;
    
    /// @notice Last distribution timestamp
    uint256 public lastDistributionTimestamp;
    
    /// @notice Minimum distribution amount
    uint256 public minDistributionAmount = 1e18;
    
    /// @notice Distribution frequency (minimum seconds between distributions)
    uint256 public distributionFrequency = 1 weeks;
    
    // ============= Events =============
    
    /// @notice Emitted when dividends are deposited
    event DividendDeposited(
        uint256 indexed distributionId,
        IERC20 indexed rewardToken,
        uint256 amount,
        string description,
        address indexed depositor,
        uint256 timestamp
    );
    
    /// @notice Emitted when dividends are claimed
    event DividendClaimed(
        address indexed claimant,
        uint256 indexed distributionId,
        IERC20 indexed rewardToken,
        uint256 amount,
        uint256 timestamp
    );
    
    /// @notice Emitted when share calculation is completed
    event DistributionCalculated(
        uint256 indexed distributionId,
        uint256 totalShares,
        uint256 sharePerToken,
        uint256 timestamp
    );
    
    /// @notice Emitted when parameters are updated
    event ParametersUpdated(
        uint256 minAmount,
        uint256 frequency,
        address indexed admin,
        uint256 timestamp
    );
    
    /// @notice Emitted when pending rewards are calculated
    event PendingRewardsCalculated(
        address indexed claimant,
        uint256 totalRewards,
        uint256 timestamp
    );
    
    // ============= Constructor =============
    
    /**
     * @notice Initialize dividend distributor
     * @param svpToken_ SVP token address
     * @param rewardToken_ Token to distribute (stablecoin)
     */
    constructor(IERC20 svpToken_, IERC20 rewardToken_) {
        require(address(svpToken_) != address(0), "SVPDividendDistributor: Invalid SVP token");
        require(address(rewardToken_) != address(0), "SVPDividendDistributor: Invalid reward token");
        
        svpToken = svpToken_;
        rewardToken = rewardToken_;
        lastDistributionTimestamp = block.timestamp;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(DISTRIBUTOR_ROLE, msg.sender);
    }
    
    // ============= Dividend Deposit & Distribution =============
    
    /**
     * @notice Deposit dividends for distribution
     * @param amount Amount of reward token to distribute
     * @param description Distribution description
     */
    function depositDividends(uint256 amount, string calldata description)
        external
        onlyRole(DISTRIBUTOR_ROLE)
        whenNotPaused
        nonReentrant
    {
        require(amount >= minDistributionAmount, "SVPDividendDistributor: Amount too small");
        require(
            block.timestamp >= lastDistributionTimestamp + distributionFrequency,
            "SVPDividendDistributor: Distribution frequency exceeded"
        );
        
        // Transfer reward tokens from depositor
        rewardToken.transferFrom(msg.sender, address(this), amount);
        
        // Create distribution record
        uint256 distributionId = distributions.length;
        distributions.push(Distribution({
            id: distributionId,
            rewardToken: rewardToken,
            totalAmount: amount,
            timestamp: block.timestamp,
            description: description
        }));
        
        totalDividends += amount;
        lastDistributionTimestamp = block.timestamp;
        
        // Emit events
        emit DividendDeposited(
            distributionId,
            rewardToken,
            amount,
            description,
            msg.sender,
            block.timestamp
        );
        
        // Calculate share
        uint256 totalSupply = svpToken.totalSupply();
        if (totalSupply > 0) {
            uint256 sharePerToken = (amount * 1e18) / totalSupply;
            emit DistributionCalculated(distributionId, totalSupply, sharePerToken, block.timestamp);
        }
    }
    
    /**
     * @notice Claim dividends for a specific distribution
     * @param distributionId Distribution to claim from
     */
    function claimDividend(uint256 distributionId)
        external
        whenNotPaused
        nonReentrant
    {
        require(distributionId < distributions.length, "SVPDividendDistributor: Invalid distribution ID");
        
        Distribution storage distribution = distributions[distributionId];
        
        // Check if already claimed
        ClaimRecord storage existingClaim = claims[msg.sender][distributionId];
        require(existingClaim.amount == 0, "SVPDividendDistributor: Already claimed");
        
        // Get token balance at distribution time
        uint256 userBalance = _getUserBalanceAtTime(msg.sender, distribution.timestamp);
        require(userBalance > 0, "SVPDividendDistributor: No tokens held at distribution time");
        
        uint256 totalSupply = svpToken.totalSupply();
        require(totalSupply > 0, "SVPDividendDistributor: Invalid total supply");
        
        // Calculate user's share
        uint256 userShare = (distribution.totalAmount * userBalance) / totalSupply;
        require(userShare > 0, "SVPDividendDistributor: No dividends to claim");
        
        // Record claim
        claims[msg.sender][distributionId] = ClaimRecord({
            amount: userShare,
            claimTimestamp: block.timestamp,
            distributionId: distributionId
        });
        
        totalClaimed += userShare;
        userTotalClaimed[msg.sender] += userShare;
        
        // Transfer reward token to claimant
        rewardToken.transfer(msg.sender, userShare);
        
        emit DividendClaimed(
            msg.sender,
            distributionId,
            distribution.rewardToken,
            userShare,
            block.timestamp
        );
    }
    
    /**
     * @notice Claim all available dividends at once
     */
    function claimAllDividends() external whenNotPaused nonReentrant {
        uint256 totalRewards = 0;
        
        for (uint256 i = 0; i < distributions.length; i++) {
            // Check if already claimed
            if (claims[msg.sender][i].amount == 0) {
                Distribution storage distribution = distributions[i];
                
                // Get token balance at distribution time
                uint256 userBalance = _getUserBalanceAtTime(msg.sender, distribution.timestamp);
                if (userBalance > 0) {
                    uint256 totalSupply = svpToken.totalSupply();
                    if (totalSupply > 0) {
                        uint256 userShare = (distribution.totalAmount * userBalance) / totalSupply;
                        if (userShare > 0) {
                            // Record claim
                            claims[msg.sender][i] = ClaimRecord({
                                amount: userShare,
                                claimTimestamp: block.timestamp,
                                distributionId: i
                            });
                            
                            totalRewards += userShare;
                            
                            emit DividendClaimed(
                                msg.sender,
                                i,
                                distribution.rewardToken,
                                userShare,
                                block.timestamp
                            );
                        }
                    }
                }
            }
        }
        
        require(totalRewards > 0, "SVPDividendDistributor: No rewards to claim");
        
        totalClaimed += totalRewards;
        userTotalClaimed[msg.sender] += totalRewards;
        
        // Transfer all rewards
        rewardToken.transfer(msg.sender, totalRewards);
        
        emit PendingRewardsCalculated(msg.sender, totalRewards, block.timestamp);
    }
    
    // ============= View Functions =============
    
    /**
     * @notice Get pending dividends for a user
     * @param claimant User address
     * @return totalPending Total pending dividends
     */
    function getPendingDividends(address claimant)
        external
        view
        returns (uint256 totalPending)
    {
        for (uint256 i = 0; i < distributions.length; i++) {
            // Check if already claimed
            if (claims[claimant][i].amount == 0) {
                Distribution storage distribution = distributions[i];
                
                uint256 userBalance = _getUserBalanceAtTime(claimant, distribution.timestamp);
                if (userBalance > 0) {
                    uint256 totalSupply = svpToken.totalSupply();
                    if (totalSupply > 0) {
                        uint256 userShare = (distribution.totalAmount * userBalance) / totalSupply;
                        totalPending += userShare;
                    }
                }
            }
        }
    }
    
    /**
     * @notice Get pending dividend for specific distribution
     * @param claimant User address
     * @param distributionId Distribution ID
     * @return Pending amount
     */
    function getPendingDividendForDistribution(address claimant, uint256 distributionId)
        external
        view
        returns (uint256)
    {
        require(distributionId < distributions.length, "SVPDividendDistributor: Invalid distribution ID");
        
        if (claims[claimant][distributionId].amount > 0) {
            return 0; // Already claimed
        }
        
        Distribution storage distribution = distributions[distributionId];
        uint256 userBalance = _getUserBalanceAtTime(claimant, distribution.timestamp);
        
        if (userBalance == 0) return 0;
        
        uint256 totalSupply = svpToken.totalSupply();
        if (totalSupply == 0) return 0;
        
        return (distribution.totalAmount * userBalance) / totalSupply;
    }
    
    /**
     * @notice Get distribution count
     * @return Number of distributions
     */
    function getDistributionCount() external view returns (uint256) {
        return distributions.length;
    }
    
    /**
     * @notice Get distribution details
     * @param distributionId Distribution ID
     * @return Distribution data
     */
    function getDistribution(uint256 distributionId)
        external
        view
        returns (Distribution memory)
    {
        require(distributionId < distributions.length, "SVPDividendDistributor: Invalid distribution ID");
        return distributions[distributionId];
    }
    
    /**
     * @notice Get user's total claimed dividends
     * @param claimant User address
     * @return Total amount claimed
     */
    function getUserTotalClaimed(address claimant) external view returns (uint256) {
        return userTotalClaimed[claimant];
    }
    
    /**
     * @notice Get claim record
     * @param claimant User address
     * @param distributionId Distribution ID
     * @return Claim record
     */
    function getClaimRecord(address claimant, uint256 distributionId)
        external
        view
        returns (ClaimRecord memory)
    {
        return claims[claimant][distributionId];
    }
    
    /**
     * @notice Check if dividend was claimed
     * @param claimant User address
     * @param distributionId Distribution ID
     * @return True if claimed
     */
    function hasClaimed(address claimant, uint256 distributionId) external view returns (bool) {
        return claims[claimant][distributionId].amount > 0;
    }
    
    // ============= Admin Functions =============
    
    /**
     * @notice Update distribution parameters
     * @param minAmount New minimum distribution amount
     * @param frequency New distribution frequency
     */
    function setParameters(uint256 minAmount, uint256 frequency)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(minAmount > 0, "SVPDividendDistributor: Min amount must be positive");
        require(frequency > 0, "SVPDividendDistributor: Frequency must be positive");
        
        minDistributionAmount = minAmount;
        distributionFrequency = frequency;
        
        emit ParametersUpdated(minAmount, frequency, msg.sender, block.timestamp);
    }
    
    /**
     * @notice Pause distribution
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpause distribution
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    
    /**
     * @notice Recover accidentally sent tokens
     * @param token Token to recover
     * @param amount Amount to recover
     */
    function recoverToken(IERC20 token, uint256 amount)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(address(token) != address(rewardToken), "SVPDividendDistributor: Cannot recover reward token");
        token.transfer(msg.sender, amount);
    }
    
    // ============= Internal Helper Functions =============
    
    /**
     * @notice Get user's token balance at specific timestamp
     * @param user User address
     * @param timestamp Timestamp to check
     * @return Balance at timestamp
     */
    function _getUserBalanceAtTime(address user, uint256 timestamp)
        internal
        view
        returns (uint256)
    {
        // In production, would use snapshot mechanism
        // For now, return current balance as placeholder
        return _getTokenBalance(user);
    }
    
    /**
     * @notice Get user's current token balance
     * @param user User address
     * @return Current balance
     */
    function _getTokenBalance(address user) internal view returns (uint256) {
        (bool success, bytes memory result) = address(svpToken).staticcall(
            abi.encodeWithSignature("balanceOf(address)", user)
        );
        if (!success || result.length == 0) return 0;
        return abi.decode(result, (uint256));
    }
}
