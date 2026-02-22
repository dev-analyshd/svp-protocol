// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title SVPToken
 * @notice Security token for fractional asset ownership in SVP Protocol
 * @dev ERC-20 compatible with snapshot capability for voting
 * @author Hudu Yusuf (Analys)
 */
contract SVPToken is
    ERC20,
    ERC20Burnable,
    ERC20Snapshot,
    AccessControl,
    Pausable
{
    // ============= Constants =============
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant SNAPSHOT_ROLE = keccak256("SNAPSHOT_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");
    
    // ============= Data Structures =============
    
    /// @notice Transfer restriction info
    struct TransferRestriction {
        bool restricted;             // Is transfer restricted
        uint256 restrictionStart;    // When restriction starts (0 = always)
        uint256 restrictionEnd;      // When restriction ends (0 = never)
        string reason;               // Reason for restriction
    }
    
    /// @notice Whitelist entry
    struct WhitelistEntry {
        bool whitelisted;            // Is address whitelisted
        uint8 tierLevel;             // Investor tier (0=retail, 1=accredited, 2=institutional)
        uint256 whitelistTimestamp;  // When whitelisted
        uint256 maxHolding;          // Max tokens allowed to hold (0 = unlimited)
    }
    
    // ============= State Variables =============
    
    /// @notice Asset this token represents
    address public asset;
    
    /// @notice Token metadata
    string public tokenSymbol;
    string public documentURI;  // IPFS/HTTP link to token documentation
    
    /// @notice Total supply cap (0 = unlimited)
    uint256 public supplyCap;
    
    /// @notice Transfer restrictions per address
    mapping(address => TransferRestriction) public transferRestrictions;
    
    /// @notice Whitelist status per address
    mapping(address => WhitelistEntry) public whitelist;
    
    /// @notice Frozen accounts (cannot transfer)
    mapping(address => bool) public frozenAccounts;
    
    /// @notice Snapshot history
    uint256 public currentSnapshotId;
    
    // ============= Events =============
    
    /// @notice Emitted when account is frozen
    event AccountFrozen(address indexed account, uint256 timestamp);
    
    /// @notice Emitted when account is unfrozen
    event AccountUnfrozen(address indexed account, uint256 timestamp);
    
    /// @notice Emitted when transfer restriction is set
    event TransferRestrictionSet(
        address indexed account,
        bool restricted,
        uint256 restrictionStart,
        uint256 restrictionEnd,
        string reason,
        uint256 timestamp
    );
    
    /// @notice Emitted when transfer restriction is removed
    event TransferRestrictionRemoved(address indexed account, uint256 timestamp);
    
    /// @notice Emitted when address is whitelisted
    event AddressWhitelisted(
        address indexed account,
        uint8 tierLevel,
        uint256 maxHolding,
        uint256 timestamp
    );
    
    /// @notice Emitted when address is removed from whitelist
    event AddressRemovedFromWhitelist(address indexed account, uint256 timestamp);
    
    /// @notice Emitted when whitelist is enforced
    event WhitelistEnforced(bool enforced, uint256 timestamp);
    
    /// @notice Emitted when snapshot is created
    event SnapshotCreated(uint256 indexed snapshotId, uint256 timestamp);
    
    /// @notice Emitted when supply cap is set
    event SupplyCapSet(uint256 newCap, uint256 timestamp);
    
    // ============= Enforcement Flags =============
    
    /// @notice Is whitelist enforcement enabled
    bool public whitelistEnforced;
    
    // ============= Constructor =============
    
    /**
     * @notice Initialize SVP Token
     * @param name Token name
     * @param symbol Token symbol
     * @param asset_ Asset this token represents
     * @param documentURI_ IPFS/HTTP URI for token documentation
     * @param initialSupplyCap Supply cap (0 = unlimited)
     */
    constructor(
        string memory name,
        string memory symbol,
        address asset_,
        string memory documentURI_,
        uint256 initialSupplyCap
    ) ERC20(name, symbol) {
        require(asset_ != address(0), "SVPToken: Invalid asset address");
        
        asset = asset_;
        tokenSymbol = symbol;
        documentURI = documentURI_;
        supplyCap = initialSupplyCap;
        whitelistEnforced = false;
        currentSnapshotId = 0;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
        _grantRole(SNAPSHOT_ROLE, msg.sender);
        _grantRole(COMPLIANCE_ROLE, msg.sender);
    }
    
    // ============= Minting & Burning =============
    
    /**
     * @notice Mint new tokens (minter role only)
     * @param to Recipient address
     * @param amount Amount to mint in wei
     */
    function mint(address to, uint256 amount)
        external
        onlyRole(MINTER_ROLE)
        whenNotPaused
    {
        require(to != address(0), "SVPToken: Cannot mint to zero address");
        require(amount > 0, "SVPToken: Amount must be positive");
        
        // Check supply cap
        if (supplyCap > 0) {
            require(totalSupply() + amount <= supplyCap, "SVPToken: Supply cap exceeded");
        }
        
        // Check whitelist if enforced
        if (whitelistEnforced) {
            require(whitelist[to].whitelisted, "SVPToken: Recipient not whitelisted");
            if (whitelist[to].maxHolding > 0) {
                require(
                    balanceOf(to) + amount <= whitelist[to].maxHolding,
                    "SVPToken: Max holding exceeded"
                );
            }
        }
        
        _mint(to, amount);
    }
    
    /**
     * @notice Burn tokens from sender
     * @param amount Amount to burn in wei
     */
    function burn(uint256 amount)
        public
        override
        whenNotPaused
    {
        require(amount > 0, "SVPToken: Amount must be positive");
        super.burn(amount);
    }
    
    /**
     * @notice Burn tokens from specific address (burner role)
     * @param account Account to burn from
     * @param amount Amount to burn
     */
    function burnFrom(address account, uint256 amount)
        public
        override
        onlyRole(BURNER_ROLE)
        whenNotPaused
    {
        require(account != address(0), "SVPToken: Invalid account");
        require(amount > 0, "SVPToken: Amount must be positive");
        super.burnFrom(account, amount);
    }
    
    // ============= Transfer Control =============
    
    /**
     * @notice Transfer tokens (with compliance checks)
     * @param to Recipient address
     * @param amount Amount to transfer
     */
    function transfer(address to, uint256 amount)
        public
        override
        whenNotPaused
        returns (bool)
    {
        _checkTransferCompliance(msg.sender, to, amount);
        return super.transfer(to, amount);
    }
    
    /**
     * @notice Transfer tokens from sender to recipient (with compliance)
     * @param from Sender address
     * @param to Recipient address
     * @param amount Amount to transfer
     */
    function transferFrom(address from, address to, uint256 amount)
        public
        override
        whenNotPaused
        returns (bool)
    {
        _checkTransferCompliance(from, to, amount);
        return super.transferFrom(from, to, amount);
    }
    
    /**
     * @notice Internal transfer compliance check
     * @param from Sender
     * @param to Recipient
     * @param amount Amount being transferred
     */
    function _checkTransferCompliance(address from, address to, uint256 amount)
        internal
        view
    {
        require(from != address(0), "SVPToken: Invalid from address");
        require(to != address(0), "SVPToken: Invalid to address");
        require(amount > 0, "SVPToken: Amount must be positive");
        
        // Check if sender is frozen
        require(!frozenAccounts[from], "SVPToken: Sender account is frozen");
        
        // Check if recipient is frozen
        require(!frozenAccounts[to], "SVPToken: Recipient account is frozen");
        
        // Check transfer restrictions
        TransferRestriction memory restriction = transferRestrictions[from];
        if (restriction.restricted) {
            if (restriction.restrictionStart == 0 || block.timestamp >= restriction.restrictionStart) {
                if (restriction.restrictionEnd == 0 || block.timestamp < restriction.restrictionEnd) {
                    revert("SVPToken: Transfer restricted for this account");
                }
            }
        }
        
        // Check whitelist if enforced
        if (whitelistEnforced) {
            require(whitelist[to].whitelisted, "SVPToken: Recipient not whitelisted");
            if (whitelist[to].maxHolding > 0) {
                require(
                    balanceOf(to) + amount <= whitelist[to].maxHolding,
                    "SVPToken: Max holding exceeded"
                );
            }
        }
    }
    
    // ============= Account Freezing =============
    
    /**
     * @notice Freeze an account (compliance role)
     * @param account Account to freeze
     */
    function freezeAccount(address account)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        require(account != address(0), "SVPToken: Invalid account");
        frozenAccounts[account] = true;
        emit AccountFrozen(account, block.timestamp);
    }
    
    /**
     * @notice Unfreeze an account (compliance role)
     * @param account Account to unfreeze
     */
    function unfreezeAccount(address account)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        require(account != address(0), "SVPToken: Invalid account");
        frozenAccounts[account] = false;
        emit AccountUnfrozen(account, block.timestamp);
    }
    
    /**
     * @notice Check if account is frozen
     * @param account Account to check
     * @return True if frozen
     */
    function isFrozen(address account) external view returns (bool) {
        return frozenAccounts[account];
    }
    
    // ============= Transfer Restrictions =============
    
    /**
     * @notice Set transfer restriction for account
     * @param account Account to restrict
     * @param restrictionStart Restriction start timestamp (0 = immediate)
     * @param restrictionEnd Restriction end timestamp (0 = permanent)
     * @param reason Reason for restriction
     */
    function setTransferRestriction(
        address account,
        uint256 restrictionStart,
        uint256 restrictionEnd,
        string calldata reason
    )
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        require(account != address(0), "SVPToken: Invalid account");
        
        transferRestrictions[account] = TransferRestriction({
            restricted: true,
            restrictionStart: restrictionStart,
            restrictionEnd: restrictionEnd,
            reason: reason
        });
        
        emit TransferRestrictionSet(
            account,
            true,
            restrictionStart,
            restrictionEnd,
            reason,
            block.timestamp
        );
    }
    
    /**
     * @notice Remove transfer restriction
     * @param account Account to unrestrict
     */
    function removeTransferRestriction(address account)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        require(account != address(0), "SVPToken: Invalid account");
        delete transferRestrictions[account];
        emit TransferRestrictionRemoved(account, block.timestamp);
    }
    
    /**
     * @notice Get transfer restriction status
     * @param account Account to check
     * @return Restriction details
     */
    function getTransferRestriction(address account)
        external
        view
        returns (TransferRestriction memory)
    {
        return transferRestrictions[account];
    }
    
    // ============= Whitelist Management =============
    
    /**
     * @notice Add address to whitelist
     * @param account Address to whitelist
     * @param tierLevel Investor tier (0=retail, 1=accredited, 2=institutional)
     * @param maxHolding Maximum tokens allowed to hold (0 = unlimited)
     */
    function addToWhitelist(address account, uint8 tierLevel, uint256 maxHolding)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        require(account != address(0), "SVPToken: Invalid account");
        require(tierLevel <= 2, "SVPToken: Invalid tier level");
        
        whitelist[account] = WhitelistEntry({
            whitelisted: true,
            tierLevel: tierLevel,
            whitelistTimestamp: block.timestamp,
            maxHolding: maxHolding
        });
        
        emit AddressWhitelisted(account, tierLevel, maxHolding, block.timestamp);
    }
    
    /**
     * @notice Remove address from whitelist
     * @param account Address to remove
     */
    function removeFromWhitelist(address account)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        require(account != address(0), "SVPToken: Invalid account");
        delete whitelist[account];
        emit AddressRemovedFromWhitelist(account, block.timestamp);
    }
    
    /**
     * @notice Check if address is whitelisted
     * @param account Address to check
     * @return True if whitelisted
     */
    function isWhitelisted(address account) external view returns (bool) {
        return whitelist[account].whitelisted;
    }
    
    /**
     * @notice Get whitelist entry
     * @param account Address to check
     * @return Whitelist entry
     */
    function getWhitelistEntry(address account)
        external
        view
        returns (WhitelistEntry memory)
    {
        return whitelist[account];
    }
    
    /**
     * @notice Enable/disable whitelist enforcement
     * @param enforce True to enforce whitelist
     */
    function setWhitelistEnforcement(bool enforce)
        external
        onlyRole(ADMIN_ROLE)
    {
        whitelistEnforced = enforce;
        emit WhitelistEnforced(enforce, block.timestamp);
    }
    
    // ============= Supply Management =============
    
    /**
     * @notice Set supply cap
     * @param newCap New supply cap (0 = unlimited)
     */
    function setSupplyCap(uint256 newCap)
        external
        onlyRole(ADMIN_ROLE)
    {
        supplyCap = newCap;
        emit SupplyCapSet(newCap, block.timestamp);
    }
    
    // ============= Snapshot Functions =============
    
    /**
     * @notice Create a snapshot for voting purposes
     * @return Snapshot ID
     */
    function snapshot() external onlyRole(SNAPSHOT_ROLE) returns (uint256) {
        currentSnapshotId++;
        _snapshot();
        emit SnapshotCreated(currentSnapshotId, block.timestamp);
        return currentSnapshotId;
    }
    
    /**
     * @notice Get balance at specific snapshot
     * @param account Account to check
     * @param snapshotId Snapshot ID
     * @return Balance at snapshot
     */
    function balanceOfAt(address account, uint256 snapshotId)
        public
        view
        override(ERC20Snapshot)
        returns (uint256)
    {
        return super.balanceOfAt(account, snapshotId);
    }
    
    /**
     * @notice Get total supply at specific snapshot
     * @param snapshotId Snapshot ID
     * @return Total supply at snapshot
     */
    function totalSupplyAt(uint256 snapshotId)
        public
        view
        override(ERC20Snapshot)
        returns (uint256)
    {
        return super.totalSupplyAt(snapshotId);
    }
    
    // ============= Admin Functions =============
    
    /**
     * @notice Pause all transfers
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpause transfers
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    
    /**
     * @notice Update document URI
     * @param newURI New document URI
     */
    function setDocumentURI(string calldata newURI)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(bytes(newURI).length > 0, "SVPToken: URI required");
        documentURI = newURI;
    }
    
    // ============= Internal Functions =============
    
    /**
     * @notice Hook called before any token transfer
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        override(ERC20, ERC20Snapshot)
        whenNotPaused
    {
        super._beforeTokenTransfer(from, to, amount);
    }
    
    /**
     * @notice Hook called after token transfer
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        override(ERC20)
    {
        super._afterTokenTransfer(from, to, amount);
    }
    
    /**
     * @notice Hook called during minting
     */
    function _mint(address to, uint256 amount)
        internal
        override(ERC20)
    {
        super._mint(to, amount);
    }
    
    /**
     * @notice Hook called during burning
     */
    function _burn(address account, uint256 amount)
        internal
        override(ERC20)
    {
        super._burn(account, amount);
    }
}
