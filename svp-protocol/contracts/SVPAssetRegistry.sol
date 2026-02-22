// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title SVPAssetRegistry
 * @notice Registry for tokenizable assets in SVP Protocol
 * @dev Maintains asset metadata, approval status, and ownership tracking
 * @author Hudu Yusuf (Analys)
 */
contract SVPAssetRegistry is AccessControl, Pausable {
    // ============= Constants =============
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");
    
    // ============= Data Structures =============
    
    /// @notice Asset registration details
    struct Asset {
        string name;                    // Asset name/ticker
        string metadataURI;             // IPFS/HTTP URI for full asset metadata
        address owner;                  // Asset owner (company/SME)
        bool approved;                  // Admin approval status
        bool active;                    // Is asset actively trading
        uint256 registrationTimestamp;  // When asset was registered
        uint256 approvalTimestamp;      // When asset was approved
        uint256 totalSupply;            // Total tokens issued for this asset
        string industry;                // Industry classification
        string jurisdiction;            // Jurisdiction/country
    }
    
    /// @notice Asset tier/class for compliance purposes
    struct AssetClass {
        uint8 tier;                     // 0 = retail, 1 = accredited, 2 = institutional
        bool restrictedTransfer;        // Are transfers restricted for this class
        uint256 minInvestment;          // Minimum investment in wei
    }
    
    // ============= State Variables =============
    
    /// @notice Registered assets mapping
    mapping(address => Asset) public assets;
    
    /// @notice Asset class definitions
    mapping(address => AssetClass) public assetClasses;
    
    /// @notice Array of all registered asset addresses
    address[] public registeredAssets;
    
    /// @notice Owner to assets mapping (for owner queries)
    mapping(address => address[]) public ownerAssets;
    
    /// @notice Industry registry counter
    mapping(string => uint256) public industryCount;
    
    /// @notice Jurisdiction registry counter
    mapping(string => uint256) public jurisdictionCount;
    
    /// @notice Total assets registered
    uint256 public totalAssets;
    
    // ============= Events =============
    
    /// @notice Emitted when asset is registered
    event AssetRegistered(
        address indexed asset,
        string name,
        address indexed owner,
        string metadataURI,
        uint256 timestamp
    );
    
    /// @notice Emitted when asset is approved
    event AssetApproved(
        address indexed asset,
        address indexed approver,
        uint256 timestamp
    );
    
    /// @notice Emitted when asset is rejected
    event AssetRejected(
        address indexed asset,
        string reason,
        address indexed rejector,
        uint256 timestamp
    );
    
    /// @notice Emitted when asset status is changed
    event AssetStatusChanged(
        address indexed asset,
        bool active,
        address indexed admin,
        uint256 timestamp
    );
    
    /// @notice Emitted when asset metadata is updated
    event AssetMetadataUpdated(
        address indexed asset,
        string newMetadataURI,
        address indexed updater,
        uint256 timestamp
    );
    
    /// @notice Emitted when asset class is set
    event AssetClassSet(
        address indexed asset,
        uint8 tier,
        bool restrictedTransfer,
        uint256 minInvestment,
        address indexed admin,
        uint256 timestamp
    );
    
    /// @notice Emitted when asset is deactivated
    event AssetDeactivated(
        address indexed asset,
        address indexed admin,
        uint256 timestamp
    );
    
    // ============= Constructor =============
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(REGISTRAR_ROLE, msg.sender);
    }
    
    // ============= Asset Registration Functions =============
    
    /**
     * @notice Register a new asset
     * @param asset Asset contract address (ERC-20/ERC-1400 token)
     * @param name Asset name or company name
     * @param metadataURI IPFS/HTTP URI pointing to full asset metadata
     * @param industry Industry classification
     * @param jurisdiction Jurisdiction/country of asset
     */
    function registerAsset(
        address asset,
        string memory name,
        string memory metadataURI,
        string memory industry,
        string memory jurisdiction
    )
        external
        onlyRole(REGISTRAR_ROLE)
        whenNotPaused
    {
        require(asset != address(0), "SVPAssetRegistry: Invalid asset address");
        require(bytes(name).length > 0, "SVPAssetRegistry: Name required");
        require(bytes(metadataURI).length > 0, "SVPAssetRegistry: MetadataURI required");
        require(assets[asset].owner == address(0), "SVPAssetRegistry: Asset already registered");
        
        // Create asset record
        assets[asset] = Asset({
            name: name,
            metadataURI: metadataURI,
            owner: msg.sender,
            approved: false,
            active: false,
            registrationTimestamp: block.timestamp,
            approvalTimestamp: 0,
            totalSupply: 0,
            industry: industry,
            jurisdiction: jurisdiction
        });
        
        // Track in arrays
        registeredAssets.push(asset);
        ownerAssets[msg.sender].push(asset);
        totalAssets++;
        
        // Update industry/jurisdiction counts
        industryCount[industry]++;
        jurisdictionCount[jurisdiction]++;
        
        emit AssetRegistered(asset, name, msg.sender, metadataURI, block.timestamp);
    }
    
    /**
     * @notice Approve an asset for trading
     * @param asset Asset address to approve
     */
    function approveAsset(address asset)
        external
        onlyRole(ADMIN_ROLE)
        whenNotPaused
    {
        require(asset != address(0), "SVPAssetRegistry: Invalid asset address");
        Asset storage assetData = assets[asset];
        require(assetData.owner != address(0), "SVPAssetRegistry: Asset not registered");
        require(!assetData.approved, "SVPAssetRegistry: Asset already approved");
        
        assetData.approved = true;
        assetData.active = true;
        assetData.approvalTimestamp = block.timestamp;
        
        emit AssetApproved(asset, msg.sender, block.timestamp);
    }
    
    /**
     * @notice Reject an asset (typically during review)
     * @param asset Asset address to reject
     * @param reason Reason for rejection
     */
    function rejectAsset(address asset, string calldata reason)
        external
        onlyRole(ADMIN_ROLE)
        whenNotPaused
    {
        require(asset != address(0), "SVPAssetRegistry: Invalid asset address");
        Asset storage assetData = assets[asset];
        require(assetData.owner != address(0), "SVPAssetRegistry: Asset not registered");
        require(!assetData.approved, "SVPAssetRegistry: Cannot reject approved asset");
        
        // Remove from registry
        _removeAsset(asset);
        
        emit AssetRejected(asset, reason, msg.sender, block.timestamp);
    }
    
    /**
     * @notice Deactivate an approved asset (pause trading)
     * @param asset Asset address to deactivate
     */
    function deactivateAsset(address asset)
        external
        onlyRole(ADMIN_ROLE)
        whenNotPaused
    {
        require(asset != address(0), "SVPAssetRegistry: Invalid asset address");
        Asset storage assetData = assets[asset];
        require(assetData.owner != address(0), "SVPAssetRegistry: Asset not registered");
        require(assetData.active, "SVPAssetRegistry: Asset already inactive");
        
        assetData.active = false;
        
        emit AssetDeactivated(asset, msg.sender, block.timestamp);
    }
    
    /**
     * @notice Reactivate a deactivated asset
     * @param asset Asset address to reactivate
     */
    function reactivateAsset(address asset)
        external
        onlyRole(ADMIN_ROLE)
        whenNotPaused
    {
        require(asset != address(0), "SVPAssetRegistry: Invalid asset address");
        Asset storage assetData = assets[asset];
        require(assetData.owner != address(0), "SVPAssetRegistry: Asset not registered");
        require(assetData.approved, "SVPAssetRegistry: Asset not approved");
        require(!assetData.active, "SVPAssetRegistry: Asset already active");
        
        assetData.active = true;
        
        emit AssetStatusChanged(asset, true, msg.sender, block.timestamp);
    }
    
    // ============= Asset Class Management =============
    
    /**
     * @notice Set asset class/tier
     * @param asset Asset address
     * @param tier Investor tier (0=retail, 1=accredited, 2=institutional)
     * @param restrictedTransfer Whether transfers are restricted
     * @param minInvestment Minimum investment amount in wei
     */
    function setAssetClass(
        address asset,
        uint8 tier,
        bool restrictedTransfer,
        uint256 minInvestment
    )
        external
        onlyRole(ADMIN_ROLE)
    {
        require(asset != address(0), "SVPAssetRegistry: Invalid asset address");
        require(tier <= 2, "SVPAssetRegistry: Invalid tier");
        require(assets[asset].owner != address(0), "SVPAssetRegistry: Asset not registered");
        
        assetClasses[asset] = AssetClass({
            tier: tier,
            restrictedTransfer: restrictedTransfer,
            minInvestment: minInvestment
        });
        
        emit AssetClassSet(asset, tier, restrictedTransfer, minInvestment, msg.sender, block.timestamp);
    }
    
    // ============= Metadata Management =============
    
    /**
     * @notice Update asset metadata URI
     * @param asset Asset address
     * @param newMetadataURI New metadata URI
     */
    function updateMetadata(address asset, string calldata newMetadataURI)
        external
        onlyRole(ADMIN_ROLE)
        whenNotPaused
    {
        require(asset != address(0), "SVPAssetRegistry: Invalid asset address");
        require(bytes(newMetadataURI).length > 0, "SVPAssetRegistry: MetadataURI required");
        Asset storage assetData = assets[asset];
        require(assetData.owner != address(0), "SVPAssetRegistry: Asset not registered");
        
        assetData.metadataURI = newMetadataURI;
        
        emit AssetMetadataUpdated(asset, newMetadataURI, msg.sender, block.timestamp);
    }
    
    /**
     * @notice Update total supply for asset
     * @param asset Asset address
     * @param newSupply New total supply
     */
    function updateTotalSupply(address asset, uint256 newSupply)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(asset != address(0), "SVPAssetRegistry: Invalid asset address");
        Asset storage assetData = assets[asset];
        require(assetData.owner != address(0), "SVPAssetRegistry: Asset not registered");
        
        assetData.totalSupply = newSupply;
    }
    
    // ============= View Functions =============
    
    /**
     * @notice Get asset details
     * @param asset Asset address
     * @return Asset data struct
     */
    function getAsset(address asset) external view returns (Asset memory) {
        return assets[asset];
    }
    
    /**
     * @notice Check if asset is registered
     * @param asset Asset address
     * @return True if registered
     */
    function isAssetRegistered(address asset) external view returns (bool) {
        return assets[asset].owner != address(0);
    }
    
    /**
     * @notice Check if asset is approved
     * @param asset Asset address
     * @return True if approved
     */
    function isAssetApproved(address asset) external view returns (bool) {
        return assets[asset].approved;
    }
    
    /**
     * @notice Check if asset is active
     * @param asset Asset address
     * @return True if active
     */
    function isAssetActive(address asset) external view returns (bool) {
        return assets[asset].active;
    }
    
    /**
     * @notice Get asset class
     * @param asset Asset address
     * @return Asset class data
     */
    function getAssetClass(address asset) external view returns (AssetClass memory) {
        return assetClasses[asset];
    }
    
    /**
     * @notice Get all registered assets
     * @return Array of registered asset addresses
     */
    function getAllAssets() external view returns (address[] memory) {
        return registeredAssets;
    }
    
    /**
     * @notice Get registered assets count
     * @return Number of registered assets
     */
    function getAssetCount() external view returns (uint256) {
        return registeredAssets.length;
    }
    
    /**
     * @notice Get assets owned by address
     * @param owner Owner address
     * @return Array of asset addresses
     */
    function getOwnerAssets(address owner) external view returns (address[] memory) {
        return ownerAssets[owner];
    }
    
    /**
     * @notice Get count of assets by industry
     * @param industry Industry name
     * @return Count of assets
     */
    function getIndustryCount(string calldata industry) external view returns (uint256) {
        return industryCount[industry];
    }
    
    /**
     * @notice Get count of assets by jurisdiction
     * @param jurisdiction Jurisdiction name
     * @return Count of assets
     */
    function getJurisdictionCount(string calldata jurisdiction) external view returns (uint256) {
        return jurisdictionCount[jurisdiction];
    }
    
    // ============= Admin Functions =============
    
    /**
     * @notice Pause all operations
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpause all operations
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    // ============= Internal Functions =============
    
    /**
     * @notice Remove asset from registry
     * @param asset Asset to remove
     */
    function _removeAsset(address asset) internal {
        Asset storage assetData = assets[asset];
        address owner = assetData.owner;
        
        // Update industry/jurisdiction counts
        industryCount[assetData.industry]--;
        jurisdictionCount[assetData.jurisdiction]--;
        
        // Remove from owner array
        address[] storage ownerAssetList = ownerAssets[owner];
        for (uint256 i = 0; i < ownerAssetList.length; i++) {
            if (ownerAssetList[i] == asset) {
                ownerAssetList[i] = ownerAssetList[ownerAssetList.length - 1];
                ownerAssetList.pop();
                break;
            }
        }
        
        // Remove from global array
        for (uint256 i = 0; i < registeredAssets.length; i++) {
            if (registeredAssets[i] == asset) {
                registeredAssets[i] = registeredAssets[registeredAssets.length - 1];
                registeredAssets.pop();
                break;
            }
        }
        
        // Delete asset data
        delete assets[asset];
        delete assetClasses[asset];
        totalAssets--;
    }
}
