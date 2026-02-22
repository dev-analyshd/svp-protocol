// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title GovernanceTokenSnapshot
 * @notice Manages voting power snapshots for governance proposals
 * @dev Tracks historical voting power at specific block numbers
 * @author Hudu Yusuf (Analys)
 */
contract GovernanceTokenSnapshot is AccessControl {
    // ============= Constants & Roles =============
    
    bytes32 public constant SNAPSHOT_ADMIN_ROLE = keccak256("SNAPSHOT_ADMIN_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    
    // ============= Data Structures =============
    
    struct VotingSnapshot {
        uint256 blockNumber;
        uint256 timestamp;
        uint256 totalVotingPower;
        uint256 proposalId;
        bool finalized;
    }
    
    struct UserSnapshot {
        uint256 blockNumber;
        uint256 votingPower;
        uint256 balance;
        uint256 intrinsicValue;
    }
    
    struct SnapshotMetrics {
        uint256 totalSnapshots;
        uint256 activeSnapshots;
        uint256 finalizedSnapshots;
        uint256 lastSnapshotBlock;
        uint256 lastSnapshotTime;
    }
    
    struct ProposalSnapshot {
        uint256 proposalId;
        uint256 blockNumber;
        uint256 totalVotingPower;
        uint256 quorumRequired;
        mapping(address => UserSnapshot) userSnapshots;
        address[] snapshotParticipants;
    }
    
    // ============= State Variables =============
    
    mapping(uint256 => VotingSnapshot) public votingSnapshots;  // snapshotId => snapshot
    mapping(uint256 => ProposalSnapshot) public proposalSnapshots;  // proposalId => snapshot
    mapping(address => mapping(uint256 => UserSnapshot)) public userSnapshots;  // user => blockNumber => snapshot
    mapping(uint256 => uint256[]) public snapshotHistory;  // blockNumber => list of snapshotIds
    
    address public governance;
    address public svpToken;
    address public vaultToken;
    address public token1400;
    
    uint256 public totalSnapshots;
    uint256 public currentSnapshotId;
    
    // ============= Events =============
    
    event SnapshotCreated(
        uint256 indexed snapshotId,
        uint256 blockNumber,
        uint256 totalVotingPower,
        address indexed creator,
        uint256 timestamp
    );
    
    event UserSnapshotRecorded(
        address indexed user,
        uint256 indexed snapshotId,
        uint256 blockNumber,
        uint256 votingPower,
        uint256 timestamp
    );
    
    event ProposalSnapshotCreated(
        uint256 indexed proposalId,
        uint256 blockNumber,
        uint256 totalVotingPower,
        uint256 quorumRequired,
        address indexed creator,
        uint256 timestamp
    );
    
    event SnapshotFinalized(
        uint256 indexed snapshotId,
        uint256 finalizedAt,
        address indexed finalizer
    );
    
    event SnapshotArchived(
        uint256 indexed snapshotId,
        uint256 blockNumber,
        uint256 timestamp
    );
    
    event GovernanceUpdated(
        address indexed oldGovernance,
        address indexed newGovernance,
        uint256 timestamp
    );
    
    event BatchSnapshotCreated(
        uint256 count,
        uint256 startBlock,
        uint256 endBlock,
        address indexed creator,
        uint256 timestamp
    );
    
    event SnapshotPurged(
        uint256 indexed snapshotId,
        address indexed admin,
        uint256 timestamp
    );
    
    // ============= Constructor =============
    
    constructor(
        address _governance,
        address _svpToken,
        address _vaultToken,
        address _token1400
    ) {
        require(_governance != address(0), "GovernanceTokenSnapshot: Invalid governance");
        require(_svpToken != address(0), "GovernanceTokenSnapshot: Invalid token");
        
        governance = _governance;
        svpToken = _svpToken;
        vaultToken = _vaultToken;
        token1400 = _token1400;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(SNAPSHOT_ADMIN_ROLE, msg.sender);
        _grantRole(GOVERNANCE_ROLE, _governance);
        
        currentSnapshotId = 1;
    }
    
    // ============= Snapshot Creation =============
    
    /// @notice Create voting power snapshot
    function createSnapshot(uint256 proposalId)
        external
        onlyRole(GOVERNANCE_ROLE)
        returns (uint256 snapshotId)
    {
        snapshotId = currentSnapshotId++;
        
        VotingSnapshot storage snapshot = votingSnapshots[snapshotId];
        snapshot.blockNumber = block.number - 1;
        snapshot.timestamp = block.timestamp;
        snapshot.proposalId = proposalId;
        snapshot.finalized = false;
        
        totalSnapshots++;
        snapshotHistory[snapshot.blockNumber].push(snapshotId);
        
        emit SnapshotCreated(
            snapshotId,
            snapshot.blockNumber,
            0,  // Total will be calculated
            msg.sender,
            block.timestamp
        );
        
        return snapshotId;
    }
    
    /// @notice Create proposal-specific snapshot
    function createProposalSnapshot(uint256 proposalId)
        external
        onlyRole(GOVERNANCE_ROLE)
        returns (uint256 snapshotId)
    {
        snapshotId = currentSnapshotId++;
        
        ProposalSnapshot storage propSnapshot = proposalSnapshots[proposalId];
        propSnapshot.proposalId = proposalId;
        propSnapshot.blockNumber = block.number - 1;
        
        emit ProposalSnapshotCreated(
            proposalId,
            propSnapshot.blockNumber,
            0,  // Will be calculated
            0,  // Will be calculated
            msg.sender,
            block.timestamp
        );
        
        return snapshotId;
    }
    
    /// @notice Record user voting power at snapshot
    function recordUserSnapshot(
        address user,
        uint256 snapshotId,
        uint256 votingPower,
        uint256 balance,
        uint256 intrinsicValue
    )
        public
        onlyRole(GOVERNANCE_ROLE)
    {
        require(user != address(0), "GovernanceTokenSnapshot: Invalid user");
        require(snapshotId > 0 && snapshotId < currentSnapshotId, "GovernanceTokenSnapshot: Invalid snapshot");
        
        VotingSnapshot storage snapshot = votingSnapshots[snapshotId];
        require(!snapshot.finalized, "GovernanceTokenSnapshot: Snapshot finalized");
        
        uint256 blockNumber = snapshot.blockNumber;
        
        UserSnapshot storage userSnap = userSnapshots[user][blockNumber];
        userSnap.blockNumber = blockNumber;
        userSnap.votingPower = votingPower;
        userSnap.balance = balance;
        userSnap.intrinsicValue = intrinsicValue;
        
        // Update proposal snapshot if exists
        ProposalSnapshot storage propSnapshot = proposalSnapshots[snapshot.proposalId];
        if (propSnapshot.proposalId == snapshot.proposalId) {
            if (propSnapshot.userSnapshots[user].blockNumber == 0) {
                propSnapshot.snapshotParticipants.push(user);
            }
            propSnapshot.userSnapshots[user] = userSnap;
        }
        
        // Update total voting power
        snapshot.totalVotingPower += votingPower;
        
        emit UserSnapshotRecorded(
            user,
            snapshotId,
            blockNumber,
            votingPower,
            block.timestamp
        );
    }
    
    /// @notice Record batch user snapshots
    function recordUserSnapshotBatch(
        address[] calldata users,
        uint256[] calldata votingPowers,
        uint256[] calldata balances,
        uint256[] calldata intrinsicValues,
        uint256 snapshotId
    )
        external
        onlyRole(GOVERNANCE_ROLE)
    {
        require(users.length == votingPowers.length, "GovernanceTokenSnapshot: Length mismatch");
        require(users.length == balances.length, "GovernanceTokenSnapshot: Length mismatch");
        require(users.length == intrinsicValues.length, "GovernanceTokenSnapshot: Length mismatch");
        
        for (uint256 i = 0; i < users.length; i++) {
            recordUserSnapshot(
                users[i],
                snapshotId,
                votingPowers[i],
                balances[i],
                intrinsicValues[i]
            );
        }
    }
    
    // ============= Snapshot Queries =============
    
    /// @notice Get voting power at specific block
    function getVotingPowerAt(address user, uint256 blockNumber)
        external
        view
        returns (uint256)
    {
        UserSnapshot storage snapshot = userSnapshots[user][blockNumber];
        return snapshot.votingPower;
    }
    
    /// @notice Get balance at specific block
    function getBalanceAt(address user, uint256 blockNumber)
        external
        view
        returns (uint256)
    {
        UserSnapshot storage snapshot = userSnapshots[user][blockNumber];
        return snapshot.balance;
    }
    
    /// @notice Get intrinsic value at specific block
    function getIntrinsicValueAt(uint256 blockNumber)
        external
        view
        returns (uint256)
    {
        if (userSnapshots[address(this)][blockNumber].intrinsicValue == 0) {
            return 1e18;  // Default: $1
        }
        return userSnapshots[address(this)][blockNumber].intrinsicValue;
    }
    
    /// @notice Get snapshot details (summary)
    function getSnapshot(uint256 snapshotId)
        external
        view
        returns (uint256 blockNumber, uint256 timestamp, uint256 totalVotingPower, uint256 proposalId, bool finalized)
    {
        require(snapshotId > 0 && snapshotId < currentSnapshotId, "GovernanceTokenSnapshot: Invalid snapshot");
        VotingSnapshot storage s = votingSnapshots[snapshotId];
        return (s.blockNumber, s.timestamp, s.totalVotingPower, s.proposalId, s.finalized);
    }
    
    /// @notice Get proposal snapshot total voting power
    function getProposalTotalVotingPower(uint256 proposalId)
        external
        view
        returns (uint256)
    {
        return proposalSnapshots[proposalId].totalVotingPower;
    }
    
    /// @notice Get proposal participant count
    function getProposalParticipantCount(uint256 proposalId)
        external
        view
        returns (uint256)
    {
        return proposalSnapshots[proposalId].snapshotParticipants.length;
    }
    
    /// @notice Get user voting power in proposal
    function getUserProposalVotingPower(address user, uint256 proposalId)
        external
        view
        returns (uint256)
    {
        ProposalSnapshot storage propSnapshot = proposalSnapshots[proposalId];
        return propSnapshot.userSnapshots[user].votingPower;
    }
    
    /// @notice Get quorum for proposal
    function getProposalQuorum(uint256 proposalId)
        external
        view
        returns (uint256)
    {
        return proposalSnapshots[proposalId].quorumRequired;
    }
    
    /// @notice Get all snapshots for block
    function getSnapshotsAtBlock(uint256 blockNumber)
        external
        view
        returns (uint256[] memory)
    {
        return snapshotHistory[blockNumber];
    }
    
    /// @notice Get snapshot history length
    function getSnapshotHistoryLength(uint256 blockNumber)
        external
        view
        returns (uint256)
    {
        return snapshotHistory[blockNumber].length;
    }
    
    // ============= Snapshot Management =============
    
    /// @notice Finalize snapshot
    function finalizeSnapshot(uint256 snapshotId)
        external
        onlyRole(SNAPSHOT_ADMIN_ROLE)
    {
        require(snapshotId > 0 && snapshotId < currentSnapshotId, "GovernanceTokenSnapshot: Invalid snapshot");
        
        VotingSnapshot storage snapshot = votingSnapshots[snapshotId];
        require(!snapshot.finalized, "GovernanceTokenSnapshot: Already finalized");
        
        snapshot.finalized = true;
        
        emit SnapshotFinalized(snapshotId, block.timestamp, msg.sender);
    }
    
    /// @notice Archive old snapshots
    function archiveSnapshots(uint256 beforeBlock)
        external
        onlyRole(SNAPSHOT_ADMIN_ROLE)
    {
        require(beforeBlock > 0, "GovernanceTokenSnapshot: Invalid block");
        
        // In production, would move old snapshots to storage layer
        // For now, just emit event
        emit SnapshotArchived(0, beforeBlock, block.timestamp);
    }
    
    /// @notice Purge snapshot (emergency only)
    function purgeSnapshot(uint256 snapshotId)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(snapshotId > 0 && snapshotId < currentSnapshotId, "GovernanceTokenSnapshot: Invalid snapshot");
        
        delete votingSnapshots[snapshotId];
        
        emit SnapshotPurged(snapshotId, msg.sender, block.timestamp);
    }
    
    // ============= Governance Configuration =============
    
    /// @notice Update governance address
    function updateGovernance(address newGovernance)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(newGovernance != address(0), "GovernanceTokenSnapshot: Invalid governance");
        
        address oldGovernance = governance;
        governance = newGovernance;
        
        _revokeRole(GOVERNANCE_ROLE, oldGovernance);
        _grantRole(GOVERNANCE_ROLE, newGovernance);
        
        emit GovernanceUpdated(oldGovernance, newGovernance, block.timestamp);
    }
    
    /// @notice Update token addresses
    function updateTokenAddresses(
        address _svpToken,
        address _vaultToken,
        address _token1400
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_svpToken != address(0), "GovernanceTokenSnapshot: Invalid SVP token");
        
        svpToken = _svpToken;
        vaultToken = _vaultToken;
        token1400 = _token1400;
    }
    
    // ============= View Functions =============
    
    /// @notice Get metrics
    function getMetrics()
        external
        view
        returns (SnapshotMetrics memory)
    {
        uint256 activeCount = 0;
        uint256 finalizedCount = 0;
        
        for (uint256 i = 1; i < currentSnapshotId; i++) {
            if (votingSnapshots[i].finalized) {
                finalizedCount++;
            } else {
                activeCount++;
            }
        }
        
        return SnapshotMetrics({
            totalSnapshots: totalSnapshots,
            activeSnapshots: activeCount,
            finalizedSnapshots: finalizedCount,
            lastSnapshotBlock: votingSnapshots[currentSnapshotId - 1].blockNumber,
            lastSnapshotTime: votingSnapshots[currentSnapshotId - 1].timestamp
        });
    }
    
    /// @notice Get current snapshot ID
    function getCurrentSnapshotId()
        external
        view
        returns (uint256)
    {
        return currentSnapshotId;
    }
    
    /// @notice Get proposal participants
    function getProposalParticipants(uint256 proposalId)
        external
        view
        returns (address[] memory)
    {
        return proposalSnapshots[proposalId].snapshotParticipants;
    }
    
    /// @notice Check if snapshot exists
    function snapshotExists(uint256 snapshotId)
        external
        view
        returns (bool)
    {
        return snapshotId > 0 && 
               snapshotId < currentSnapshotId && 
               votingSnapshots[snapshotId].timestamp > 0;
    }
}
