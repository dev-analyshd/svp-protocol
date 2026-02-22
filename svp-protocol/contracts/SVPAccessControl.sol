// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title SVPAccessControl
 * @notice Centralized role-based access control for the SVP Protocol
 * @dev Defines all roles used across the protocol ecosystem
 * @author Hudu Yusuf (Analys)
 */
contract SVPAccessControl is AccessControl {
    // ============= Role Definitions =============
    
    /// @notice Role for submitting financial data
    bytes32 public constant REPORTER_ROLE = keccak256("REPORTER_ROLE");
    
    /// @notice Role for minting tokens
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    /// @notice Role for governance execution
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    
    /// @notice Role for emergency pause mechanisms
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    // ============= Events =============
    
    /// @notice Emitted when a role is granted
    event RoleGrantedToAddress(bytes32 indexed role, address indexed account, address indexed sender);
    
    /// @notice Emitted when a role is revoked
    event RoleRevokedFromAddress(bytes32 indexed role, address indexed account, address indexed sender);
    
    // ============= Constructor =============
    
    /**
     * @notice Initialize access control with DEFAULT_ADMIN_ROLE
     */
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    // ============= Role Management =============
    
    /**
     * @notice Grant a role to an address (overridden for custom events)
     * @param role Role identifier
     * @param account Address to grant role to
     */
    function grantRole(bytes32 role, address account) 
        public 
        override 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        _grantRole(role, account);
        emit RoleGrantedToAddress(role, account, msg.sender);
    }
    
    /**
     * @notice Revoke a role from an address (overridden for custom events)
     * @param role Role identifier
     * @param account Address to revoke role from
     */
    function revokeRole(bytes32 role, address account) 
        public 
        override 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        _revokeRole(role, account);
        emit RoleRevokedFromAddress(role, account, msg.sender);
    }
    
    // ============= Batch Operations =============
    
    /**
     * @notice Grant multiple roles to multiple addresses (gas-efficient)
     * @param roles Array of role identifiers
     * @param accounts Array of addresses
     * @dev Arrays must be same length
     */
    function grantRolesBatch(bytes32[] calldata roles, address[] calldata accounts)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(roles.length == accounts.length, "SVPAccessControl: Array length mismatch");
        
        for (uint256 i = 0; i < roles.length; i++) {
            _grantRole(roles[i], accounts[i]);
            emit RoleGrantedToAddress(roles[i], accounts[i], msg.sender);
        }
    }
    
    /**
     * @notice Revoke multiple roles from multiple addresses (gas-efficient)
     * @param roles Array of role identifiers
     * @param accounts Array of addresses
     * @dev Arrays must be same length
     */
    function revokeRolesBatch(bytes32[] calldata roles, address[] calldata accounts)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(roles.length == accounts.length, "SVPAccessControl: Array length mismatch");
        
        for (uint256 i = 0; i < roles.length; i++) {
            _revokeRole(roles[i], accounts[i]);
            emit RoleRevokedFromAddress(roles[i], accounts[i], msg.sender);
        }
    }
}
