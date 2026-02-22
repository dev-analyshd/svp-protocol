// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title EnhancedDividendTracker
 * @notice Advanced dividend tracking with multi-asset support and claim history
 * @dev Tracks pending dividends, claims, and historical distributions
 * @author Hudu Yusuf (Analys)
 */
contract EnhancedDividendTracker is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    
    // ============= Constants & Roles =============
    
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    bytes32 public constant CLAIM_PROCESSOR_ROLE = keccak256("CLAIM_PROCESSOR_ROLE");
    
    uint256 public constant BASIS_POINTS = 10000;
    
    // ============= Data Structures =============
    
    enum DividendType {
        STANDARD,
        PERFORMANCE,
        BONUS,
        EMERGENCY
    }
    
    struct DividendAllocation {
        address token;
        uint256 totalAmount;
        uint256 claimedAmount;
        uint256 unclaimedAmount;
        uint256 holderCount;
        uint256 createdBlock;
        uint256 createdTimestamp;
        DividendType divType;
        bool isFinal;
    }
    
    struct HolderDividend {
        address token;
        uint256 amount;
        uint256 claimedAmount;
        uint256 unclaimedAmount;
        uint256 claimsCount;
        uint256 firstClaimTime;
        uint256 lastClaimTime;
        bool isPerformanceDividend;
    }
    
    struct ClaimRecord {
        address holder;
        address token;
        uint256 amount;
        uint256 allocationId;
        uint256 claimTime;
        bytes claimProof;
    }
    
    struct AllocationSnapshot {
        uint256 allocationId;
        uint256 totalHolders;
        uint256 totalAmount;
        address[] topClaimers;  // Top 10 claimers
        uint256[] topAmounts;   // Corresponding amounts
        uint256 snapshotTime;
    }
    
    struct HolderSnapshot {
        address holder;
        uint256 dividendBalance;
        uint256 historicalClaimed;
        uint256 lastUpdateBlock;
        uint256 claimStreak;  // Consecutive periods claimed
    }
    
    // ============= State Variables =============
    
    mapping(uint256 => DividendAllocation) public allocations;  // allocationId => data
    mapping(address => mapping(uint256 => HolderDividend)) public holderDividends;  // holder => allocationId => data
    mapping(address => ClaimRecord[]) public claimHistory;  // holder => claims
    mapping(address => HolderSnapshot) public holderSnapshots;
    
    mapping(address => uint256) public pendingClaims;  // holder => total pending
    mapping(address => uint256) public totalClaimed;   // holder => total ever claimed
    mapping(address => uint256) public claimCount;     // holder => number of claims
    
    uint256 public allocationCounter;
    uint256 public totalAllocatedValue;
    uint256 public totalDistributedValue;
    
    address[] public trackedTokens;
    mapping(address => bool) public isTrackedToken;
    
    uint256 public minClaimAmount;  // Minimum amount to claim
    uint256 public claimFeePercentageBPS;  // Fee percentage for claims
    address public feeRecipient;
    
    // ============= Events =============
    
    event AllocationCreated(
        uint256 indexed allocationId,
        address indexed token,
        uint256 totalAmount,
        uint256 holderCount,
        DividendType divType,
        uint256 timestamp
    );
    
    event AllocationFinalized(
        uint256 indexed allocationId,
        uint256 totalClaimed,
        uint256 totalUnclaimed,
        uint256 claimRate,
        uint256 timestamp
    );
    
    event DividendRecorded(
        address indexed holder,
        uint256 indexed allocationId,
        address indexed token,
        uint256 amount,
        uint256 timestamp
    );
    
    event DividendClaimed(
        address indexed holder,
        uint256 indexed allocationId,
        address indexed token,
        uint256 amount,
        uint256 fee,
        uint256 netAmount,
        uint256 timestamp
    );
    
    event TokenTracked(address indexed token, uint256 timestamp);
    event TokenUntracked(address indexed token, uint256 timestamp);
    
    event MinClaimAmountUpdated(uint256 oldAmount, uint256 newAmount, uint256 timestamp);
    event ClaimFeeUpdated(uint256 oldFee, uint256 newFee, uint256 timestamp);
    
    event SnapshotCreated(
        uint256 indexed allocationId,
        uint256 totalHolders,
        uint256 totalAmount,
        uint256 timestamp
    );
    
    event ClaimStreakUpdated(
        address indexed holder,
        uint256 newStreak,
        uint256 timestamp
    );
    
    // ============= Constructor =============
    
    constructor() {
        minClaimAmount = 1e17;  // 0.1 tokens
        claimFeePercentageBPS = 50;  // 0.5%
        feeRecipient = msg.sender;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DISTRIBUTOR_ROLE, msg.sender);
        _grantRole(CLAIM_PROCESSOR_ROLE, msg.sender);
    }
    
    // ============= Allocation Management =============
    
    /// @notice Create a new dividend allocation
    function createAllocation(
        address token,
        uint256 totalAmount,
        address[] calldata holders,
        uint256[] calldata amounts,
        DividendType divType
    ) 
        external 
        onlyRole(DISTRIBUTOR_ROLE) 
        returns (uint256 allocationId) 
    {
        require(token != address(0), "EnhancedDividendTracker: Invalid token");
        require(totalAmount > 0, "EnhancedDividendTracker: Zero amount");
        require(holders.length == amounts.length, "EnhancedDividendTracker: Length mismatch");
        require(holders.length > 0, "EnhancedDividendTracker: No holders");
        
        allocationId = allocationCounter++;
        
        DividendAllocation storage allocation = allocations[allocationId];
        allocation.token = token;
        allocation.totalAmount = totalAmount;
        allocation.holderCount = holders.length;
        allocation.createdBlock = block.number;
        allocation.createdTimestamp = block.timestamp;
        allocation.divType = divType;
        allocation.isFinal = false;
        allocation.unclaimedAmount = totalAmount;
        
        // Record dividends for each holder
        uint256 totalAmountCheck = 0;
        for (uint256 i = 0; i < holders.length; i++) {
            require(holders[i] != address(0), "EnhancedDividendTracker: Invalid holder");
            require(amounts[i] > 0, "EnhancedDividendTracker: Zero amount");
            
            holderDividends[holders[i]][allocationId] = HolderDividend({
                token: token,
                amount: amounts[i],
                claimedAmount: 0,
                unclaimedAmount: amounts[i],
                claimsCount: 0,
                firstClaimTime: 0,
                lastClaimTime: 0,
                isPerformanceDividend: divType == DividendType.PERFORMANCE
            });
            
            pendingClaims[holders[i]] += amounts[i];
            totalAmountCheck += amounts[i];
            
            emit DividendRecorded(holders[i], allocationId, token, amounts[i], block.timestamp);
        }
        
        require(totalAmountCheck == totalAmount, "EnhancedDividendTracker: Amount mismatch");
        
        // Track token if not already tracked
        if (!isTrackedToken[token]) {
            trackedTokens.push(token);
            isTrackedToken[token] = true;
            emit TokenTracked(token, block.timestamp);
        }
        
        totalAllocatedValue += totalAmount;
        
        emit AllocationCreated(
            allocationId,
            token,
            totalAmount,
            holders.length,
            divType,
            block.timestamp
        );
        
        return allocationId;
    }
    
    /// @notice Get allocation data
    function getAllocation(uint256 allocationId) 
        external 
        view 
        returns (DividendAllocation memory) 
    {
        return allocations[allocationId];
    }
    
    // ============= Claiming =============
    
    /// @notice Claim dividends from allocation
    function claimDividend(uint256 allocationId) 
        public
        nonReentrant 
        whenNotPaused 
        returns (uint256 netAmount) 
    {
        HolderDividend storage hd = holderDividends[msg.sender][allocationId];
        require(hd.amount > 0, "EnhancedDividendTracker: No dividend");
        require(hd.unclaimedAmount > 0, "EnhancedDividendTracker: Already claimed");
        
        address token = hd.token;
        uint256 amount = hd.unclaimedAmount;
        require(amount >= minClaimAmount, "EnhancedDividendTracker: Below minimum");
        
        // Calculate fee
        uint256 fee = (amount * claimFeePercentageBPS) / BASIS_POINTS;
        netAmount = amount - fee;
        
        // Update holder dividend
        hd.claimedAmount += amount;
        hd.unclaimedAmount = 0;
        hd.claimsCount++;
        if (hd.firstClaimTime == 0) {
            hd.firstClaimTime = block.timestamp;
        }
        hd.lastClaimTime = block.timestamp;
        
        // Update global tracking
        pendingClaims[msg.sender] -= amount;
        totalClaimed[msg.sender] += amount;
        claimCount[msg.sender]++;
        totalDistributedValue += netAmount;
        
        // Update allocation
        allocations[allocationId].claimedAmount += amount;
        allocations[allocationId].unclaimedAmount -= amount;
        
        // Update snapshot
        HolderSnapshot storage hs = holderSnapshots[msg.sender];
        hs.holder = msg.sender;
        hs.dividendBalance += netAmount;
        hs.historicalClaimed += amount;
        hs.lastUpdateBlock = block.number;
        hs.claimStreak++;
        
        // Record claim
        claimHistory[msg.sender].push(ClaimRecord({
            holder: msg.sender,
            token: token,
            amount: netAmount,
            allocationId: allocationId,
            claimTime: block.timestamp,
            claimProof: ""
        }));
        
        // Transfer tokens
        if (fee > 0) {
            IERC20(token).safeTransfer(feeRecipient, fee);
        }
        IERC20(token).safeTransfer(msg.sender, netAmount);
        
        emit DividendClaimed(
            msg.sender,
            allocationId,
            token,
            amount,
            fee,
            netAmount,
            block.timestamp
        );
        
        emit ClaimStreakUpdated(msg.sender, hs.claimStreak, block.timestamp);
        
        return netAmount;
    }
    
    /// @notice Claim multiple dividends at once
    function claimMultipleDividends(uint256[] calldata allocationIds) 
        external 
        nonReentrant 
        whenNotPaused 
        returns (uint256 totalNetAmount) 
    {
        require(allocationIds.length > 0, "EnhancedDividendTracker: No allocations");
        
        for (uint256 i = 0; i < allocationIds.length; i++) {
            HolderDividend storage hd = holderDividends[msg.sender][allocationIds[i]];
            if (hd.unclaimedAmount > 0 && hd.unclaimedAmount >= minClaimAmount) {
                // Process claim directly without recursing through claimDividend to avoid reentrancy
                address token = hd.token;
                uint256 amount = hd.unclaimedAmount;
                
                // Calculate fee
                uint256 fee = (amount * claimFeePercentageBPS) / BASIS_POINTS;
                uint256 netAmount = amount - fee;
                
                // Update holder dividend
                hd.claimedAmount += amount;
                hd.unclaimedAmount = 0;
                hd.claimsCount++;
                if (hd.firstClaimTime == 0) {
                    hd.firstClaimTime = block.timestamp;
                }
                hd.lastClaimTime = block.timestamp;
                
                // Update global tracking
                pendingClaims[msg.sender] -= amount;
                totalClaimed[msg.sender] += amount;
                claimCount[msg.sender]++;
                totalDistributedValue += netAmount;
                
                // Update allocation
                allocations[allocationIds[i]].claimedAmount += amount;
                allocations[allocationIds[i]].unclaimedAmount -= amount;
                
                // Update snapshot
                HolderSnapshot storage hs = holderSnapshots[msg.sender];
                hs.holder = msg.sender;
                hs.dividendBalance += netAmount;
                hs.historicalClaimed += amount;
                hs.lastUpdateBlock = block.number;
                hs.claimStreak++;
                
                // Record claim
                claimHistory[msg.sender].push(ClaimRecord({
                    holder: msg.sender,
                    token: token,
                    amount: netAmount,
                    allocationId: allocationIds[i],
                    claimTime: block.timestamp,
                    claimProof: ""
                }));
                
                // Transfer tokens
                if (fee > 0) {
                    IERC20(token).safeTransfer(feeRecipient, fee);
                }
                IERC20(token).safeTransfer(msg.sender, netAmount);
                
                totalNetAmount += netAmount;
                
                emit DividendClaimed(
                    msg.sender,
                    allocationIds[i],
                    token,
                    amount,
                    fee,
                    netAmount,
                    block.timestamp
                );
            }
        }
        
        require(totalNetAmount > 0, "EnhancedDividendTracker: No valid claims");
        
        // Update claim streak once
        HolderSnapshot storage finalSnapshot = holderSnapshots[msg.sender];
        emit ClaimStreakUpdated(msg.sender, finalSnapshot.claimStreak, block.timestamp);
        
        return totalNetAmount;
    }
    
    // ============= Query Functions =============
    
    /// @notice Get pending dividend for holder in allocation
    function getPendingDividend(address holder, uint256 allocationId) 
        external 
        view 
        returns (uint256) 
    {
        return holderDividends[holder][allocationId].unclaimedAmount;
    }
    
    /// @notice Get total pending dividends for holder
    function getTotalPendingDividends(address holder) external view returns (uint256) {
        return pendingClaims[holder];
    }
    
    /// @notice Get total claimed by holder
    function getTotalClaimedByHolder(address holder) external view returns (uint256) {
        return totalClaimed[holder];
    }
    
    /// @notice Get claim count for holder
    function getClaimCountByHolder(address holder) external view returns (uint256) {
        return claimCount[holder];
    }
    
    /// @notice Get claim history for holder
    function getClaimHistory(address holder) 
        external 
        view 
        returns (ClaimRecord[] memory) 
    {
        return claimHistory[holder];
    }
    
    /// @notice Get holder snapshot
    function getHolderSnapshot(address holder) 
        external 
        view 
        returns (HolderSnapshot memory) 
    {
        return holderSnapshots[holder];
    }
    
    /// @notice Get tracked tokens
    function getTrackedTokens() external view returns (address[] memory) {
        return trackedTokens;
    }
    
    /// @notice Get allocation statistics
    function getAllocationStats(uint256 allocationId) 
        external 
        view 
        returns (
            uint256 totalAmount,
            uint256 claimedAmount,
            uint256 unclaimedAmount,
            uint256 claimPercentage,
            uint256 holderCount
        ) 
    {
        DividendAllocation storage da = allocations[allocationId];
        totalAmount = da.totalAmount;
        claimedAmount = da.claimedAmount;
        unclaimedAmount = da.unclaimedAmount;
        claimPercentage = totalAmount > 0 ? (claimedAmount * 10000) / totalAmount : 0;
        holderCount = da.holderCount;
    }
    
    // ============= Admin Functions =============
    
    /// @notice Finalize an allocation (no more changes)
    function finalizeAllocation(uint256 allocationId) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        DividendAllocation storage allocation = allocations[allocationId];
        require(!allocation.isFinal, "EnhancedDividendTracker: Already finalized");
        
        allocation.isFinal = true;
        
        uint256 claimRate = allocation.totalAmount > 0 
            ? (allocation.claimedAmount * BASIS_POINTS) / allocation.totalAmount 
            : 0;
        
        emit AllocationFinalized(
            allocationId,
            allocation.claimedAmount,
            allocation.unclaimedAmount,
            claimRate,
            block.timestamp
        );
    }
    
    /// @notice Set minimum claim amount
    function setMinClaimAmount(uint256 newMinAmount) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(newMinAmount > 0, "EnhancedDividendTracker: Invalid amount");
        uint256 oldAmount = minClaimAmount;
        minClaimAmount = newMinAmount;
        
        emit MinClaimAmountUpdated(oldAmount, newMinAmount, block.timestamp);
    }
    
    /// @notice Set claim fee percentage
    function setClaimFeePercentage(uint256 newFeeBPS) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(newFeeBPS < BASIS_POINTS, "EnhancedDividendTracker: Invalid fee");
        uint256 oldFee = claimFeePercentageBPS;
        claimFeePercentageBPS = newFeeBPS;
        
        emit ClaimFeeUpdated(oldFee, newFeeBPS, block.timestamp);
    }
    
    /// @notice Set fee recipient
    function setFeeRecipient(address newRecipient) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(newRecipient != address(0), "EnhancedDividendTracker: Invalid recipient");
        feeRecipient = newRecipient;
    }
    
    /// @notice Pause claims
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    /// @notice Unpause claims
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
