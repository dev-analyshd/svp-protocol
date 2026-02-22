// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title DividendDistributor
 * @notice Manages automated dividend distribution to token holders
 * @dev Tracks dividend distributions per holder, supports multiple dividend types
 * @author Hudu Yusuf (Analys)
 */
contract DividendDistributor is AccessControl, ReentrancyGuard, Pausable {
    // ============= Constants & Roles =============
    
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    bytes32 public constant PAYMENT_ROLE = keccak256("PAYMENT_ROLE");
    
    // ============= Data Structures =============
    
    struct DividendRecord {
        uint256 amount;
        uint256 timestamp;
        address token;
        uint256 blockNumber;
        uint256 totalHolders;
        string description;
        bool claimed;
    }
    
    struct HolderDividends {
        uint256 totalEarned;
        uint256 totalClaimed;
        uint256 pendingClaim;
        uint256 lastClaimBlock;
        uint256 claimCount;
    }
    
    struct DividendPool {
        uint256 totalAllocated;
        uint256 totalClaimed;
        address paymentToken;
        uint256 createdAt;
        bool active;
        string name;
    }
    
    struct ClaimHistory {
        uint256 amount;
        uint256 timestamp;
        address token;
        uint256 poolId;
    }
    
    // ============= State Variables =============
    
    mapping(uint256 => DividendRecord) public dividendRecords;  // dividendId => record
    mapping(address => HolderDividends) public holderDividends;  // holder => dividends
    mapping(uint256 => DividendPool) public dividendPools;  // poolId => pool
    mapping(address => mapping(uint256 => uint256)) public holderPoolShare;  // holder => poolId => amount
    mapping(address => ClaimHistory[]) public claimHistory;  // holder => claim history array
    
    address[] public registeredHolders;
    mapping(address => bool) public isRegisteredHolder;
    
    uint256 public totalDividendsPaid;
    uint256 public totalDistributions;
    uint256 public currentPoolId;
    uint256 public currentDividendId;
    
    address public masterToken;  // Primary dividend token
    uint256 public minimumClaimAmount;
    uint256 public claimFrequencyDays;
    
    // ============= Events =============
    
    event DividendDistributed(
        uint256 indexed dividendId,
        uint256 amount,
        address indexed token,
        uint256 holderCount,
        uint256 timestamp
    );
    
    event DividendClaimed(
        address indexed holder,
        uint256 amount,
        address indexed token,
        uint256 timestamp
    );
    
    event HolderRegistered(
        address indexed holder,
        uint256 timestamp
    );
    
    event HolderUnregistered(
        address indexed holder,
        uint256 timestamp
    );
    
    event DividendPoolCreated(
        uint256 indexed poolId,
        address indexed paymentToken,
        string name,
        uint256 timestamp
    );
    
    event PoolAllocated(
        uint256 indexed poolId,
        uint256 totalAmount,
        uint256 holderCount,
        uint256 timestamp
    );
    
    event PerformanceDividendIssued(
        address indexed holder,
        uint256 amount,
        uint256 performanceScore,
        uint256 timestamp
    );
    
    event MinimumClaimUpdated(
        uint256 oldMinimum,
        uint256 newMinimum,
        uint256 timestamp
    );
    
    // ============= Constructor =============
    
    constructor(address _masterToken) {
        require(_masterToken != address(0), "DividendDistributor: Invalid token");
        
        masterToken = _masterToken;
        minimumClaimAmount = 1e6;  // 1 token in base units
        claimFrequencyDays = 1;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DISTRIBUTOR_ROLE, msg.sender);
        _grantRole(PAYMENT_ROLE, msg.sender);
    }
    
    // ============= Holder Management =============
    
    /// @notice Register holder for dividend eligibility
    function registerHolder(address holder) external onlyRole(DISTRIBUTOR_ROLE) {
        require(holder != address(0), "DividendDistributor: Invalid holder");
        require(!isRegisteredHolder[holder], "DividendDistributor: Already registered");
        
        isRegisteredHolder[holder] = true;
        registeredHolders.push(holder);
        
        emit HolderRegistered(holder, block.timestamp);
    }
    
    /// @notice Unregister holder
    function unregisterHolder(address holder) external onlyRole(DISTRIBUTOR_ROLE) {
        require(isRegisteredHolder[holder], "DividendDistributor: Not registered");
        
        isRegisteredHolder[holder] = false;
        
        emit HolderUnregistered(holder, block.timestamp);
    }
    
    /// @notice Register multiple holders (batch)
    function registerHoldersBatch(address[] calldata holders) external onlyRole(DISTRIBUTOR_ROLE) {
        for (uint256 i = 0; i < holders.length; i++) {
            if (!isRegisteredHolder[holders[i]] && holders[i] != address(0)) {
                isRegisteredHolder[holders[i]] = true;
                registeredHolders.push(holders[i]);
                emit HolderRegistered(holders[i], block.timestamp);
            }
        }
    }
    
    // ============= Dividend Pool Management =============
    
    /// @notice Create new dividend pool
    function createDividendPool(
        address paymentToken,
        string memory name
    ) external onlyRole(DISTRIBUTOR_ROLE) returns (uint256 poolId) {
        require(paymentToken != address(0), "DividendDistributor: Invalid token");
        
        poolId = currentPoolId++;
        dividendPools[poolId] = DividendPool({
            totalAllocated: 0,
            totalClaimed: 0,
            paymentToken: paymentToken,
            createdAt: block.timestamp,
            active: true,
            name: name
        });
        
        emit DividendPoolCreated(poolId, paymentToken, name, block.timestamp);
        return poolId;
    }
    
    /// @notice Allocate dividends equally to all registered holders
    function allocateDividendPool(
        uint256 poolId,
        uint256 totalAmount
    ) external onlyRole(PAYMENT_ROLE) nonReentrant {
        require(poolId < currentPoolId, "DividendDistributor: Invalid pool");
        require(totalAmount > 0, "DividendDistributor: Invalid amount");
        DividendPool storage pool = dividendPools[poolId];
        require(pool.active, "DividendDistributor: Pool inactive");
        require(registeredHolders.length > 0, "DividendDistributor: No holders");
        
        uint256 amountPerHolder = totalAmount / registeredHolders.length;
        require(amountPerHolder > 0, "DividendDistributor: Amount too small");
        
        // Transfer tokens from sender to this contract
        IERC20(pool.paymentToken).transferFrom(msg.sender, address(this), totalAmount);
        
        // Allocate to each holder
        for (uint256 i = 0; i < registeredHolders.length; i++) {
            address holder = registeredHolders[i];
            holderPoolShare[holder][poolId] += amountPerHolder;
            holderDividends[holder].pendingClaim += amountPerHolder;
        }
        
        pool.totalAllocated += totalAmount;
        totalDividendsPaid += totalAmount;
        totalDistributions++;
        
        emit PoolAllocated(poolId, totalAmount, registeredHolders.length, block.timestamp);
    }
    
    /// @notice Allocate dividends proportionally based on voting power
    function allocateProportionalDividends(
        uint256 poolId,
        uint256 totalAmount,
        address[] calldata holders,
        uint256[] calldata votingPowers
    ) external onlyRole(PAYMENT_ROLE) nonReentrant {
        require(poolId < currentPoolId, "DividendDistributor: Invalid pool");
        require(totalAmount > 0, "DividendDistributor: Invalid amount");
        require(holders.length == votingPowers.length, "DividendDistributor: Length mismatch");
        
        DividendPool storage pool = dividendPools[poolId];
        require(pool.active, "DividendDistributor: Pool inactive");
        
        // Transfer tokens
        IERC20(pool.paymentToken).transferFrom(msg.sender, address(this), totalAmount);
        
        // Calculate total voting power
        uint256 totalVotingPower = 0;
        for (uint256 i = 0; i < votingPowers.length; i++) {
            totalVotingPower += votingPowers[i];
        }
        require(totalVotingPower > 0, "DividendDistributor: No voting power");
        
        // Allocate proportionally
        for (uint256 i = 0; i < holders.length; i++) {
            if (isRegisteredHolder[holders[i]]) {
                uint256 allocation = (totalAmount * votingPowers[i]) / totalVotingPower;
                holderPoolShare[holders[i]][poolId] += allocation;
                holderDividends[holders[i]].pendingClaim += allocation;
            }
        }
        
        pool.totalAllocated += totalAmount;
        totalDividendsPaid += totalAmount;
        totalDistributions++;
        
        emit PoolAllocated(poolId, totalAmount, holders.length, block.timestamp);
    }
    
    // ============= Dividend Claims =============
    
    /// @notice Claim pending dividends
    function claimDividends(uint256[] calldata poolIds)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 totalClaimed)
    {
        require(poolIds.length > 0, "DividendDistributor: No pools specified");
        require(isRegisteredHolder[msg.sender], "DividendDistributor: Not registered");
        
        uint256 pendingAmount = 0;
        address[] memory tokensToTransfer = new address[](poolIds.length);
        
        for (uint256 i = 0; i < poolIds.length; i++) {
            uint256 poolId = poolIds[i];
            require(poolId < currentPoolId, "DividendDistributor: Invalid pool");
            
            uint256 claimAmount = holderPoolShare[msg.sender][poolId];
            if (claimAmount > 0 && claimAmount >= minimumClaimAmount) {
                pendingAmount += claimAmount;
                tokensToTransfer[i] = dividendPools[poolId].paymentToken;
                holderPoolShare[msg.sender][poolId] = 0;
                dividendPools[poolId].totalClaimed += claimAmount;
            }
        }
        
        require(pendingAmount >= minimumClaimAmount, "DividendDistributor: Below minimum");
        
        // Update holder record
        HolderDividends storage hd = holderDividends[msg.sender];
        hd.totalClaimed += pendingAmount;
        hd.pendingClaim = 0;
        hd.lastClaimBlock = block.number;
        hd.claimCount++;
        
        // Record claim history (using primary token for record)
        claimHistory[msg.sender].push(ClaimHistory({
            amount: pendingAmount,
            timestamp: block.timestamp,
            token: masterToken,
            poolId: poolIds[0]
        }));
        
        // Transfer tokens
        for (uint256 i = 0; i < poolIds.length; i++) {
            uint256 claimAmount = holderPoolShare[msg.sender][poolIds[i]];
            if (claimAmount > 0) {
                IERC20(tokensToTransfer[i]).transfer(msg.sender, claimAmount);
                emit DividendClaimed(msg.sender, claimAmount, tokensToTransfer[i], block.timestamp);
            }
        }
        
        totalDividendsPaid += pendingAmount;
        return pendingAmount;
    }
    
    /// @notice Claim from single pool
    function claimFromPool(uint256 poolId)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 claimedAmount)
    {
        require(poolId < currentPoolId, "DividendDistributor: Invalid pool");
        require(isRegisteredHolder[msg.sender], "DividendDistributor: Not registered");
        
        claimedAmount = holderPoolShare[msg.sender][poolId];
        require(claimedAmount >= minimumClaimAmount, "DividendDistributor: Below minimum");
        
        holderPoolShare[msg.sender][poolId] = 0;
        
        HolderDividends storage hd = holderDividends[msg.sender];
        hd.totalClaimed += claimedAmount;
        hd.pendingClaim -= claimedAmount;
        hd.lastClaimBlock = block.number;
        hd.claimCount++;
        
        DividendPool storage pool = dividendPools[poolId];
        pool.totalClaimed += claimedAmount;
        
        claimHistory[msg.sender].push(ClaimHistory({
            amount: claimedAmount,
            timestamp: block.timestamp,
            token: pool.paymentToken,
            poolId: poolId
        }));
        
        IERC20(pool.paymentToken).transfer(msg.sender, claimedAmount);
        
        emit DividendClaimed(msg.sender, claimedAmount, pool.paymentToken, block.timestamp);
        return claimedAmount;
    }
    
    // ============= Performance Dividends =============
    
    /// @notice Issue performance-based dividend bonus
    function issuePerformanceDividend(
        address holder,
        uint256 amount,
        uint256 performanceScore
    ) external onlyRole(PAYMENT_ROLE) nonReentrant {
        require(holder != address(0), "DividendDistributor: Invalid holder");
        require(amount > 0, "DividendDistributor: Invalid amount");
        require(isRegisteredHolder[holder], "DividendDistributor: Not registered");
        
        // Create temporary pool for performance dividend
        uint256 poolId = currentPoolId++;
        dividendPools[poolId] = DividendPool({
            totalAllocated: amount,
            totalClaimed: 0,
            paymentToken: masterToken,
            createdAt: block.timestamp,
            active: true,
            name: "Performance Dividend"
        });
        
        holderPoolShare[holder][poolId] = amount;
        holderDividends[holder].pendingClaim += amount;
        holderDividends[holder].totalEarned += amount;
        
        // Transfer from caller to contract
        IERC20(masterToken).transferFrom(msg.sender, address(this), amount);
        
        emit PerformanceDividendIssued(holder, amount, performanceScore, block.timestamp);
    }
    
    // ============= View Functions =============
    
    /// @notice Get holder's pending dividend amount
    function getPendingDividends(address holder) external view returns (uint256) {
        return holderDividends[holder].pendingClaim;
    }
    
    /// @notice Get holder's claim history
    function getClaimHistory(address holder) external view returns (ClaimHistory[] memory) {
        return claimHistory[holder];
    }
    
    /// @notice Get holder's total earned dividends
    function getTotalEarned(address holder) external view returns (uint256) {
        return holderDividends[holder].totalEarned;
    }
    
    /// @notice Get holder's total claimed dividends
    function getTotalClaimed(address holder) external view returns (uint256) {
        return holderDividends[holder].totalClaimed;
    }
    
    /// @notice Get registered holders count
    function getHolderCount() external view returns (uint256) {
        return registeredHolders.length;
    }
    
    /// @notice Get all registered holders
    function getRegisteredHolders() external view returns (address[] memory) {
        return registeredHolders;
    }
    
    /// @notice Get pool details
    function getPoolDetails(uint256 poolId) 
        external 
        view 
        returns (DividendPool memory) 
    {
        require(poolId < currentPoolId, "DividendDistributor: Invalid pool");
        return dividendPools[poolId];
    }
    
    /// @notice Get holder's share in specific pool
    function getPoolShare(address holder, uint256 poolId) external view returns (uint256) {
        return holderPoolShare[holder][poolId];
    }
    
    // ============= Admin Functions =============
    
    /// @notice Update minimum claim amount
    function setMinimumClaimAmount(uint256 newMinimum) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newMinimum > 0, "DividendDistributor: Invalid minimum");
        uint256 oldMinimum = minimumClaimAmount;
        minimumClaimAmount = newMinimum;
        
        emit MinimumClaimUpdated(oldMinimum, newMinimum, block.timestamp);
    }
    
    /// @notice Pause/unpause dividend claims
    function pauseDistribution() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    /// @notice Unpause dividend claims
    function unpauseDistribution() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    /// @notice Deactivate pool (prevent new allocations)
    function deactivatePool(uint256 poolId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(poolId < currentPoolId, "DividendDistributor: Invalid pool");
        dividendPools[poolId].active = false;
    }
}
