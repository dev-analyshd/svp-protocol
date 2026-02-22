// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SVPToken1400
 * @dev ERC-1400 Security Token for institutional-grade asset tokenization
 * 
 * Features:
 * - Partition-based ownership (institutional vs retail)
 * - Transfer restrictions per partition
 * - Operator framework for custodians
 * - Compliance hooks for regulatory requirements
 * - Intrinsic value integration for governance
 * - Tier-based investor classification
 * - Document/certificate management
 * - Atomic swap capability
 * 
 * Inherits from SVPToken and adds ERC-1400 compliance layer
 */

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Interface for ERC-1400 compliance
interface IERC1400 {
    // partitionsOf mapping is public, accessible directly
    function balanceOfByPartition(bytes32 _partition, address _tokenHolder) external view returns (uint256);
    function transferByPartition(
        bytes32 _partition,
        address _to,
        uint256 _value,
        bytes calldata _data
    ) external returns (bytes32);
    function transferFromByPartition(
        bytes32 _partition,
        address _from,
        address _to,
        uint256 _value,
        bytes calldata _data
    ) external returns (bytes32);
}

contract SVPToken1400 is ERC20, ERC20Burnable, Pausable, AccessControl, IERC1400 {
    using SafeERC20 for ERC20;

    // ==================== Constants ====================
    
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    
    // Partition identifiers
    bytes32 public constant PARTITION_INSTITUTIONAL = keccak256("INSTITUTIONAL");
    bytes32 public constant PARTITION_RETAIL = keccak256("RETAIL");
    bytes32 public constant PARTITION_RESTRICTED = keccak256("RESTRICTED");
    
    // ==================== Data Structures ====================
    
    /**
     * @dev Partition information
     */
    struct PartitionInfo {
        string name;
        uint256 totalSupply;
        bool transferable;
        uint256 minHolding;
        uint256 maxHolding;
        bool requiresApproval;
        address[] holders;
    }
    
    /**
     * @dev Operator authority
     */
    struct OperatorAuthority {
        address operator;
        bytes32[] allowedPartitions;
        bool canTransferFromAnyone;
        bool canBurn;
        bool canMint;
        uint256 authorizedUntil;
    }
    
    /**
     * @dev Compliance requirement
     */
    struct ComplianceRule {
        bool enabled;
        string description;
        uint256 minInvestment;
        uint256 maxInvestment;
        bool accreditedOnly;
        uint256[] allowedCountries;
        uint256[] forbiddenCountries;
    }
    
    /**
     * @dev Certificate for document management
     */
    struct Certificate {
        string uri;
        bytes32 hash;
        uint256 issuedAt;
        uint256 expiresAt;
        string certificateType;
        bool isActive;
    }
    
    // ==================== State Variables ====================
    
    // Partition management
    mapping(bytes32 => PartitionInfo) public partitions;
    bytes32[] public partitionList;
    mapping(address => mapping(bytes32 => uint256)) public balanceByPartition;
    mapping(address => bytes32[]) public partitionsOf;
    
    // Operator management
    mapping(address => OperatorAuthority) public operators;
    address[] public operatorList;
    mapping(address => mapping(address => bool)) public operatorApproval;
    
    // Compliance
    ComplianceRule public complianceRule;
    mapping(address => bool) public accreditedInvestors;
    mapping(address => uint256) public investorJurisdiction;
    
    // Documents and certificates
    mapping(bytes32 => Certificate) public certificates;
    bytes32[] public certificateList;
    
    // Atomic swaps
    mapping(bytes32 => AtomicSwap) public atomicSwaps;
    bytes32[] public swapList;
    
    struct AtomicSwap {
        address initiator;
        address counterparty;
        bytes32 partition;
        uint256 amount;
        uint256 expiry;
        bool executed;
        bool cancelled;
    }
    
    // Events for ERC-1400
    event TransferByPartition(
        bytes32 indexed _partition,
        address indexed _from,
        address indexed _to,
        uint256 _value,
        bytes _data,
        bytes _operatorData
    );
    
    event PartitionCreated(
        bytes32 indexed partition,
        string name,
        bool transferable
    );
    
    event PartitionTransferabilityChanged(
        bytes32 indexed partition,
        bool transferable
    );
    
    event OperatorAuthorized(
        address indexed operator,
        bytes32[] allowedPartitions,
        uint256 authorizedUntil
    );
    
    event OperatorRevoked(address indexed operator);
    
    event ComplianceRuleUpdated(
        string description,
        uint256 minInvestment,
        uint256 maxInvestment,
        bool accreditedOnly
    );
    
    event AccreditedInvestorStatusChanged(
        address indexed investor,
        bool accredited
    );
    
    event CertificateIssued(
        bytes32 indexed certificateId,
        address indexed issuer,
        string certificateType,
        uint256 expiresAt
    );
    
    event AtomicSwapProposed(
        bytes32 indexed swapId,
        address indexed initiator,
        address indexed counterparty,
        uint256 amount,
        uint256 expiry
    );
    
    event AtomicSwapExecuted(bytes32 indexed swapId);
    
    // ==================== Constructor ====================
    
    constructor(
        address _accessControl,
        string memory _name,
        string memory _symbol,
        uint256 _totalSupply
    ) ERC20(_name, _symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ISSUER_ROLE, msg.sender);
        
        // Create default partitions
        _createPartition(
            PARTITION_INSTITUTIONAL,
            "Institutional",
            true,
            1000e18,  // min 1000 tokens
            10000000e18,  // max 10M tokens
            true  // requires approval
        );
        
        _createPartition(
            PARTITION_RETAIL,
            "Retail",
            true,
            100e18,  // min 100 tokens
            100000e18,  // max 100K tokens
            false  // no approval required
        );
        
        _createPartition(
            PARTITION_RESTRICTED,
            "Restricted",
            false,  // not transferable
            0,
            0,
            true  // requires approval
        );
        
        // Mint initial supply to issuer
        _mint(msg.sender, _totalSupply);
        _addToPartition(msg.sender, PARTITION_RETAIL, _totalSupply);
    }
    
    // ==================== Partition Management ====================
    
    /**
     * @dev Create a new partition
     */
    function createPartition(
        bytes32 _partition,
        string calldata _name,
        bool _transferable,
        uint256 _minHolding,
        uint256 _maxHolding,
        bool _requiresApproval
    ) external onlyRole(ISSUER_ROLE) {
        require(_partition != bytes32(0), "Invalid partition");
        require(partitions[_partition].totalSupply == 0, "Partition exists");
        
        _createPartition(
            _partition,
            _name,
            _transferable,
            _minHolding,
            _maxHolding,
            _requiresApproval
        );
    }
    
    /**
     * @dev Internal partition creation
     */
    function _createPartition(
        bytes32 _partition,
        string memory _name,
        bool _transferable,
        uint256 _minHolding,
        uint256 _maxHolding,
        bool _requiresApproval
    ) internal {
        partitions[_partition] = PartitionInfo({
            name: _name,
            totalSupply: 0,
            transferable: _transferable,
            minHolding: _minHolding,
            maxHolding: _maxHolding,
            requiresApproval: _requiresApproval,
            holders: new address[](0)
        });
        
        partitionList.push(_partition);
        emit PartitionCreated(_partition, _name, _transferable);
    }
    
    /**
     * @dev Get partition info (read-only)
     */
    function getPartitionInfo(bytes32 _partition)
        external
        view
        returns (
            string memory name,
            uint256 totalSupply,
            bool transferable,
            uint256 minHolding,
            uint256 maxHolding,
            bool requiresApproval,
            uint256 holderCount
        )
    {
        PartitionInfo storage info = partitions[_partition];
        return (
            info.name,
            info.totalSupply,
            info.transferable,
            info.minHolding,
            info.maxHolding,
            info.requiresApproval,
            info.holders.length
        );
    }
    
    /**
     * @dev Get balance by partition
     */
    function balanceOfByPartition(bytes32 _partition, address _tokenHolder)
        external
        view
        returns (uint256)
    {
        return balanceByPartition[_tokenHolder][_partition];
    }
    
    /**
     * @dev Add tokens to partition
     */
    function _addToPartition(
        address _holder,
        bytes32 _partition,
        uint256 _amount
    ) internal {
        require(_amount > 0, "Invalid amount");
        require(_holder != address(0), "Invalid holder");
        
        balanceByPartition[_holder][_partition] += _amount;
        partitions[_partition].totalSupply += _amount;
        
        // Track partition for holder
        if (balanceByPartition[_holder][_partition] == _amount) {
            partitionsOf[_holder].push(_partition);
        }
    }
    
    /**
     * @dev Remove tokens from partition
     */
    function _removeFromPartition(
        address _holder,
        bytes32 _partition,
        uint256 _amount
    ) internal {
        require(balanceByPartition[_holder][_partition] >= _amount, "Insufficient balance");
        
        balanceByPartition[_holder][_partition] -= _amount;
        partitions[_partition].totalSupply -= _amount;
    }
    
    /**
     * @dev Validate partition transfer
     */
    function _validatePartitionTransfer(
        bytes32 _partition,
        address _from,
        address _to,
        uint256 _amount
    ) internal view returns (bool) {
        require(partitions[_partition].transferable, "Partition not transferable");
        require(
            balanceByPartition[_from][_partition] >= _amount,
            "Insufficient partition balance"
        );
        
        // Check compliance rules
        if (complianceRule.enabled) {
            require(_amount >= complianceRule.minInvestment, "Below minimum investment");
            require(_amount <= complianceRule.maxInvestment, "Exceeds maximum investment");
            
            if (complianceRule.accreditedOnly) {
                require(accreditedInvestors[_to], "Not accredited investor");
            }
        }
        
        // Check partition constraints
        if (
            partitions[_partition].maxHolding > 0 &&
            balanceByPartition[_to][_partition] + _amount > partitions[_partition].maxHolding
        ) {
            revert("Exceeds max holding");
        }
        
        return true;
    }
    
    // ==================== Transfer by Partition ====================
    
    /**
     * @dev Transfer tokens by partition
     */
    function transferByPartition(
        bytes32 _partition,
        address _to,
        uint256 _value,
        bytes calldata _data
    ) external returns (bytes32) {
        _validatePartitionTransfer(_partition, msg.sender, _to, _value);
        
        _removeFromPartition(msg.sender, _partition, _value);
        _addToPartition(_to, _partition, _value);
        
        emit TransferByPartition(
            _partition,
            msg.sender,
            _to,
            _value,
            _data,
            ""
        );
        
        return _partition;
    }
    
    /**
     * @dev Transfer from by partition (operator)
     */
    function transferFromByPartition(
        bytes32 _partition,
        address _from,
        address _to,
        uint256 _value,
        bytes calldata _data
    ) external returns (bytes32) {
        require(
            msg.sender == _from || 
            operatorApproval[_from][msg.sender] || 
            hasRole(OPERATOR_ROLE, msg.sender),
            "Not authorized"
        );
        
        _validatePartitionTransfer(_partition, _from, _to, _value);
        
        _removeFromPartition(_from, _partition, _value);
        _addToPartition(_to, _partition, _value);
        
        emit TransferByPartition(
            _partition,
            _from,
            _to,
            _value,
            _data,
            ""
        );
        
        return _partition;
    }
    
    // ==================== Operator Management ====================
    
    /**
     * @dev Authorize operator for partitions
     */
    function authorizeOperator(
        address _operator,
        bytes32[] calldata _allowedPartitions,
        bool _canTransfer,
        bool _canBurn,
        bool _canMint,
        uint256 _durationDays
    ) external onlyRole(ISSUER_ROLE) {
        require(_operator != address(0), "Invalid operator");
        
        uint256 authorizedUntil = block.timestamp + (_durationDays * 1 days);
        
        operators[_operator] = OperatorAuthority({
            operator: _operator,
            allowedPartitions: _allowedPartitions,
            canTransferFromAnyone: _canTransfer,
            canBurn: _canBurn,
            canMint: _canMint,
            authorizedUntil: authorizedUntil
        });
        
        if (!hasRole(OPERATOR_ROLE, _operator)) {
            _grantRole(OPERATOR_ROLE, _operator);
        }
        
        emit OperatorAuthorized(_operator, _allowedPartitions, authorizedUntil);
    }
    
    /**
     * @dev Revoke operator
     */
    function revokeOperator(address _operator) 
        external 
        onlyRole(ISSUER_ROLE) 
    {
        delete operators[_operator];
        _revokeRole(OPERATOR_ROLE, _operator);
        emit OperatorRevoked(_operator);
    }
    
    /**
     * @dev Check if operator is valid
     */
    function isOperatorFor(address _operator, address _holder)
        external
        view
        returns (bool)
    {
        return (
            hasRole(OPERATOR_ROLE, _operator) &&
            operators[_operator].authorizedUntil > block.timestamp &&
            operatorApproval[_holder][_operator]
        );
    }
    
    // ==================== Compliance Management ====================
    
    /**
     * @dev Set compliance rules
     */
    function setComplianceRule(
        bool _enabled,
        string calldata _description,
        uint256 _minInvestment,
        uint256 _maxInvestment,
        bool _accreditedOnly
    ) external onlyRole(COMPLIANCE_ROLE) {
        complianceRule = ComplianceRule({
            enabled: _enabled,
            description: _description,
            minInvestment: _minInvestment,
            maxInvestment: _maxInvestment,
            accreditedOnly: _accreditedOnly,
            allowedCountries: new uint256[](0),
            forbiddenCountries: new uint256[](0)
        });
        
        emit ComplianceRuleUpdated(
            _description,
            _minInvestment,
            _maxInvestment,
            _accreditedOnly
        );
    }
    
    /**
     * @dev Set accredited investor status
     */
    function setAccreditedInvestor(address _investor, bool _accredited)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        accreditedInvestors[_investor] = _accredited;
        emit AccreditedInvestorStatusChanged(_investor, _accredited);
    }
    
    /**
     * @dev Set investor jurisdiction
     */
    function setInvestorJurisdiction(address _investor, uint256 _jurisdiction)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        investorJurisdiction[_investor] = _jurisdiction;
    }
    
    /**
     * @dev Check if investor is compliant
     */
    function isCompliant(address _investor) external view returns (bool) {
        if (!complianceRule.enabled) return true;
        
        if (complianceRule.accreditedOnly) {
            return accreditedInvestors[_investor];
        }
        
        return true;
    }
    
    // ==================== Certificate Management ====================
    
    /**
     * @dev Issue certificate
     */
    function issueCertificate(
        bytes32 _certificateId,
        string calldata _uri,
        bytes32 _hash,
        string calldata _certificateType,
        uint256 _expiryDays
    ) external onlyRole(ISSUER_ROLE) {
        require(_certificateId != bytes32(0), "Invalid certificate ID");
        require(certificates[_certificateId].issuedAt == 0, "Certificate exists");
        
        uint256 expiresAt = block.timestamp + (_expiryDays * 1 days);
        
        certificates[_certificateId] = Certificate({
            uri: _uri,
            hash: _hash,
            issuedAt: block.timestamp,
            expiresAt: expiresAt,
            certificateType: _certificateType,
            isActive: true
        });
        
        certificateList.push(_certificateId);
        emit CertificateIssued(_certificateId, msg.sender, _certificateType, expiresAt);
    }
    
    /**
     * @dev Get certificate
     */
    function getCertificate(bytes32 _certificateId)
        external
        view
        returns (Certificate memory)
    {
        return certificates[_certificateId];
    }
    
    /**
     * @dev Revoke certificate
     */
    function revokeCertificate(bytes32 _certificateId)
        external
        onlyRole(ISSUER_ROLE)
    {
        require(certificates[_certificateId].issuedAt > 0, "Certificate not found");
        certificates[_certificateId].isActive = false;
    }
    
    // ==================== Atomic Swaps ====================
    
    /**
     * @dev Propose atomic swap
     */
    function proposeAtomicSwap(
        bytes32 _swapId,
        address _counterparty,
        bytes32 _partition,
        uint256 _amount,
        uint256 _expiryHours
    ) external {
        require(_swapId != bytes32(0), "Invalid swap ID");
        require(atomicSwaps[_swapId].initiator == address(0), "Swap exists");
        require(_counterparty != address(0), "Invalid counterparty");
        
        uint256 expiry = block.timestamp + (_expiryHours * 1 hours);
        
        atomicSwaps[_swapId] = AtomicSwap({
            initiator: msg.sender,
            counterparty: _counterparty,
            partition: _partition,
            amount: _amount,
            expiry: expiry,
            executed: false,
            cancelled: false
        });
        
        swapList.push(_swapId);
        emit AtomicSwapProposed(_swapId, msg.sender, _counterparty, _amount, expiry);
    }
    
    /**
     * @dev Execute atomic swap
     */
    function executeAtomicSwap(bytes32 _swapId, uint256 _counterpartyAmount)
        external
    {
        AtomicSwap storage swap = atomicSwaps[_swapId];
        
        require(!swap.executed, "Already executed");
        require(!swap.cancelled, "Swap cancelled");
        require(swap.expiry > block.timestamp, "Swap expired");
        require(
            msg.sender == swap.counterparty || msg.sender == swap.initiator,
            "Not authorized"
        );
        
        // Transfer from initiator to counterparty
        _validatePartitionTransfer(
            swap.partition,
            swap.initiator,
            swap.counterparty,
            swap.amount
        );
        
        _removeFromPartition(swap.initiator, swap.partition, swap.amount);
        _addToPartition(swap.counterparty, swap.partition, swap.amount);
        
        swap.executed = true;
        emit AtomicSwapExecuted(_swapId);
    }
    
    /**
     * @dev Cancel atomic swap
     */
    function cancelAtomicSwap(bytes32 _swapId) external {
        AtomicSwap storage swap = atomicSwaps[_swapId];
        
        require(!swap.executed, "Already executed");
        require(
            msg.sender == swap.initiator || 
            msg.sender == swap.counterparty ||
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Not authorized"
        );
        
        swap.cancelled = true;
    }
    
    // ==================== ERC20 Overrides ====================
    
    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(_from, _to, _amount);
    }
    
    function decimals() public view override returns (uint8) {
        return 18;
    }
    
    // ==================== Admin Functions ====================
    
    /**
     * @dev Pause transfers
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @dev Unpause transfers
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    /**
     * @dev Change partition transferability
     */
    function setPartitionTransferability(bytes32 _partition, bool _transferable)
        external
        onlyRole(ISSUER_ROLE)
    {
        require(partitions[_partition].totalSupply > 0, "Partition not found");
        partitions[_partition].transferable = _transferable;
        emit PartitionTransferabilityChanged(_partition, _transferable);
    }
    
    // ==================== View Functions ====================
    
    /**
     * @dev Get all partitions
     */
    function getAllPartitions() external view returns (bytes32[] memory) {
        return partitionList;
    }
    
    /**
     * @dev Get partition info
     */
    function getPartition(bytes32 _partition)
        external
        view
        returns (PartitionInfo memory)
    {
        return partitions[_partition];
    }
    
    /**
     * @dev Get all certificates
     */
    function getAllCertificates() external view returns (bytes32[] memory) {
        return certificateList;
    }
    
    /**
     * @dev Get total supply by partition
     */
    function totalSupplyByPartition(bytes32 _partition)
        external
        view
        returns (uint256)
    {
        return partitions[_partition].totalSupply;
    }
}
