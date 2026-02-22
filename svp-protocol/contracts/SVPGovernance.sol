// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title SVPGovernance
 * @notice Value-weighted governance voting for SVP Protocol
 * @dev Voting power = Token Balance × Intrinsic Value
 * @author Hudu Yusuf (Analys)
 */
contract SVPGovernance is AccessControl, ReentrancyGuard, Pausable {
    // ============= Constants =============
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    
    /// @notice Base unit for fixed-point arithmetic (1e18)
    uint256 public constant BASE_UNIT = 1e18;
    
    /// @notice Proposal states
    enum ProposalState {
        PENDING,
        ACTIVE,
        DEFEATED,
        SUCCEEDED,
        QUEUED,
        EXECUTED,
        CANCELED
    }
    
    // ============= Data Structures =============
    
    /// @notice Proposal details
    struct Proposal {
        uint256 id;                    // Proposal ID
        address proposer;              // Address that created proposal
        uint256 startBlock;            // Block voting starts
        uint256 endBlock;              // Block voting ends
        uint256 forVotes;              // Total votes in favor
        uint256 againstVotes;          // Total votes against
        uint256 abstainVotes;          // Total abstain votes
        bool canceled;                 // Has proposal been canceled
        bool executed;                 // Has proposal been executed
        uint256 eta;                   // ETA for execution (timelock)
        uint256 proposalTimestamp;     // Creation timestamp
        string description;            // Proposal description
    }
    
    /// @notice Vote receipt
    struct Receipt {
        bool hasVoted;                 // Has voter cast vote
        uint8 support;                 // 0=Against, 1=For, 2=Abstain
        uint256 votes;                 // Number of votes cast
        uint256 votingPower;           // Weighted voting power used
    }
    
    /// @notice Governance parameters
    struct GovernanceParams {
        uint256 votingDelay;           // Blocks before voting starts
        uint256 votingPeriod;          // Blocks for voting duration
        uint256 quorumPercentage;      // Quorum as percentage of total voting power
        uint256 timelockDelay;         // Time delay for execution (seconds)
        uint256 proposalThreshold;     // Minimum voting power to create proposal
    }
    
    // ============= State Variables =============
    
    /// @notice Reference to valuation engine
    address public valuationEngine;
    
    /// @notice Reference to SVP token
    address public svpToken;
    
    /// @notice Asset this governance controls
    address public asset;
    
    /// @notice Governance parameters
    GovernanceParams public params;
    
    /// @notice Proposal counter
    uint256 public proposalCount;
    
    /// @notice Proposals mapping
    mapping(uint256 => Proposal) public proposals;
    
    /// @notice Proposal ID to targets
    mapping(uint256 => address[]) public proposalTargets;
    
    /// @notice Proposal ID to values (eth amounts)
    mapping(uint256 => uint256[]) public proposalValues;
    
    /// @notice Proposal ID to signatures
    mapping(uint256 => string[]) public proposalSignatures;
    
    /// @notice Proposal ID to call data
    mapping(uint256 => bytes[]) public proposalCalldatas;
    
    /// @notice Vote receipts (proposalId => voter => receipt)
    mapping(uint256 => mapping(address => Receipt)) public receipts;
    
    /// @notice Total voting power for weighted calculations
    uint256 public totalVotingPower;
    
    /// @notice Last proposal timestamp per proposer (rate limiting)
    mapping(address => uint256) public lastProposalTimestamp;
    
    /// @notice Proposal creation rate limit (min seconds between proposals)
    uint256 public proposalCreationCooldown = 1 days;
    
    /// @notice Whether governance is active
    bool public governanceActive = true;
    
    // ============= Events =============
    
    /// @notice Emitted when a proposal is created
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock,
        string description,
        uint256 timestamp
    );
    
    /// @notice Emitted when a vote is cast
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        uint8 support,
        uint256 votes,
        uint256 votingPower,
        string reason
    );
    
    /// @notice Emitted when a proposal is canceled
    event ProposalCanceled(uint256 indexed proposalId, uint256 timestamp);
    
    /// @notice Emitted when a proposal is queued for execution
    event ProposalQueued(uint256 indexed proposalId, uint256 eta, uint256 timestamp);
    
    /// @notice Emitted when a proposal is executed
    event ProposalExecuted(uint256 indexed proposalId, uint256 timestamp);
    
    /// @notice Emitted when governance parameters are updated
    event GovernanceParamsUpdated(
        uint256 votingDelay,
        uint256 votingPeriod,
        uint256 quorumPercentage,
        uint256 timelockDelay,
        uint256 proposalThreshold,
        address indexed admin,
        uint256 timestamp
    );
    
    /// @notice Emitted when total voting power is updated
    event VotingPowerUpdated(uint256 newTotalPower, uint256 timestamp);
    
    // ============= Constructor =============
    
    /**
     * @notice Initialize governance contract
     * @param valuationEngine_ Address of valuation engine
     * @param svpToken_ Address of SVP token
     * @param asset_ Asset being governed
     */
    constructor(
        address valuationEngine_,
        address svpToken_,
        address asset_
    ) {
        require(valuationEngine_ != address(0), "SVPGovernance: Invalid valuation engine");
        require(svpToken_ != address(0), "SVPGovernance: Invalid token");
        require(asset_ != address(0), "SVPGovernance: Invalid asset");
        
        valuationEngine = valuationEngine_;
        svpToken = svpToken_;
        asset = asset_;
        
        // Default governance parameters
        params = GovernanceParams({
            votingDelay: 1,              // 1 block delay
            votingPeriod: 50400,         // ~1 week at 12s/block
            quorumPercentage: 20,        // 20% quorum
            timelockDelay: 2 days,       // 2 day timelock
            proposalThreshold: 10000e18  // 10,000 wei minimum to propose
        });
        
        proposalCount = 0;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }
    
    // ============= Voting Power Calculation =============
    
    /**
     * @notice Calculate voting power for an account
     * @param voter Address to check
     * @return Voting power (token balance × intrinsic value)
     */
    function getVotingPower(address voter) public view returns (uint256) {
        // Get token balance from snapshot
        uint256 tokenBalance = _getTokenBalance(voter);
        if (tokenBalance == 0) return 0;
        
        // Get intrinsic value from valuation engine
        uint256 intrinsicValue = _getIntrinsicValue();
        if (intrinsicValue == 0) return 0;
        
        // Voting power = balance × value / BASE_UNIT
        return (tokenBalance * intrinsicValue) / BASE_UNIT;
    }
    
    /**
     * @notice Get token balance (interface to token contract)
     * @param account Account to check
     * @return Token balance
     */
    function _getTokenBalance(address account) internal view returns (uint256) {
        // In production, would call token contract's balanceOf
        // This is a placeholder for interface integration
        (bool success, bytes memory result) = svpToken.staticcall(
            abi.encodeWithSignature("balanceOf(address)", account)
        );
        if (!success || result.length == 0) return 0;
        return abi.decode(result, (uint256));
    }
    
    /**
     * @notice Get current intrinsic value (interface to valuation engine)
     * @return Intrinsic value of asset
     */
    function _getIntrinsicValue() internal view returns (uint256) {
        // In production, would call valuation engine's getIntrinsicValue
        // This is a placeholder for interface integration
        (bool success, bytes memory result) = valuationEngine.staticcall(
            abi.encodeWithSignature("getIntrinsicValue(address)", asset)
        );
        if (!success || result.length == 0) return 0;
        return abi.decode(result, (uint256));
    }
    
    // ============= Proposal Management =============
    
    /**
     * @notice Create a new proposal
     * @param targets Target contract addresses for proposal actions
     * @param values ETH amounts for each action
     * @param signatures Function signatures for each action
     * @param calldatas Encoded function call data
     * @param description Proposal description
     * @return proposalId New proposal ID
     */
    function createProposal(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    )
        external
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        require(governanceActive, "SVPGovernance: Governance is inactive");
        require(
            block.timestamp >= lastProposalTimestamp[msg.sender] + proposalCreationCooldown,
            "SVPGovernance: Proposal creation rate limited"
        );
        
        // Check voting power threshold
        uint256 votingPower = getVotingPower(msg.sender);
        require(
            votingPower >= params.proposalThreshold,
            "SVPGovernance: Insufficient voting power to create proposal"
        );
        
        // Validate input arrays
        require(targets.length > 0, "SVPGovernance: Must provide targets");
        require(
            targets.length == values.length &&
            targets.length == signatures.length &&
            targets.length == calldatas.length,
            "SVPGovernance: Array length mismatch"
        );
        
        // Validate description
        require(bytes(description).length > 0, "SVPGovernance: Description required");
        
        // Create proposal
        uint256 proposalId = proposalCount++;
        uint256 startBlock = block.number + params.votingDelay;
        uint256 endBlock = startBlock + params.votingPeriod;
        
        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.startBlock = startBlock;
        newProposal.endBlock = endBlock;
        newProposal.proposalTimestamp = block.timestamp;
        newProposal.description = description;
        
        // Store proposal actions
        proposalTargets[proposalId] = targets;
        proposalValues[proposalId] = values;
        proposalSignatures[proposalId] = signatures;
        proposalCalldatas[proposalId] = calldatas;
        
        // Update rate limiting
        lastProposalTimestamp[msg.sender] = block.timestamp;
        
        emit ProposalCreated(
            proposalId,
            msg.sender,
            targets,
            values,
            signatures,
            calldatas,
            startBlock,
            endBlock,
            description,
            block.timestamp
        );
        
        return proposalId;
    }
    
    /**
     * @notice Cast a vote on a proposal
     * @param proposalId Proposal ID
     * @param support Vote choice (0=Against, 1=For, 2=Abstain)
     * @param reason Optional reason text
     */
    function castVote(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    )
        external
        whenNotPaused
        nonReentrant
    {
        require(proposalId < proposalCount, "SVPGovernance: Invalid proposal ID");
        require(support <= 2, "SVPGovernance: Invalid vote choice");
        
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.canceled, "SVPGovernance: Proposal is canceled");
        require(!proposal.executed, "SVPGovernance: Proposal already executed");
        
        // Check voting is active
        require(
            block.number >= proposal.startBlock,
            "SVPGovernance: Voting has not started"
        );
        require(
            block.number <= proposal.endBlock,
            "SVPGovernance: Voting has ended"
        );
        
        // Check voter hasn't already voted
        Receipt storage receipt = receipts[proposalId][msg.sender];
        require(!receipt.hasVoted, "SVPGovernance: Voter has already voted");
        
        // Calculate voting power
        uint256 votingPower = getVotingPower(msg.sender);
        require(votingPower > 0, "SVPGovernance: Voter has no voting power");
        
        // Record vote
        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = 1;
        receipt.votingPower = votingPower;
        
        // Update proposal vote counts
        if (support == 0) {
            proposal.againstVotes += votingPower;
        } else if (support == 1) {
            proposal.forVotes += votingPower;
        } else if (support == 2) {
            proposal.abstainVotes += votingPower;
        }
        
        emit VoteCast(proposalId, msg.sender, support, 1, votingPower, reason);
    }
    
    /**
     * @notice Cancel a proposal
     * @param proposalId Proposal ID to cancel
     */
    function cancelProposal(uint256 proposalId)
        external
        whenNotPaused
        nonReentrant
    {
        require(proposalId < proposalCount, "SVPGovernance: Invalid proposal ID");
        
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.canceled, "SVPGovernance: Proposal already canceled");
        require(!proposal.executed, "SVPGovernance: Proposal already executed");
        
        // Only proposer or admin can cancel
        require(
            msg.sender == proposal.proposer || hasRole(ADMIN_ROLE, msg.sender),
            "SVPGovernance: Caller not authorized to cancel"
        );
        
        proposal.canceled = true;
        
        emit ProposalCanceled(proposalId, block.timestamp);
    }
    
    /**
     * @notice Queue a succeeded proposal for execution
     * @param proposalId Proposal ID to queue
     */
    function queueProposal(uint256 proposalId)
        external
        onlyRole(ADMIN_ROLE)
        whenNotPaused
        nonReentrant
    {
        require(proposalId < proposalCount, "SVPGovernance: Invalid proposal ID");
        
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.canceled, "SVPGovernance: Proposal is canceled");
        require(!proposal.executed, "SVPGovernance: Proposal already executed");
        require(proposal.endBlock <= block.number, "SVPGovernance: Voting not ended");
        
        // Check if proposal succeeded
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        require(totalVotes > 0, "SVPGovernance: No votes cast");
        require(
            proposal.forVotes > proposal.againstVotes,
            "SVPGovernance: Proposal did not pass"
        );
        
        // Check quorum
        uint256 quorumVotes = _calculateQuorum();
        require(totalVotes >= quorumVotes, "SVPGovernance: Quorum not met");
        
        // Set ETA for execution (timelock)
        proposal.eta = block.timestamp + params.timelockDelay;
        
        emit ProposalQueued(proposalId, proposal.eta, block.timestamp);
    }
    
    /**
     * @notice Execute a queued proposal
     * @param proposalId Proposal ID to execute
     */
    function executeProposal(uint256 proposalId)
        external
        onlyRole(ADMIN_ROLE)
        whenNotPaused
        nonReentrant
    {
        require(proposalId < proposalCount, "SVPGovernance: Invalid proposal ID");
        
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.canceled, "SVPGovernance: Proposal is canceled");
        require(!proposal.executed, "SVPGovernance: Proposal already executed");
        require(proposal.eta != 0, "SVPGovernance: Proposal not queued");
        require(
            block.timestamp >= proposal.eta,
            "SVPGovernance: Timelock not satisfied"
        );
        
        // Execute proposal actions
        address[] memory targets = proposalTargets[proposalId];
        uint256[] memory values = proposalValues[proposalId];
        string[] memory signatures = proposalSignatures[proposalId];
        bytes[] memory calldatas = proposalCalldatas[proposalId];
        
        for (uint256 i = 0; i < targets.length; i++) {
            _executeProposalAction(targets[i], values[i], signatures[i], calldatas[i]);
        }
        
        proposal.executed = true;
        
        emit ProposalExecuted(proposalId, block.timestamp);
    }
    
    /**
     * @notice Execute a single proposal action
     * @param target Target contract
     * @param value ETH amount
     * @param signature Function signature
     * @param calldata_ Function call data
     */
    function _executeProposalAction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory calldata_
    ) internal {
        bytes memory callData;
        if (bytes(signature).length == 0) {
            callData = calldata_;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), calldata_);
        }
        
        (bool success, ) = target.call{value: value}(callData);
        require(success, "SVPGovernance: Proposal execution failed");
    }
    
    // ============= View Functions =============
    
    /**
     * @notice Get proposal state
     * @param proposalId Proposal ID
     * @return Current state of proposal
     */
    function getProposalState(uint256 proposalId) external view returns (ProposalState) {
        require(proposalId < proposalCount, "SVPGovernance: Invalid proposal ID");
        Proposal storage proposal = proposals[proposalId];
        
        if (proposal.canceled) return ProposalState.CANCELED;
        if (proposal.executed) return ProposalState.EXECUTED;
        if (proposal.eta != 0) return ProposalState.QUEUED;
        if (block.number <= proposal.endBlock) return ProposalState.ACTIVE;
        
        // Voting ended, check if succeeded
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        if (totalVotes == 0 || proposal.forVotes <= proposal.againstVotes) {
            return ProposalState.DEFEATED;
        }
        
        return ProposalState.SUCCEEDED;
    }
    
    /**
     * @notice Get proposal details
     * @param proposalId Proposal ID
     * @return Proposal data
     */
    function getProposal(uint256 proposalId)
        external
        view
        returns (Proposal memory)
    {
        require(proposalId < proposalCount, "SVPGovernance: Invalid proposal ID");
        return proposals[proposalId];
    }
    
    /**
     * @notice Get vote receipt
     * @param proposalId Proposal ID
     * @param voter Voter address
     * @return Vote receipt
     */
    function getReceipt(uint256 proposalId, address voter)
        external
        view
        returns (Receipt memory)
    {
        return receipts[proposalId][voter];
    }
    
    /**
     * @notice Calculate quorum requirement
     * @return Quorum votes needed
     */
    function _calculateQuorum() internal view returns (uint256) {
        // Get total possible voting power (total token supply × max intrinsic value)
        // This is simplified; production would track total voting power
        uint256 intrinsicValue = _getIntrinsicValue();
        if (intrinsicValue == 0) return 0;
        
        // Placeholder: would use tracked total voting power
        // For now, return a default quorum
        return totalVotingPower * params.quorumPercentage / 100;
    }
    
    // ============= Admin Functions =============
    
    /**
     * @notice Update governance parameters
     * @param votingDelay New voting delay
     * @param votingPeriod New voting period
     * @param quorumPercentage New quorum percentage
     * @param timelockDelay New timelock delay
     * @param proposalThreshold New proposal threshold
     */
    function setGovernanceParams(
        uint256 votingDelay,
        uint256 votingPeriod,
        uint256 quorumPercentage,
        uint256 timelockDelay,
        uint256 proposalThreshold
    )
        external
        onlyRole(ADMIN_ROLE)
    {
        require(votingDelay > 0, "SVPGovernance: Voting delay must be positive");
        require(votingPeriod > 0, "SVPGovernance: Voting period must be positive");
        require(quorumPercentage <= 100, "SVPGovernance: Quorum cannot exceed 100%");
        require(timelockDelay > 0, "SVPGovernance: Timelock delay must be positive");
        
        params = GovernanceParams({
            votingDelay: votingDelay,
            votingPeriod: votingPeriod,
            quorumPercentage: quorumPercentage,
            timelockDelay: timelockDelay,
            proposalThreshold: proposalThreshold
        });
        
        emit GovernanceParamsUpdated(
            votingDelay,
            votingPeriod,
            quorumPercentage,
            timelockDelay,
            proposalThreshold,
            msg.sender,
            block.timestamp
        );
    }
    
    /**
     * @notice Update total voting power
     * @param newTotalPower New total voting power
     */
    function setTotalVotingPower(uint256 newTotalPower)
        external
        onlyRole(ADMIN_ROLE)
    {
        totalVotingPower = newTotalPower;
        emit VotingPowerUpdated(newTotalPower, block.timestamp);
    }
    
    /**
     * @notice Pause/unpause governance
     * @param pauseGovernance True to pause
     */
    function setGovernanceActive(bool pauseGovernance)
        external
        onlyRole(ADMIN_ROLE)
    {
        governanceActive = !pauseGovernance;
    }
}
