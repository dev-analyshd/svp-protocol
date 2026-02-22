// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title Timelock
 * @notice Timelock executor for SVP Governance - enforces 2-day execution delay
 * @dev Manages queued transactions with enforced delay before execution
 * @author Hudu Yusuf (Analys)
 */
contract Timelock is AccessControl, ReentrancyGuard {
    // ============= Constants & Roles =============
    
    bytes32 public constant TIMELOCK_ADMIN_ROLE = keccak256("TIMELOCK_ADMIN_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    
    uint256 public constant MIN_DELAY = 2 days;
    uint256 public constant MAX_DELAY = 30 days;
    uint256 public constant GRACE_PERIOD = 14 days;
    
    // ============= Data Structures =============
    
    struct Transaction {
        address target;
        uint256 value;
        string signature;
        bytes data;
        uint256 eta;
        bool executed;
        bool cancelled;
        uint256 queuedAt;
        uint256 executedAt;
    }
    
    struct DelayConfig {
        uint256 standard;
        uint256 emergency;
        uint256 lastUpdated;
        address updatedBy;
    }
    
    struct ExecutionLog {
        bytes32 txHash;
        uint256 executedAt;
        address executor;
        bool success;
        bytes result;
    }
    
    // ============= State Variables =============
    
    mapping(bytes32 => Transaction) public transactions;
    mapping(bytes32 => bool) public queuedTransactions;
    mapping(address => uint256) public executionCount;
    mapping(uint256 => ExecutionLog) public executionLogs;
    
    address public governance;
    DelayConfig public delayConfig;
    uint256 public totalExecutedTransactions;
    uint256 public totalQueuedTransactions;
    
    // ============= Events =============
    
    event TransactionQueued(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta,
        address indexed queuer,
        uint256 timestamp
    );
    
    event TransactionExecuted(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta,
        address indexed executor,
        uint256 timestamp
    );
    
    event TransactionCancelled(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta,
        address indexed canceller,
        uint256 timestamp
    );
    
    event DelayUpdated(
        uint256 oldDelay,
        uint256 newDelay,
        address indexed admin,
        uint256 timestamp
    );
    
    event EmergencyDelayUpdated(
        uint256 oldDelay,
        uint256 newDelay,
        address indexed admin,
        uint256 timestamp
    );
    
    event GovernanceUpdated(
        address indexed oldGovernance,
        address indexed newGovernance,
        address indexed admin,
        uint256 timestamp
    );
    
    event TransactionExecutionFailed(
        bytes32 indexed txHash,
        address indexed target,
        string reason,
        uint256 timestamp
    );
    
    event TransactionQueuedBatch(
        uint256 count,
        address indexed queuer,
        uint256 timestamp
    );
    
    event TransactionExpired(
        bytes32 indexed txHash,
        address indexed target,
        uint256 eta,
        uint256 timestamp
    );
    
    // ============= Constructor =============
    
    constructor(address _governance) {
        require(_governance != address(0), "Timelock: Invalid governance");
        
        governance = _governance;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(TIMELOCK_ADMIN_ROLE, msg.sender);
        _grantRole(PROPOSER_ROLE, _governance);
        _grantRole(EXECUTOR_ROLE, msg.sender);
        _grantRole(CANCELLER_ROLE, msg.sender);
        
        delayConfig = DelayConfig({
            standard: MIN_DELAY,
            emergency: 1 days,
            lastUpdated: block.timestamp,
            updatedBy: msg.sender
        });
    }
    
    // ============= Queue Functions =============
    
    /// @notice Queue transaction for execution
    function queueTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 delay
    )
        public
        onlyRole(PROPOSER_ROLE)
        nonReentrant
        returns (bytes32 txHash)
    {
        require(target != address(0), "Timelock: Invalid target");
        require(delay >= delayConfig.standard, "Timelock: Delay too short");
        require(delay <= MAX_DELAY, "Timelock: Delay too long");
        
        uint256 eta = block.timestamp + delay;
        txHash = keccak256(abi.encode(target, value, signature, data, eta));
        
        require(!queuedTransactions[txHash], "Timelock: Already queued");
        
        queuedTransactions[txHash] = true;
        transactions[txHash] = Transaction({
            target: target,
            value: value,
            signature: signature,
            data: data,
            eta: eta,
            executed: false,
            cancelled: false,
            queuedAt: block.timestamp,
            executedAt: 0
        });
        
        totalQueuedTransactions++;
        
        emit TransactionQueued(
            txHash,
            target,
            value,
            signature,
            data,
            eta,
            msg.sender,
            block.timestamp
        );
    }
    
    /// @notice Queue multiple transactions
    function queueTransactionBatch(
        address[] calldata targets,
        uint256[] calldata values,
        string[] calldata signatures,
        bytes[] calldata calldatas,
        uint256[] calldata delays
    )
        external
        onlyRole(PROPOSER_ROLE)
        nonReentrant
    {
        require(targets.length == values.length, "Timelock: Length mismatch");
        require(targets.length == signatures.length, "Timelock: Length mismatch");
        require(targets.length == calldatas.length, "Timelock: Length mismatch");
        require(targets.length == delays.length, "Timelock: Length mismatch");
        require(targets.length > 0 && targets.length <= 50, "Timelock: Invalid batch size");
        
        for (uint256 i = 0; i < targets.length; i++) {
            queueTransaction(
                targets[i],
                values[i],
                signatures[i],
                calldatas[i],
                delays[i]
            );
        }
        
        emit TransactionQueuedBatch(targets.length, msg.sender, block.timestamp);
    }
    
    // ============= Execution Functions =============
    
    /// @notice Execute queued transaction
    function executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    )
        public
        payable
        onlyRole(EXECUTOR_ROLE)
        nonReentrant
    {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        
        Transaction storage transaction = transactions[txHash];
        require(queuedTransactions[txHash], "Timelock: Not queued");
        require(!transaction.executed, "Timelock: Already executed");
        require(!transaction.cancelled, "Timelock: Cancelled");
        require(block.timestamp >= transaction.eta, "Timelock: Too early");
        require(block.timestamp < transaction.eta + GRACE_PERIOD, "Timelock: Expired");
        
        transaction.executed = true;
        transaction.executedAt = block.timestamp;
        
        bytes memory callData;
        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }
        
        (bool success, bytes memory result) = target.call{value: value}(callData);
        
        executionCount[msg.sender]++;
        totalExecutedTransactions++;
        
        if (!success) {
            emit TransactionExecutionFailed(
                txHash,
                target,
                _getRevertReason(result),
                block.timestamp
            );
            revert("Timelock: Execution failed");
        }
        
        ExecutionLog storage log = executionLogs[totalExecutedTransactions];
        log.txHash = txHash;
        log.executedAt = block.timestamp;
        log.executor = msg.sender;
        log.success = success;
        log.result = result;
        
        emit TransactionExecuted(
            txHash,
            target,
            value,
            signature,
            data,
            eta,
            msg.sender,
            block.timestamp
        );
    }
    
    /// @notice Execute multiple queued transactions
    function executeTransactionBatch(
        address[] calldata targets,
        uint256[] calldata values,
        string[] calldata signatures,
        bytes[] calldata calldatas,
        uint256[] calldata etas
    )
        external
        payable
        onlyRole(EXECUTOR_ROLE)
        nonReentrant
    {
        require(targets.length == values.length, "Timelock: Length mismatch");
        require(targets.length == signatures.length, "Timelock: Length mismatch");
        require(targets.length == calldatas.length, "Timelock: Length mismatch");
        require(targets.length == etas.length, "Timelock: Length mismatch");
        require(targets.length > 0 && targets.length <= 10, "Timelock: Invalid batch size");
        
        for (uint256 i = 0; i < targets.length; i++) {
            executeTransaction(
                targets[i],
                values[i],
                signatures[i],
                calldatas[i],
                etas[i]
            );
        }
    }
    
    // ============= Cancellation Functions =============
    
    /// @notice Cancel queued transaction
    function cancelTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    )
        public
        onlyRole(CANCELLER_ROLE)
        nonReentrant
    {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        
        Transaction storage transaction = transactions[txHash];
        require(queuedTransactions[txHash], "Timelock: Not queued");
        require(!transaction.executed, "Timelock: Already executed");
        require(!transaction.cancelled, "Timelock: Already cancelled");
        
        transaction.cancelled = true;
        queuedTransactions[txHash] = false;
        
        emit TransactionCancelled(
            txHash,
            target,
            value,
            signature,
            data,
            eta,
            msg.sender,
            block.timestamp
        );
    }
    
    /// @notice Cancel multiple transactions
    function cancelTransactionBatch(
        address[] calldata targets,
        uint256[] calldata values,
        string[] calldata signatures,
        bytes[] calldata calldatas,
        uint256[] calldata etas
    )
        external
        onlyRole(CANCELLER_ROLE)
        nonReentrant
    {
        require(targets.length == values.length, "Timelock: Length mismatch");
        require(targets.length == signatures.length, "Timelock: Length mismatch");
        require(targets.length == calldatas.length, "Timelock: Length mismatch");
        require(targets.length == etas.length, "Timelock: Length mismatch");
        
        for (uint256 i = 0; i < targets.length; i++) {
            cancelTransaction(
                targets[i],
                values[i],
                signatures[i],
                calldatas[i],
                etas[i]
            );
        }
    }
    
    // ============= Configuration Functions =============
    
    /// @notice Update standard delay
    function updateDelay(uint256 newDelay)
        external
        onlyRole(TIMELOCK_ADMIN_ROLE)
    {
        require(newDelay >= MIN_DELAY, "Timelock: Delay too short");
        require(newDelay <= MAX_DELAY, "Timelock: Delay too long");
        
        uint256 oldDelay = delayConfig.standard;
        delayConfig.standard = newDelay;
        delayConfig.lastUpdated = block.timestamp;
        delayConfig.updatedBy = msg.sender;
        
        emit DelayUpdated(oldDelay, newDelay, msg.sender, block.timestamp);
    }
    
    /// @notice Update emergency delay
    function updateEmergencyDelay(uint256 newDelay)
        external
        onlyRole(TIMELOCK_ADMIN_ROLE)
    {
        require(newDelay > 0, "Timelock: Invalid delay");
        require(newDelay <= delayConfig.standard, "Timelock: Emergency must be shorter");
        
        uint256 oldDelay = delayConfig.emergency;
        delayConfig.emergency = newDelay;
        
        emit EmergencyDelayUpdated(oldDelay, newDelay, msg.sender, block.timestamp);
    }
    
    /// @notice Update governance address
    function updateGovernance(address newGovernance)
        external
        onlyRole(TIMELOCK_ADMIN_ROLE)
    {
        require(newGovernance != address(0), "Timelock: Invalid governance");
        
        address oldGovernance = governance;
        governance = newGovernance;
        
        _revokeRole(PROPOSER_ROLE, oldGovernance);
        _grantRole(PROPOSER_ROLE, newGovernance);
        
        emit GovernanceUpdated(oldGovernance, newGovernance, msg.sender, block.timestamp);
    }
    
    // ============= View Functions =============
    
    /// @notice Get transaction details
    function getTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    )
        external
        view
        returns (Transaction memory)
    {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        return transactions[txHash];
    }
    
    /// @notice Check if transaction is queued
    function isQueued(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    )
        external
        view
        returns (bool)
    {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        return queuedTransactions[txHash];
    }
    
    /// @notice Check if transaction is ready for execution
    function isReady(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    )
        external
        view
        returns (bool)
    {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        Transaction storage transaction = transactions[txHash];
        
        return queuedTransactions[txHash] &&
               !transaction.executed &&
               !transaction.cancelled &&
               block.timestamp >= transaction.eta &&
               block.timestamp < transaction.eta + GRACE_PERIOD;
    }
    
    /// @notice Check if transaction is expired
    function isExpired(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    )
        external
        view
        returns (bool)
    {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        Transaction storage transaction = transactions[txHash];
        
        return queuedTransactions[txHash] &&
               !transaction.executed &&
               block.timestamp >= transaction.eta + GRACE_PERIOD;
    }
    
    /// @notice Get execution log
    function getExecutionLog(uint256 logIndex)
        external
        view
        returns (ExecutionLog memory)
    {
        return executionLogs[logIndex];
    }
    
    /// @notice Get delay configuration
    function getDelayConfig()
        external
        view
        returns (DelayConfig memory)
    {
        return delayConfig;
    }
    
    // ============= Internal Functions =============
    
    function _getRevertReason(bytes memory result)
        internal
        pure
        returns (string memory)
    {
        if (result.length < 68) return "Execution reverted";
        
        assembly {
            result := add(result, 0x04)
        }
        
        return abi.decode(result, (string));
    }
    
    // ============= Fallback =============
    
    receive() external payable {}
}
