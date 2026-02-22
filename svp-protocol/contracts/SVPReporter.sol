// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title SVPReporter
 * @notice Handles financial data submission and validation for assets
 * @dev Integrates with Valuation Engine and Asset Registry
 * @author Hudu Yusuf (Analys)
 */
contract SVPReporter is AccessControl, Pausable {
    // ============= Constants =============
    
    bytes32 public constant REPORTER_ROLE = keccak256("REPORTER_ROLE");
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    // ============= Data Structures =============
    
    /// @notice Financial data submission
    struct DataSubmission {
        uint256 id;                    // Submission ID
        address asset;                 // Asset being reported on
        address reporter;              // Who submitted the data
        uint256 revenue;               // Annual revenue
        uint256 growthRate;            // Growth rate
        uint256 assetValue;            // Total assets
        uint256 liabilities;           // Total liabilities
        uint256 riskFactor;            // Risk factor
        uint256 submissionTimestamp;   // When submitted
        uint8 status;                  // 0=Pending, 1=Approved, 2=Rejected
        string dataHash;               // IPFS hash of full data
        string supportingDocuments;    // Link to supporting docs
        uint256 validationTimestamp;   // When validated
        address validator;             // Who validated
    }
    
    /// @notice Reporter profile
    struct Reporter {
        address reporterAddress;       // Reporter wallet
        string name;                   // Reporter organization name
        string jurisdiction;           // Jurisdiction
        bool verified;                 // Is reporter verified
        uint256 registrationTimestamp; // When registered
        uint256 totalSubmissions;      // Total submissions made
        uint256 approvalRate;          // % of submissions approved
    }
    
    /// @notice Data validation rules
    struct ValidationRules {
        uint256 minRevenue;            // Minimum revenue required
        uint256 maxLiabilities;        // Maximum liabilities allowed
        uint256 maxRiskFactor;         // Maximum risk factor
        bool requireSupportingDocs;    // Must have supporting docs
    }
    
    // ============= State Variables =============
    
    /// @notice Reference to valuation engine
    address public valuationEngine;
    
    /// @notice Reference to asset registry
    address public assetRegistry;
    
    /// @notice Data submissions
    DataSubmission[] public submissions;
    
    /// @notice Reporter profiles
    mapping(address => Reporter) public reporters;
    
    /// @notice Registered reporters
    address[] public registeredReporters;
    
    /// @notice Asset to latest submission mapping
    mapping(address => uint256) public latestSubmissionForAsset;
    
    /// @notice Validation rules
    ValidationRules public validationRules;
    
    /// @notice Submission count per reporter
    mapping(address => uint256[]) public reporterSubmissions;
    
    /// @notice Auto-approval threshold (approval rate % required)
    uint256 public autoApprovalThreshold = 9000; // 90%
    
    /// @notice Allow auto-approval flag
    bool public autoApprovalEnabled = false;
    
    // ============= Events =============
    
    /// @notice Emitted when data is submitted
    event DataSubmitted(
        uint256 indexed submissionId,
        address indexed asset,
        address indexed reporter,
        uint256 revenue,
        uint256 timestamp
    );
    
    /// @notice Emitted when data is validated/approved
    event DataApproved(
        uint256 indexed submissionId,
        address indexed asset,
        address indexed validator,
        uint256 timestamp
    );
    
    /// @notice Emitted when data is rejected
    event DataRejected(
        uint256 indexed submissionId,
        address indexed asset,
        address indexed validator,
        string reason,
        uint256 timestamp
    );
    
    /// @notice Emitted when reporter is registered
    event ReporterRegistered(
        address indexed reporter,
        string name,
        string jurisdiction,
        uint256 timestamp
    );
    
    /// @notice Emitted when reporter is verified
    event ReporterVerified(
        address indexed reporter,
        address indexed admin,
        uint256 timestamp
    );
    
    /// @notice Emitted when validation rules are updated
    event ValidationRulesUpdated(
        uint256 minRevenue,
        uint256 maxLiabilities,
        uint256 maxRiskFactor,
        bool requireDocs,
        address indexed admin,
        uint256 timestamp
    );
    
    // ============= Constructor =============
    
    /**
     * @notice Initialize reporter contract
     * @param valuationEngine_ Address of valuation engine
     * @param assetRegistry_ Address of asset registry
     */
    constructor(address valuationEngine_, address assetRegistry_) {
        require(valuationEngine_ != address(0), "SVPReporter: Invalid valuation engine");
        require(assetRegistry_ != address(0), "SVPReporter: Invalid asset registry");
        
        valuationEngine = valuationEngine_;
        assetRegistry = assetRegistry_;
        
        // Set default validation rules
        validationRules = ValidationRules({
            minRevenue: 1e6,             // $1 minimum
            maxLiabilities: 1e30,        // Very high limit
            maxRiskFactor: 5e18,         // 5x risk
            requireSupportingDocs: true
        });
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(VALIDATOR_ROLE, msg.sender);
        _grantRole(REPORTER_ROLE, msg.sender);
    }
    
    // ============= Reporter Management =============
    
    /**
     * @notice Register as a reporter
     * @param name Organization name
     * @param jurisdiction Jurisdiction
     */
    function registerAsReporter(string calldata name, string calldata jurisdiction)
        external
        whenNotPaused
    {
        require(bytes(name).length > 0, "SVPReporter: Name required");
        require(bytes(jurisdiction).length > 0, "SVPReporter: Jurisdiction required");
        require(reporters[msg.sender].reporterAddress == address(0), "SVPReporter: Already registered");
        
        reporters[msg.sender] = Reporter({
            reporterAddress: msg.sender,
            name: name,
            jurisdiction: jurisdiction,
            verified: false,
            registrationTimestamp: block.timestamp,
            totalSubmissions: 0,
            approvalRate: 0
        });
        
        registeredReporters.push(msg.sender);
        
        emit ReporterRegistered(msg.sender, name, jurisdiction, block.timestamp);
    }
    
    /**
     * @notice Verify reporter (admin only)
     * @param reporter Reporter address to verify
     */
    function verifyReporter(address reporter)
        external
        onlyRole(ADMIN_ROLE)
        whenNotPaused
    {
        require(reporters[reporter].reporterAddress != address(0), "SVPReporter: Reporter not registered");
        require(!reporters[reporter].verified, "SVPReporter: Reporter already verified");
        
        reporters[reporter].verified = true;
        
        _grantRole(REPORTER_ROLE, reporter);
        
        emit ReporterVerified(reporter, msg.sender, block.timestamp);
    }
    
    /**
     * @notice Get reporter details
     * @param reporter Reporter address
     * @return Reporter data
     */
    function getReporter(address reporter)
        external
        view
        returns (Reporter memory)
    {
        return reporters[reporter];
    }
    
    /**
     * @notice Get all registered reporters
     * @return Array of reporter addresses
     */
    function getAllReporters() external view returns (address[] memory) {
        return registeredReporters;
    }
    
    // ============= Data Submission =============
    
    /**
     * @notice Submit financial data for an asset
     * @param asset Asset address
     * @param revenue Annual revenue
     * @param growthRate Growth rate (1e18 = 100%)
     * @param assetValue Total assets
     * @param liabilities Total liabilities
     * @param riskFactor Risk factor (1e18 = neutral)
     * @param dataHash IPFS hash of full data
     * @param supportingDocuments Link to supporting docs
     */
    function submitData(
        address asset,
        uint256 revenue,
        uint256 growthRate,
        uint256 assetValue,
        uint256 liabilities,
        uint256 riskFactor,
        string calldata dataHash,
        string calldata supportingDocuments
    )
        external
        onlyRole(REPORTER_ROLE)
        whenNotPaused
        returns (uint256)
    {
        require(asset != address(0), "SVPReporter: Invalid asset");
        require(bytes(dataHash).length > 0, "SVPReporter: Data hash required");
        
        // Validate data
        _validateData(revenue, assetValue, liabilities, riskFactor, supportingDocuments);
        
        // Create submission
        uint256 submissionId = submissions.length;
        
        DataSubmission storage submission = submissions.push();
        submission.id = submissionId;
        submission.asset = asset;
        submission.reporter = msg.sender;
        submission.revenue = revenue;
        submission.growthRate = growthRate;
        submission.assetValue = assetValue;
        submission.liabilities = liabilities;
        submission.riskFactor = riskFactor;
        submission.submissionTimestamp = block.timestamp;
        submission.status = 0;  // Pending
        submission.dataHash = dataHash;
        submission.supportingDocuments = supportingDocuments;
        
        // Track submission
        latestSubmissionForAsset[asset] = submissionId;
        reporterSubmissions[msg.sender].push(submissionId);
        
        Reporter storage reporter = reporters[msg.sender];
        reporter.totalSubmissions++;
        
        emit DataSubmitted(submissionId, asset, msg.sender, revenue, block.timestamp);
        
        // Check for auto-approval
        if (autoApprovalEnabled && reporter.approvalRate >= autoApprovalThreshold) {
            _approveSubmission(submissionId);
        }
        
        return submissionId;
    }
    
    /**
     * @notice Validate financial data against rules
     * @param revenue Asset revenue
     * @param assetValue Asset value
     * @param liabilities Liabilities
     * @param riskFactor Risk factor
     * @param supportingDocuments Supporting docs link
     */
    function _validateData(
        uint256 revenue,
        uint256 assetValue,
        uint256 liabilities,
        uint256 riskFactor,
        string calldata supportingDocuments
    )
        internal
        view
    {
        require(revenue >= validationRules.minRevenue, "SVPReporter: Revenue too low");
        require(liabilities <= validationRules.maxLiabilities, "SVPReporter: Liabilities too high");
        require(riskFactor <= validationRules.maxRiskFactor, "SVPReporter: Risk factor too high");
        require(assetValue > 0, "SVPReporter: Asset value must be positive");
        require(liabilities < assetValue, "SVPReporter: Liabilities exceed assets");
        
        if (validationRules.requireSupportingDocs) {
            require(bytes(supportingDocuments).length > 0, "SVPReporter: Supporting docs required");
        }
    }
    
    // ============= Submission Validation =============
    
    /**
     * @notice Approve a submission (validator only)
     * @param submissionId Submission ID to approve
     */
    function approveSubmission(uint256 submissionId)
        external
        onlyRole(VALIDATOR_ROLE)
        whenNotPaused
    {
        _approveSubmission(submissionId);
    }
    
    /**
     * @notice Internal approve submission
     * @param submissionId Submission ID
     */
    function _approveSubmission(uint256 submissionId) internal {
        require(submissionId < submissions.length, "SVPReporter: Invalid submission ID");
        
        DataSubmission storage submission = submissions[submissionId];
        require(submission.status == 0, "SVPReporter: Submission already processed");
        
        submission.status = 1;  // Approved
        submission.validationTimestamp = block.timestamp;
        submission.validator = msg.sender;
        
        // Update reporter approval rate
        Reporter storage reporter = reporters[submission.reporter];
        uint256 approvalCount = 0;
        uint256 totalCount = reporter.totalSubmissions;
        
        for (uint256 i = 0; i < reporterSubmissions[submission.reporter].length; i++) {
            if (submissions[reporterSubmissions[submission.reporter][i]].status == 1) {
                approvalCount++;
            }
        }
        
        reporter.approvalRate = (approvalCount * 10000) / totalCount;
        
        // Call valuation engine to update
        _callValuationEngineUpdate(submission);
        
        emit DataApproved(submissionId, submission.asset, msg.sender, block.timestamp);
    }
    
    /**
     * @notice Reject a submission (validator only)
     * @param submissionId Submission ID to reject
     * @param reason Rejection reason
     */
    function rejectSubmission(uint256 submissionId, string calldata reason)
        external
        onlyRole(VALIDATOR_ROLE)
        whenNotPaused
    {
        require(submissionId < submissions.length, "SVPReporter: Invalid submission ID");
        require(bytes(reason).length > 0, "SVPReporter: Reason required");
        
        DataSubmission storage submission = submissions[submissionId];
        require(submission.status == 0, "SVPReporter: Submission already processed");
        
        submission.status = 2;  // Rejected
        submission.validationTimestamp = block.timestamp;
        submission.validator = msg.sender;
        
        emit DataRejected(submissionId, submission.asset, msg.sender, reason, block.timestamp);
    }
    
    /**
     * @notice Call valuation engine to update values
     * @param submission Data submission
     */
    function _callValuationEngineUpdate(DataSubmission storage submission) internal {
        // In production, would call valuation engine's updateFinancialData
        // This is a placeholder for interface integration
    }
    
    // ============= View Functions =============
    
    /**
     * @notice Get submission details
     * @param submissionId Submission ID
     * @return Submission data
     */
    function getSubmission(uint256 submissionId)
        external
        view
        returns (DataSubmission memory)
    {
        require(submissionId < submissions.length, "SVPReporter: Invalid submission ID");
        return submissions[submissionId];
    }
    
    /**
     * @notice Get submission count
     * @return Total submissions
     */
    function getSubmissionCount() external view returns (uint256) {
        return submissions.length;
    }
    
    /**
     * @notice Get reporter's submissions
     * @param reporter Reporter address
     * @return Array of submission IDs
     */
    function getReporterSubmissions(address reporter)
        external
        view
        returns (uint256[] memory)
    {
        return reporterSubmissions[reporter];
    }
    
    /**
     * @notice Get latest submission for asset
     * @param asset Asset address
     * @return Submission ID
     */
    function getLatestSubmissionForAsset(address asset)
        external
        view
        returns (uint256)
    {
        return latestSubmissionForAsset[asset];
    }
    
    // ============= Admin Functions =============
    
    /**
     * @notice Update validation rules
     * @param minRevenue Minimum revenue
     * @param maxLiabilities Maximum liabilities
     * @param maxRiskFactor Maximum risk factor
     * @param requireDocs Require supporting documents
     */
    function setValidationRules(
        uint256 minRevenue,
        uint256 maxLiabilities,
        uint256 maxRiskFactor,
        bool requireDocs
    )
        external
        onlyRole(ADMIN_ROLE)
    {
        validationRules = ValidationRules({
            minRevenue: minRevenue,
            maxLiabilities: maxLiabilities,
            maxRiskFactor: maxRiskFactor,
            requireSupportingDocs: requireDocs
        });
        
        emit ValidationRulesUpdated(
            minRevenue,
            maxLiabilities,
            maxRiskFactor,
            requireDocs,
            msg.sender,
            block.timestamp
        );
    }
    
    /**
     * @notice Set auto-approval settings
     * @param enabled Enable auto-approval
     * @param threshold Approval rate threshold
     */
    function setAutoApproval(bool enabled, uint256 threshold)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(threshold <= 10000, "SVPReporter: Invalid threshold");
        autoApprovalEnabled = enabled;
        autoApprovalThreshold = threshold;
    }
    
    /**
     * @notice Pause all operations
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpause all operations
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}
