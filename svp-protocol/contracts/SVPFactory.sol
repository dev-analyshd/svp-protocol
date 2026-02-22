// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title SVPFactory
 * @notice Factory for deploying SVP protocol instances
 * @dev Creates new tokens, vaults, and governance instances
 * @author Hudu Yusuf (Analys)
 */
contract SVPFactory is AccessControl {
    // ============= Constants =============
    
    bytes32 public constant FACTORY_ADMIN_ROLE = keccak256("FACTORY_ADMIN_ROLE");
    
    // ============= Data Structures =============
    
    /// @notice Deployment record
    struct Deployment {
        uint256 id;                    // Deployment ID
        address tokenAddress;          // SVP Token deployed
        address govAddress;            // Governance contract
        address vaultAddress;          // SPV Vault address
        address assetAddress;          // Asset being tokenized
        string assetName;              // Asset name
        address deployer;              // Who deployed
        uint256 deploymentTimestamp;   // When deployed
        bool active;                   // Is deployment active
    }
    
    // ============= State Variables =============
    
    /// @notice Implementation contracts (for proxies)
    address public tokenImplementation;
    address public governanceImplementation;
    address public vaultImplementation;
    
    /// @notice Deployed instances
    Deployment[] public deployments;
    
    /// @notice Token to deployment mapping
    mapping(address => uint256) public tokenToDeployment;
    
    /// @notice Governance to deployment mapping
    mapping(address => uint256) public govToDeployment;
    
    /// @notice Vault to deployment mapping
    mapping(address => uint256) public vaultToDeployment;
    
    /// @notice Deployer to deployments
    mapping(address => uint256[]) public deployerDeployments;
    
    /// @notice Total deployments
    uint256 public deploymentCount;
    
    // ============= Events =============
    
    /// @notice Emitted when new SVP instance is deployed
    event SVPInstanceDeployed(
        uint256 indexed deploymentId,
        address indexed token,
        address indexed governance,
        address vault,
        address asset,
        string assetName,
        address deployer,
        uint256 timestamp
    );
    
    /// @notice Emitted when deployment is deactivated
    event DeploymentDeactivated(
        uint256 indexed deploymentId,
        address indexed admin,
        uint256 timestamp
    );
    
    /// @notice Emitted when implementation is updated
    event ImplementationUpdated(
        address indexed tokenImpl,
        address indexed govImpl,
        address indexed vaultImpl,
        address admin,
        uint256 timestamp
    );
    
    // ============= Constructor =============
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(FACTORY_ADMIN_ROLE, msg.sender);
    }
    
    // ============= Deployment Functions =============
    
    /**
     * @notice Deploy new SVP instance
     * @param tokenImpl Token implementation address
     * @param govImpl Governance implementation address
     * @param vaultImpl Vault implementation address
     * @param asset Asset address being tokenized
     * @param assetName Asset name
     * @return deploymentId New deployment ID
     */
    function deployInstance(
        address tokenImpl,
        address govImpl,
        address vaultImpl,
        address asset,
        string calldata assetName
    )
        external
        onlyRole(FACTORY_ADMIN_ROLE)
        returns (uint256)
    {
        require(tokenImpl != address(0), "SVPFactory: Invalid token impl");
        require(govImpl != address(0), "SVPFactory: Invalid governance impl");
        require(vaultImpl != address(0), "SVPFactory: Invalid vault impl");
        require(asset != address(0), "SVPFactory: Invalid asset");
        require(bytes(assetName).length > 0, "SVPFactory: Asset name required");
        
        // Deploy token proxy
        bytes memory tokenData = _encodeTokenInitialize(assetName);
        ERC1967Proxy tokenProxy = new ERC1967Proxy(tokenImpl, tokenData);
        address tokenAddress = address(tokenProxy);
        
        // Deploy governance proxy
        bytes memory govData = _encodeGovInitialize(tokenAddress, asset);
        ERC1967Proxy govProxy = new ERC1967Proxy(govImpl, govData);
        address govAddress = address(govProxy);
        
        // Deploy vault proxy
        bytes memory vaultData = _encodeVaultInitialize(assetName);
        ERC1967Proxy vaultProxy = new ERC1967Proxy(vaultImpl, vaultData);
        address vaultAddress = address(vaultProxy);
        
        // Record deployment
        uint256 deploymentId = deploymentCount++;
        
        Deployment storage deployment = deployments.push();
        deployment.id = deploymentId;
        deployment.tokenAddress = tokenAddress;
        deployment.govAddress = govAddress;
        deployment.vaultAddress = vaultAddress;
        deployment.assetAddress = asset;
        deployment.assetName = assetName;
        deployment.deployer = msg.sender;
        deployment.deploymentTimestamp = block.timestamp;
        deployment.active = true;
        
        // Track mappings
        tokenToDeployment[tokenAddress] = deploymentId;
        govToDeployment[govAddress] = deploymentId;
        vaultToDeployment[vaultAddress] = deploymentId;
        deployerDeployments[msg.sender].push(deploymentId);
        
        emit SVPInstanceDeployed(
            deploymentId,
            tokenAddress,
            govAddress,
            vaultAddress,
            asset,
            assetName,
            msg.sender,
            block.timestamp
        );
        
        return deploymentId;
    }
    
    /**
     * @notice Deactivate a deployment
     * @param deploymentId Deployment ID to deactivate
     */
    function deactivateDeployment(uint256 deploymentId)
        external
        onlyRole(FACTORY_ADMIN_ROLE)
    {
        require(deploymentId < deployments.length, "SVPFactory: Invalid deployment ID");
        
        Deployment storage deployment = deployments[deploymentId];
        require(deployment.active, "SVPFactory: Deployment already inactive");
        
        deployment.active = false;
        
        emit DeploymentDeactivated(deploymentId, msg.sender, block.timestamp);
    }
    
    // ============= Implementation Management =============
    
    /**
     * @notice Set implementation contracts
     * @param tokenImpl New token implementation
     * @param govImpl New governance implementation
     * @param vaultImpl New vault implementation
     */
    function setImplementations(
        address tokenImpl,
        address govImpl,
        address vaultImpl
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(tokenImpl != address(0), "SVPFactory: Invalid token impl");
        require(govImpl != address(0), "SVPFactory: Invalid governance impl");
        require(vaultImpl != address(0), "SVPFactory: Invalid vault impl");
        
        tokenImplementation = tokenImpl;
        governanceImplementation = govImpl;
        vaultImplementation = vaultImpl;
        
        emit ImplementationUpdated(tokenImpl, govImpl, vaultImpl, msg.sender, block.timestamp);
    }
    
    // ============= View Functions =============
    
    /**
     * @notice Get deployment details
     * @param deploymentId Deployment ID
     * @return Deployment data
     */
    function getDeployment(uint256 deploymentId)
        external
        view
        returns (Deployment memory)
    {
        require(deploymentId < deployments.length, "SVPFactory: Invalid deployment ID");
        return deployments[deploymentId];
    }
    
    /**
     * @notice Get total deployments
     * @return Total count
     */
    function getTotalDeployments() external view returns (uint256) {
        return deployments.length;
    }
    
    /**
     * @notice Get deployments by deployer
     * @param deployer Deployer address
     * @return Array of deployment IDs
     */
    function getDeployerDeployments(address deployer)
        external
        view
        returns (uint256[] memory)
    {
        return deployerDeployments[deployer];
    }
    
    /**
     * @notice Check if token is managed
     * @param tokenAddress Token to check
     * @return True if managed
     */
    function isManagedToken(address tokenAddress) external view returns (bool) {
        return tokenToDeployment[tokenAddress] != 0 || 
               (deployments.length > 0 && deployments[0].tokenAddress == tokenAddress);
    }
    
    /**
     * @notice Get active deployments count
     * @return Active deployment count
     */
    function getActiveDeploymentCount() external view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < deployments.length; i++) {
            if (deployments[i].active) count++;
        }
        return count;
    }
    
    // ============= Internal Helper Functions =============
    
    /**
     * @notice Encode token initialization call data
     * @param name Asset name
     * @return Encoded init data
     */
    function _encodeTokenInitialize(string calldata name)
        internal
        pure
        returns (bytes memory)
    {
        // Placeholder: would encode SVPToken.initialize(name, symbol, asset, uri, cap)
        return abi.encodeWithSignature("initialize(string)", name);
    }
    
    /**
     * @notice Encode governance initialization call data
     * @param token Token address
     * @param asset Asset address
     * @return Encoded init data
     */
    function _encodeGovInitialize(address token, address asset)
        internal
        pure
        returns (bytes memory)
    {
        // Placeholder: would encode SVPGovernance constructor params
        return abi.encodeWithSignature("initialize(address,address)", token, asset);
    }
    
    /**
     * @notice Encode vault initialization call data
     * @param name Vault name
     * @return Encoded init data
     */
    function _encodeVaultInitialize(string calldata name)
        internal
        pure
        returns (bytes memory)
    {
        // Placeholder: would encode SVPSPVVault initialization
        return abi.encodeWithSignature("initialize(string)", name);
    }
}
