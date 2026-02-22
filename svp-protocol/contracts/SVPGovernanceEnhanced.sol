// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// Minimal interfaces for integration
interface IValuationEngine {
    function getIntrinsicValueAt(uint256 blockNumber) external view returns (uint256);
}

interface IERC1400Partition {
    function balanceOfByPartition(bytes32 partition, address tokenHolder) external view returns (uint256);
}

interface IGovernanceSnapshot {
    function getVotingPowerAt(address user, uint256 blockNumber) external view returns (uint256);
    function getSnapshot(uint256 snapshotId) external view returns (uint256 blockNumber, uint256 timestamp, uint256 totalVotingPower, uint256 proposalId, bool finalized);
}

/**
 * @title SVPGovernanceEnhanced
 * @notice Value-weighted governance system for SVP Protocol DAO
 * @dev Implements value-weighted voting (balance × intrinsic value), proposal lifecycle, timelock execution
 * @author Hudu Yusuf (Analys)
 */
contract SVPGovernanceEnhanced is AccessControl, Pausable, ReentrancyGuard {
    // ============= Constants & Enums =============
    
    bytes32 public constant EMERGENCY_ADMIN_ROLE = keccak256("EMERGENCY_ADMIN_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant TIMELOCK_ADMIN_ROLE = keccak256("TIMELOCK_ADMIN_ROLE");
    
    uint256 public constant BPS = 10000;
    uint256 public constant VOTING_DELAY = 1 days;
    uint256 public constant VOTING_PERIOD = 3 days;
    uint256 public constant QUORUM_BPS = 500;  // 5%
    uint256 public constant TIMELOCK_DELAY = 2 days;
    uint256 public constant EMERGENCY_TIMELOCK = 1 days;
    
    enum ProposalState {
        PENDING,
        ACTIVE,
        CANCELLED,
        DEFEATED,
        SUCCEEDED,
        QUEUED,
        EXPIRED,
        EXECUTED
    }
    
    enum VoteType {
        AGAINST,
        FOR,
        ABSTAIN
    }
    
    // ============= Data Structures =============
    
    struct Proposal {
        uint256 id;
        address proposer;
        string title;
        string description;
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        uint256 eta;
        uint256 startTime;
        ProposalState state;
        bool cancelled;
        bool executed;
    }
    
    struct Receipt {
        bool hasVoted;
        uint8 support;
        uint96 votes;
        uint256 blockNumber;
    }
    
    struct ProposalAction {
        address target;
        uint256 value;
        string signature;
        bytes data;
    }
    
    struct VotingPower {
        uint256 balance;
        uint256 intrinsicValue;
        uint256 totalPower;
        uint256 blockNumber;
        uint256 timestamp;
    }
    
    struct GovernanceParams {
        uint256 votingDelay;
        uint256 votingPeriod;
        uint256 quorumPercentage;
        uint256 proposalThreshold;
        uint256 timelockDelay;
        uint256 votingThreshold;
    }
    
    // ============= State Variables =============
    
    Proposal[] public proposals;
    mapping(uint256 => ProposalAction[]) public proposalActions;
    mapping(uint256 => mapping(address => Receipt)) public proposalReceipts;
    mapping(uint256 => mapping(address => bool)) public proposalVoters;
    
    mapping(address => uint256) public latestProposalIds;
    mapping(address => address) public voteDelegates;
    mapping(address => uint256) public votingPowerByBlock;
    
    GovernanceParams public params;
    
    address public svpToken;
    address public valuationEngine;
    address public vaultToken;
    address public token1400;
    address public snapshotContract;
    
    uint256 public totalVotingPowerAtBlock;
    bool public protocolPaused;
    
    // ============= Events =============
    
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock,
        string title,
        string description
    );
    
    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        uint8 support,
        uint256 votes,
        string reason
    );
    
    event ProposalQueued(
        uint256 indexed proposalId,
        uint256 eta,
        address indexed queuer
    );
    
    event ProposalExecuted(
        uint256 indexed proposalId,
        uint256 executedAt,
        address indexed executor
    );
    
    event ProposalCancelled(
        uint256 indexed proposalId,
        address indexed proposer
    );
    
    event GovernanceParametersUpdated(
        uint256 votingDelay,
        uint256 votingPeriod,
        uint256 quorumPercentage,
        uint256 proposalThreshold,
        uint256 timelockDelay,
        uint256 timestamp
    );
    
    event VotingPowerUpdated(
        address indexed user,
        uint256 newVotingPower,
        uint256 blockNumber,
        uint256 timestamp
    );
    
    event DelegateChanged(
        address indexed delegator,
        address indexed fromDelegate,
        address indexed toDelegate,
        uint256 timestamp
    );

    event SnapshotAttachedToProposal(uint256 indexed proposalId, uint256 snapshotId, uint256 timestamp);
    
    event ProtocolPaused(
        address indexed admin,
        string reason,
        uint256 timestamp
    );
    
    event ProtocolUnpaused(
        address indexed admin,
        uint256 timestamp
    );
    
    event QuorumThresholdMet(
        uint256 indexed proposalId,
        uint256 totalVotes,
        uint256 quorumRequired,
        uint256 timestamp
    );
    
    event ProposalStateChanged(
        uint256 indexed proposalId,
        ProposalState oldState,
        ProposalState newState,
        uint256 timestamp
    );
    
    // ============= Constructor =============
    
    constructor(
        address _svpToken,
        address _valuationEngine,
        address _vaultToken,
        address _token1400
    ) {
        require(_svpToken != address(0), "SVPGovernanceEnhanced: Invalid token");
        require(_valuationEngine != address(0), "SVPGovernanceEnhanced: Invalid valuation engine");
        
        svpToken = _svpToken;
        valuationEngine = _valuationEngine;
        vaultToken = _vaultToken;
        token1400 = _token1400;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(EMERGENCY_ADMIN_ROLE, msg.sender);
        _grantRole(PROPOSER_ROLE, msg.sender);
        _grantRole(TIMELOCK_ADMIN_ROLE, msg.sender);
        
        // Initialize default parameters
        params = GovernanceParams({
            votingDelay: VOTING_DELAY,
            votingPeriod: VOTING_PERIOD,
            quorumPercentage: QUORUM_BPS,
            proposalThreshold: 65000e18,  // 65,000 tokens
            timelockDelay: TIMELOCK_DELAY,
            votingThreshold: 5001  // 50% + 1 in bps
        });
    }

    // ============= Snapshot Integration =============

    /// @notice Set snapshot contract address
    function setSnapshotContract(address _snapshot) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_snapshot != address(0), "Invalid snapshot");
        snapshotContract = _snapshot;
    }

    /// @notice Attach snapshot id to a proposal and activate it
    function attachSnapshotAndActivate(uint256 proposalId, uint256 snapshotId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(proposalId < proposals.length, "Invalid proposal");
        require(snapshotContract != address(0), "Snapshot not set");

        // fetch snapshot total voting power
        (uint256 blk, uint256 ts, uint256 totalVotingPower,, bool finalized) = IGovernanceSnapshot(snapshotContract).getSnapshot(snapshotId);
        require(finalized == false || finalized == true, "snapshot check"); // no-op to silence unused

        Proposal storage proposal = proposals[proposalId];
        require(proposal.state == ProposalState.PENDING, "Proposal not pending");

        // set total voting power reference for quorum calculations
        totalVotingPowerAtBlock = totalVotingPower;

        proposal.state = ProposalState.ACTIVE;
        proposal.startTime = block.timestamp;

        emit SnapshotAttachedToProposal(proposalId, snapshotId, block.timestamp);
        emit ProposalStateChanged(proposalId, ProposalState.PENDING, ProposalState.ACTIVE, block.timestamp);
    }
    
    // ============= Proposal Management =============
    
    /// @notice Create new governance proposal
    function createProposal(
        string memory title,
        string memory description,
        address[] calldata targets,
        uint256[] calldata values,
        string[] calldata signatures,
        bytes[] calldata calldatas
    )
        external
        whenNotPaused
        nonReentrant
        returns (uint256 proposalId)
    {
        require(targets.length == values.length, "SVPGovernanceEnhanced: Length mismatch");
        require(targets.length == signatures.length, "SVPGovernanceEnhanced: Length mismatch");
        require(targets.length == calldatas.length, "SVPGovernanceEnhanced: Length mismatch");
        require(targets.length > 0, "SVPGovernanceEnhanced: No actions");
        require(targets.length <= 10, "SVPGovernanceEnhanced: Too many actions");
        
        uint256 votingPower = getVotingPower(msg.sender, block.number - 1);
        require(votingPower >= params.proposalThreshold, "SVPGovernanceEnhanced: Low voting power");
        
        proposalId = proposals.length;
        
        Proposal storage proposal = proposals.push();
        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.title = title;
        proposal.description = description;
        proposal.startBlock = block.number + (params.votingDelay / 12); // Approx blocks
        proposal.endBlock = proposal.startBlock + (params.votingPeriod / 12);
        proposal.state = ProposalState.PENDING;
        proposal.startTime = block.timestamp;
        
        for (uint256 i = 0; i < targets.length; i++) {
            proposalActions[proposalId].push(ProposalAction({
                target: targets[i],
                value: values[i],
                signature: signatures[i],
                data: calldatas[i]
            }));
        }
        
        latestProposalIds[msg.sender] = proposalId;
        
        emit ProposalCreated(
            proposalId,
            msg.sender,
            targets,
            values,
            signatures,
            calldatas,
            proposal.startBlock,
            proposal.endBlock,
            title,
            description
        );
    }
    
    /// @notice Cast vote on proposal
    function castVote(uint256 proposalId, uint8 support)
        external
        whenNotPaused
        nonReentrant
    {
        require(proposalId < proposals.length, "SVPGovernanceEnhanced: Invalid proposal");
        require(support <= 2, "SVPGovernanceEnhanced: Invalid vote");
        
        Proposal storage proposal = proposals[proposalId];
        require(proposal.state == ProposalState.ACTIVE, "SVPGovernanceEnhanced: Proposal not active");
        require(block.timestamp >= proposal.startTime + params.votingDelay, "SVPGovernanceEnhanced: Voting not started");
        require(block.timestamp < proposal.startTime + params.votingDelay + params.votingPeriod, "SVPGovernanceEnhanced: Voting ended");
        
        Receipt storage receipt = proposalReceipts[proposalId][msg.sender];
        require(!receipt.hasVoted, "SVPGovernanceEnhanced: Already voted");
        
        uint256 votes = getVotingPower(msg.sender, block.number - 1);
        require(votes > 0, "SVPGovernanceEnhanced: No voting power");
        
        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = uint96(votes);
        receipt.blockNumber = block.number;
        
        proposalVoters[proposalId][msg.sender] = true;
        
        if (support == 0) {
            proposal.againstVotes += votes;
        } else if (support == 1) {
            proposal.forVotes += votes;
        } else {
            proposal.abstainVotes += votes;
        }
        
        emit VoteCast(msg.sender, proposalId, support, votes, "");
        
        // Check if quorum met
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        uint256 quorumRequired = (totalVotingPowerAtBlock * params.quorumPercentage) / BPS;
        
        if (totalVotes >= quorumRequired) {
            emit QuorumThresholdMet(proposalId, totalVotes, quorumRequired, block.timestamp);
        }
    }
    
    /// @notice Queue proposal for execution
    function queueProposal(uint256 proposalId)
        external
        onlyRole(TIMELOCK_ADMIN_ROLE)
        nonReentrant
    {
        require(proposalId < proposals.length, "SVPGovernanceEnhanced: Invalid proposal");
        
        Proposal storage proposal = proposals[proposalId];
        require(proposal.state == ProposalState.ACTIVE, "SVPGovernanceEnhanced: Not active");
        
        // Check voting period ended
        require(
            block.timestamp >= proposal.startTime + params.votingDelay + params.votingPeriod,
            "SVPGovernanceEnhanced: Voting active"
        );
        
        // Check quorum
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        uint256 quorumRequired = (totalVotingPowerAtBlock * params.quorumPercentage) / BPS;
        
        if (totalVotes < quorumRequired) {
            proposal.state = ProposalState.DEFEATED;
            emit ProposalStateChanged(proposalId, ProposalState.ACTIVE, ProposalState.DEFEATED, block.timestamp);
            return;
        }
        
        // Check vote threshold
        uint256 votesNeeded = (totalVotes * params.votingThreshold) / BPS;
        if (proposal.forVotes <= votesNeeded / 2) {
            proposal.state = ProposalState.DEFEATED;
            emit ProposalStateChanged(proposalId, ProposalState.ACTIVE, ProposalState.DEFEATED, block.timestamp);
            return;
        }
        
        proposal.state = ProposalState.SUCCEEDED;
        proposal.eta = block.timestamp + params.timelockDelay;
        
        emit ProposalQueued(proposalId, proposal.eta, msg.sender);
    }
    
    /// @notice Execute proposal
    function executeProposal(uint256 proposalId)
        external
        payable
        onlyRole(TIMELOCK_ADMIN_ROLE)
        nonReentrant
    {
        require(proposalId < proposals.length, "SVPGovernanceEnhanced: Invalid proposal");
        
        Proposal storage proposal = proposals[proposalId];
        require(proposal.state == ProposalState.SUCCEEDED, "SVPGovernanceEnhanced: Not succeeded");
        require(block.timestamp >= proposal.eta, "SVPGovernanceEnhanced: Timelock active");
        require(block.timestamp < proposal.eta + 14 days, "SVPGovernanceEnhanced: Proposal expired");
        
        proposal.state = ProposalState.EXECUTED;
        proposal.executed = true;
        
        ProposalAction[] storage actions = proposalActions[proposalId];
        
        for (uint256 i = 0; i < actions.length; i++) {
            _executeTransaction(
                actions[i].target,
                actions[i].value,
                actions[i].signature,
                actions[i].data
            );
        }
        
        emit ProposalExecuted(proposalId, block.timestamp, msg.sender);
    }
    
    /// @notice Cancel proposal
    function cancelProposal(uint256 proposalId)
        external
        nonReentrant
    {
        require(proposalId < proposals.length, "SVPGovernanceEnhanced: Invalid proposal");
        
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "SVPGovernanceEnhanced: Already executed");
        require(
            msg.sender == proposal.proposer || hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "SVPGovernanceEnhanced: Not authorized"
        );
        
        proposal.state = ProposalState.CANCELLED;
        proposal.cancelled = true;
        
        emit ProposalCancelled(proposalId, msg.sender);
    }
    
    // ============= Voting Power Management =============
    
    /// @notice Get voting power for user
    function getVotingPower(address user, uint256 blockNumber)
        public
        view
        returns (uint256)
    {
        // If a snapshot contract is attached, prefer historical snapshot voting power
        if (snapshotContract != address(0)) {
            try IGovernanceSnapshot(snapshotContract).getVotingPowerAt(user, blockNumber) returns (uint256 snapVP) {
                return snapVP;
            } catch {
                // fallback to on-chain calculation below
            }
        }

        uint256 tokenBalance = _getTokenBalance(user, blockNumber);
        uint256 vaultBalance = _getVaultBalance(user, blockNumber);
        uint256 partition1400Balance = _getPartition1400Balance(user, blockNumber);

        uint256 totalBalance = tokenBalance + vaultBalance + partition1400Balance;

        uint256 intrinsicValue = _getIntrinsicValue(blockNumber);

        return (totalBalance * intrinsicValue) / 1e18;
    }
    
    /// @notice Delegate voting power to another address
    function delegate(address delegatee)
        external
        whenNotPaused
    {
        require(delegatee != address(0), "SVPGovernanceEnhanced: Invalid delegatee");
        
        address currentDelegate = voteDelegates[msg.sender];
        voteDelegates[msg.sender] = delegatee;
        
        emit DelegateChanged(msg.sender, currentDelegate, delegatee, block.timestamp);
    }
    
    /// @notice Get delegate for user
    function getDelegate(address user)
        external
        view
        returns (address)
    {
        address delegateAddress = voteDelegates[user];
        return delegateAddress == address(0) ? user : delegateAddress;
    }
    
    // ============= Governance Parameters =============
    
    /// @notice Set quorum percentage
    function setQuorumPercentage(uint256 newQuorum)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(newQuorum > 0 && newQuorum <= BPS, "SVPGovernanceEnhanced: Invalid quorum");
        params.quorumPercentage = newQuorum;
        
        emit GovernanceParametersUpdated(
            params.votingDelay,
            params.votingPeriod,
            params.quorumPercentage,
            params.proposalThreshold,
            params.timelockDelay,
            block.timestamp
        );
    }
    
    /// @notice Set voting delay
    function setVotingDelay(uint256 newDelay)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(newDelay > 0, "SVPGovernanceEnhanced: Invalid delay");
        params.votingDelay = newDelay;
        
        emit GovernanceParametersUpdated(
            params.votingDelay,
            params.votingPeriod,
            params.quorumPercentage,
            params.proposalThreshold,
            params.timelockDelay,
            block.timestamp
        );
    }
    
    /// @notice Set voting period
    function setVotingPeriod(uint256 newPeriod)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(newPeriod > 0, "SVPGovernanceEnhanced: Invalid period");
        params.votingPeriod = newPeriod;
        
        emit GovernanceParametersUpdated(
            params.votingDelay,
            params.votingPeriod,
            params.quorumPercentage,
            params.proposalThreshold,
            params.timelockDelay,
            block.timestamp
        );
    }
    
    /// @notice Set proposal threshold
    function setProposalThreshold(uint256 newThreshold)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(newThreshold > 0, "SVPGovernanceEnhanced: Invalid threshold");
        params.proposalThreshold = newThreshold;
        
        emit GovernanceParametersUpdated(
            params.votingDelay,
            params.votingPeriod,
            params.quorumPercentage,
            params.proposalThreshold,
            params.timelockDelay,
            block.timestamp
        );
    }
    
    /// @notice Set timelock delay
    function setTimelockDelay(uint256 newDelay)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(newDelay > 0, "SVPGovernanceEnhanced: Invalid delay");
        params.timelockDelay = newDelay;
        
        emit GovernanceParametersUpdated(
            params.votingDelay,
            params.votingPeriod,
            params.quorumPercentage,
            params.proposalThreshold,
            params.timelockDelay,
            block.timestamp
        );
    }
    
    // ============= Emergency Functions =============
    
    /// @notice Pause protocol (emergency only)
    function pauseProtocol(string memory reason)
        external
        onlyRole(EMERGENCY_ADMIN_ROLE)
    {
        protocolPaused = true;
        _pause();
        
        emit ProtocolPaused(msg.sender, reason, block.timestamp);
    }
    
    /// @notice Unpause protocol
    function unpauseProtocol()
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        protocolPaused = false;
        _unpause();
        
        emit ProtocolUnpaused(msg.sender, block.timestamp);
    }
    
    // ============= View Functions =============
    
    /// @notice Get proposal details
    function getProposal(uint256 proposalId)
        external
        view
        returns (Proposal memory)
    {
        require(proposalId < proposals.length, "SVPGovernanceEnhanced: Invalid proposal");
        return proposals[proposalId];
    }
    
    /// @notice Get proposal action count
    function getProposalActionCount(uint256 proposalId)
        external
        view
        returns (uint256)
    {
        return proposalActions[proposalId].length;
    }
    
    /// @notice Get proposal action
    function getProposalAction(uint256 proposalId, uint256 actionIndex)
        external
        view
        returns (ProposalAction memory)
    {
        require(proposalId < proposals.length, "SVPGovernanceEnhanced: Invalid proposal");
        return proposalActions[proposalId][actionIndex];
    }
    
    /// @notice Get proposal votes
    function getProposalVotes(uint256 proposalId)
        external
        view
        returns (
            uint256 forVotes,
            uint256 againstVotes,
            uint256 abstainVotes
        )
    {
        require(proposalId < proposals.length, "SVPGovernanceEnhanced: Invalid proposal");
        
        Proposal storage proposal = proposals[proposalId];
        return (proposal.forVotes, proposal.againstVotes, proposal.abstainVotes);
    }
    
    /// @notice Get proposal state
    function getProposalState(uint256 proposalId)
        external
        view
        returns (ProposalState)
    {
        require(proposalId < proposals.length, "SVPGovernanceEnhanced: Invalid proposal");
        return proposals[proposalId].state;
    }
    
    /// @notice Check if user has voted
    function hasVoted(uint256 proposalId, address account)
        external
        view
        returns (bool)
    {
        return proposalReceipts[proposalId][account].hasVoted;
    }
    
    /// @notice Get proposal count
    function getProposalCount()
        external
        view
        returns (uint256)
    {
        return proposals.length;
    }
    
    /// @notice Get governance parameters
    function getGovernanceParams()
        external
        view
        returns (GovernanceParams memory)
    {
        return params;
    }
    
    // ============= Internal Functions =============
    
    function _getTokenBalance(address user, uint256 blockNumber)
        internal
        view
        returns (uint256)
    {
        if (svpToken == address(0)) return 0;
        try IERC20(svpToken).balanceOf(user) returns (uint256 bal) {
            return bal;
        } catch {
            return 0;
        }
    }
    
    function _getVaultBalance(address user, uint256 blockNumber)
        internal
        view
        returns (uint256)
    {
        if (vaultToken == address(0)) return 0;
        try IERC20(vaultToken).balanceOf(user) returns (uint256 bal) {
            return bal;
        } catch {
            return 0;
        }
    }
    
    function _getPartition1400Balance(address user, uint256 blockNumber)
        internal
        view
        returns (uint256)
    {
        if (token1400 == address(0)) return 0;
        // Try partitioned balance if ERC-1400 supports it
        try IERC1400Partition(token1400).balanceOfByPartition(bytes32(0), user) returns (uint256 pbal) {
            return pbal;
        } catch {
            // Fallback to ERC20 balance if available
            try IERC20(token1400).balanceOf(user) returns (uint256 bal) {
                return bal;
            } catch {
                return 0;
            }
        }
    }
    
    function _getIntrinsicValue(uint256 blockNumber)
        internal
        view
        returns (uint256)
    {
        if (valuationEngine == address(0)) return 1e18;
        try IValuationEngine(valuationEngine).getIntrinsicValueAt(blockNumber) returns (uint256 v) {
            if (v == 0) return 1e18;
            return v;
        } catch {
            return 1e18;
        }
    }

    // ============= Admin: Integration Setters =============

    /// @notice Set token and integration addresses
    function setTokenAddresses(
        address _svpToken,
        address _vaultToken,
        address _token1400
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_svpToken != address(0), "Invalid svp token");
        svpToken = _svpToken;
        vaultToken = _vaultToken;
        token1400 = _token1400;
    }

    /// @notice Set valuation engine address
    function setValuationEngine(address _valuationEngine) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_valuationEngine != address(0), "Invalid valuation engine");
        valuationEngine = _valuationEngine;
    }

    /// @notice Set timelock admin address used to queue/execute proposals
    function setTimelockAdmin(address timelockAdmin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(timelockAdmin != address(0), "Invalid timelock admin");
        _grantRole(TIMELOCK_ADMIN_ROLE, timelockAdmin);
    }
    
    function _executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data
    )
        internal
    {
        bytes memory callData;
        
        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }
        
        (bool success, ) = target.call{value: value}(callData);
        require(success, "SVPGovernanceEnhanced: Execution failed");
    }
}
