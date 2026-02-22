/**
 * SVP Protocol - Unit Tests Template
 * 
 * Test Suite Structure:
 * - Access Control Tests
 * - Valuation Engine Tests
 * - Asset Registry Tests
 * - Token Tests
 * - Governance Tests
 * - Vault Tests
 * - Dividend Distributor Tests
 * - Reporter Tests
 * - Factory Tests
 */

import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, Signer } from "ethers";

describe("SVP Protocol", function () {
  let owner: Signer;
  let admin: Signer;
  let reporter: Signer;
  let user1: Signer;
  let user2: Signer;

  let accessControl: Contract;
  let valuationEngine: Contract;
  let assetRegistry: Contract;
  let token: Contract;
  let governance: Contract;
  let vault: Contract;
  let dividendDistributor: Contract;
  let reporter_contract: Contract;
  let factory: Contract;

  before(async function () {
    // Get signers
    [owner, admin, reporter, user1, user2] = await ethers.getSigners();

    // Deploy AccessControl
    const ACFactory = await ethers.getContractFactory("SVPAccessControl");
    accessControl = await ACFactory.deploy();
    await accessControl.waitForDeployment();
  });

  describe("SVPAccessControl", function () {
    it("Should deploy correctly", async function () {
      const address = await accessControl.getAddress();
      expect(address).to.not.equal(ethers.ZeroAddress);
    });

    it("Should have correct roles defined", async function () {
      const DEFAULT_ADMIN_ROLE = await accessControl.DEFAULT_ADMIN_ROLE();
      const REPORTER_ROLE = await accessControl.REPORTER_ROLE();
      expect(DEFAULT_ADMIN_ROLE).to.not.equal(REPORTER_ROLE);
    });

    it("Should grant roles correctly", async function () {
      const REPORTER_ROLE = await accessControl.REPORTER_ROLE();
      const reporterAddress = await reporter.getAddress();
      
      const tx = await accessControl.grantRole(REPORTER_ROLE, reporterAddress);
      await tx.wait();
      
      const hasRole = await accessControl.hasRole(REPORTER_ROLE, reporterAddress);
      expect(hasRole).to.be.true;
    });

    it("Should batch grant roles", async function () {
      const REPORTER_ROLE = await accessControl.REPORTER_ROLE();
      const user1Address = await user1.getAddress();
      const user2Address = await user2.getAddress();
      
      const tx = await accessControl.grantRolesBatch(
        REPORTER_ROLE,
        [user1Address, user2Address]
      );
      await tx.wait();
      
      const hasRole1 = await accessControl.hasRole(REPORTER_ROLE, user1Address);
      const hasRole2 = await accessControl.hasRole(REPORTER_ROLE, user2Address);
      expect(hasRole1).to.be.true;
      expect(hasRole2).to.be.true;
    });

    it("Should revoke roles correctly", async function () {
      const REPORTER_ROLE = await accessControl.REPORTER_ROLE();
      const reporterAddress = await reporter.getAddress();
      
      const tx = await accessControl.revokeRole(REPORTER_ROLE, reporterAddress);
      await tx.wait();
      
      const hasRole = await accessControl.hasRole(REPORTER_ROLE, reporterAddress);
      expect(hasRole).to.be.false;
    });

    it("Should emit RoleGrantedToAddress event", async function () {
      const REPORTER_ROLE = await accessControl.REPORTER_ROLE();
      const reporterAddress = await reporter.getAddress();
      
      await expect(
        accessControl.grantRole(REPORTER_ROLE, reporterAddress)
      ).to.emit(accessControl, "RoleGrantedToAddress");
    });

    it("Should emit RoleRevokedFromAddress event", async function () {
      const REPORTER_ROLE = await accessControl.REPORTER_ROLE();
      const reporterAddress = await reporter.getAddress();
      
      // First grant
      await accessControl.grantRole(REPORTER_ROLE, reporterAddress);
      
      // Then revoke
      await expect(
        accessControl.revokeRole(REPORTER_ROLE, reporterAddress)
      ).to.emit(accessControl, "RoleRevokedFromAddress");
    });

    it("Should not allow non-admin to grant roles", async function () {
      const REPORTER_ROLE = await accessControl.REPORTER_ROLE();
      const userAddress = await user1.getAddress();
      const reporterAddress = await reporter.getAddress();
      
      await expect(
        accessControl.connect(user1).grantRole(REPORTER_ROLE, reporterAddress)
      ).to.be.revertedWithCustomError(accessControl, "AccessControlUnauthorizedAccount");
    });
  });

  describe("SVPValuationEngine", function () {
    before(async function () {
      const VEFactory = await ethers.getContractFactory("SVPValuationEngine");
      const acAddress = await accessControl.getAddress();
      
      // Deploy with proxy
      const ve = await ethers.getContractFactory("SVPValuationEngine");
      const proxy = await ethers.upgrades.deployProxy(
        ve,
        [acAddress],
        { kind: "uups" }
      );
      valuationEngine = await proxy.waitForDeployment().then(() => proxy);
    });

    it("Should deploy correctly", async function () {
      const address = await valuationEngine.getAddress();
      expect(address).to.not.equal(ethers.ZeroAddress);
    });

    it("Should submit financial data", async function () {
      const assetId = 1;
      const reporterAddress = await reporter.getAddress();
      
      // Grant reporter role first
      const REPORTER_ROLE = await accessControl.REPORTER_ROLE();
      await accessControl.grantRole(REPORTER_ROLE, reporterAddress);
      
      const tx = await valuationEngine.connect(reporter).submitFinancialData(
        assetId,
        ethers.parseEther("100"),    // revenue
        ethers.parseUnits("0.1", 18), // growthRate
        ethers.parseEther("500"),    // assetValue
        ethers.parseEther("100"),    // liabilities
        ethers.parseUnits("1.2", 18) // riskFactor
      );
      
      await expect(tx).to.emit(valuationEngine, "FinancialDataSubmitted");
    });

    it("Should calculate intrinsic value", async function () {
      const assetId = 1;
      
      const value = await valuationEngine.getIntrinsicValue(assetId);
      expect(value).to.be.gt(0);
    });

    it("Should have rate limiting", async function () {
      const assetId = 2;
      const reporterAddress = await reporter.getAddress();
      
      // First submission
      await valuationEngine.connect(reporter).submitFinancialData(
        assetId,
        ethers.parseEther("100"),
        ethers.parseUnits("0.1", 18),
        ethers.parseEther("500"),
        ethers.parseEther("100"),
        ethers.parseUnits("1.2", 18)
      );
      
      // Second submission should fail (rate limited)
      await expect(
        valuationEngine.connect(reporter).submitFinancialData(
          assetId,
          ethers.parseEther("100"),
          ethers.parseUnits("0.1", 18),
          ethers.parseEther("500"),
          ethers.parseEther("100"),
          ethers.parseUnits("1.2", 18)
        )
      ).to.be.revertedWithCustomError(valuationEngine, "RateLimitExceeded");
    });

    it("Should emit IntrinsicValueCalculated event", async function () {
      const assetId = 3;
      
      await valuationEngine.connect(reporter).submitFinancialData(
        assetId,
        ethers.parseEther("100"),
        ethers.parseUnits("0.1", 18),
        ethers.parseEther("500"),
        ethers.parseEther("100"),
        ethers.parseUnits("1.2", 18)
      );
      
      // Calculate should emit event
      const tx = await valuationEngine.calculateIntrinsicValue(assetId);
      await expect(tx).to.emit(valuationEngine, "IntrinsicValueCalculated");
    });
  });

  describe("SVPAssetRegistry", function () {
    before(async function () {
      const ARFactory = await ethers.getContractFactory("SVPAssetRegistry");
      const acAddress = await accessControl.getAddress();
      assetRegistry = await ARFactory.deploy(acAddress);
      await assetRegistry.waitForDeployment();
    });

    it("Should register asset", async function () {
      const ownerAddress = await owner.getAddress();
      
      const tx = await assetRegistry.registerAsset(
        ownerAddress,
        "Test Asset",
        "ipfs://metadata",
        "Technology",
        "US"
      );
      
      await expect(tx).to.emit(assetRegistry, "AssetRegistered");
    });

    it("Should retrieve asset info", async function () {
      const asset = await assetRegistry.getAsset(0);
      expect(asset.name).to.equal("Test Asset");
    });

    it("Should approve asset", async function () {
      const ADMIN_ROLE = await accessControl.DEFAULT_ADMIN_ROLE();
      const adminAddress = await admin.getAddress();
      
      await accessControl.grantRole(ADMIN_ROLE, adminAddress);
      
      const tx = await assetRegistry.connect(admin).approveAsset(0);
      await expect(tx).to.emit(assetRegistry, "AssetApproved");
    });

    it("Should deactivate asset", async function () {
      const adminAddress = await admin.getAddress();
      
      const tx = await assetRegistry.connect(admin).deactivateAsset(0);
      await expect(tx).to.emit(assetRegistry, "AssetStatusChanged");
    });

    it("Should set asset class", async function () {
      const ADMIN_ROLE = await accessControl.DEFAULT_ADMIN_ROLE();
      const adminAddress = await admin.getAddress();
      
      const tx = await assetRegistry.connect(admin).setAssetClass(
        0,
        0,           // tier
        false,       // restrictedTransfer
        ethers.parseEther("1000") // minInvestment
      );
      
      await expect(tx).to.emit(assetRegistry, "AssetClassSet");
    });
  });

  describe("SVPToken", function () {
    before(async function () {
      const TFactory = await ethers.getContractFactory("SVPToken");
      const acAddress = await accessControl.getAddress();
      
      token = await TFactory.deploy(
        acAddress,
        "SVP Token",
        "SVP",
        ethers.parseEther("1000000")
      );
      await token.waitForDeployment();
    });

    it("Should have correct name and symbol", async function () {
      const name = await token.name();
      const symbol = await token.symbol();
      expect(name).to.equal("SVP Token");
      expect(symbol).to.equal("SVP");
    });

    it("Should mint tokens", async function () {
      const MINTER_ROLE = await accessControl.MINTER_ROLE();
      const ownerAddress = await owner.getAddress();
      
      await accessControl.grantRole(MINTER_ROLE, ownerAddress);
      
      const tx = await token.mint(ownerAddress, ethers.parseEther("100"));
      await tx.wait();
      
      const balance = await token.balanceOf(ownerAddress);
      expect(balance).to.equal(ethers.parseEther("100"));
    });

    it("Should transfer tokens", async function () {
      const ownerAddress = await owner.getAddress();
      const user1Address = await user1.getAddress();
      
      const tx = await token.connect(owner).transfer(
        user1Address,
        ethers.parseEther("50")
      );
      
      await tx.wait();
      
      const balance = await token.balanceOf(user1Address);
      expect(balance).to.equal(ethers.parseEther("50"));
    });

    it("Should burn tokens", async function () {
      const ownerAddress = await owner.getAddress();
      const balanceBefore = await token.balanceOf(ownerAddress);
      
      const tx = await token.burn(ethers.parseEther("25"));
      await tx.wait();
      
      const balanceAfter = await token.balanceOf(ownerAddress);
      expect(balanceAfter).to.equal(balanceBefore - ethers.parseEther("25"));
    });

    it("Should freeze account", async function () {
      const user1Address = await user1.getAddress();
      const COMPLIANCE_ROLE = await accessControl.COMPLIANCE_ROLE();
      const ownerAddress = await owner.getAddress();
      
      await accessControl.grantRole(COMPLIANCE_ROLE, ownerAddress);
      
      const tx = await token.connect(owner).freezeAccount(user1Address);
      await expect(tx).to.emit(token, "AccountFrozen");
    });

    it("Should prevent transfer from frozen account", async function () {
      const user1Address = await user1.getAddress();
      const user2Address = await user2.getAddress();
      
      await expect(
        token.connect(user1).transfer(user2Address, ethers.parseEther("10"))
      ).to.be.revertedWithCustomError(token, "AccountFrozen");
    });

    it("Should create snapshot", async function () {
      const tx = await token.snapshot();
      await expect(tx).to.emit(token, "SnapshotCreated");
    });

    it("Should add to whitelist", async function () {
      const COMPLIANCE_ROLE = await accessControl.COMPLIANCE_ROLE();
      const ownerAddress = await owner.getAddress();
      const user2Address = await user2.getAddress();
      
      const tx = await token.connect(owner).addToWhitelist(
        user2Address,
        1,                          // tier
        ethers.parseEther("10000")  // maxHolding
      );
      
      await expect(tx).to.emit(token, "AddressWhitelisted");
    });
  });

  describe("SVPGovernance", function () {
    before(async function () {
      const GFactory = await ethers.getContractFactory("SVPGovernance");
      const acAddress = await accessControl.getAddress();
      const veAddress = await valuationEngine.getAddress();
      
      governance = await GFactory.deploy(acAddress, veAddress);
      await governance.waitForDeployment();
    });

    it("Should have correct governance parameters", async function () {
      const params = await governance.getGovernanceParams();
      expect(params.votingDelay).to.equal(1);
      expect(params.votingPeriod).to.equal(50400);
    });

    it("Should calculate voting power", async function () {
      const ownerAddress = await owner.getAddress();
      const votingPower = await governance.getVotingPower(ownerAddress);
      expect(votingPower).to.be.gte(0);
    });

    it("Should create proposal", async function () {
      const ownerAddress = await owner.getAddress();
      
      const tx = await governance.createProposal(
        ownerAddress,
        "Test Proposal",
        "Test Description"
      );
      
      await expect(tx).to.emit(governance, "ProposalCreated");
    });

    it("Should cast vote", async function () {
      const ownerAddress = await owner.getAddress();
      
      // Create proposal first
      await governance.createProposal(
        ownerAddress,
        "Vote Test Proposal",
        "Test Description"
      );
      
      const proposalId = 1;
      const tx = await governance.castVote(proposalId, 1); // 1 = For
      
      await expect(tx).to.emit(governance, "VoteCast");
    });
  });

  describe("SVPSPVVault", function () {
    before(async function () {
      const VFactory = await ethers.getContractFactory("SVPSPVVault");
      const acAddress = await accessControl.getAddress();
      
      vault = await VFactory.deploy(
        acAddress,
        ethers.ZeroAddress, // underlying
        "SVP Vault",
        "svpVault"
      );
      await vault.waitForDeployment();
    });

    it("Should have correct name and symbol", async function () {
      const name = await vault.name();
      const symbol = await vault.symbol();
      expect(name).to.equal("SVP Vault");
      expect(symbol).to.equal("svpVault");
    });

    it("Should calculate NAV", async function () {
      const nav = await vault.calculateNAV();
      expect(nav).to.be.gte(0);
    });
  });

  describe("SVPDividendDistributor", function () {
    before(async function () {
      const DFactory = await ethers.getContractFactory("SVPDividendDistributor");
      const acAddress = await accessControl.getAddress();
      
      dividendDistributor = await DFactory.deploy(acAddress);
      await dividendDistributor.waitForDeployment();
    });

    it("Should deposit dividends", async function () {
      const tx = await dividendDistributor.depositDividends(
        ethers.parseEther("100"),
        ethers.ZeroAddress,  // rewardToken
        "Test Dividend"
      );
      
      await expect(tx).to.emit(dividendDistributor, "DividendDeposited");
    });

    it("Should track distributions", async function () {
      const distributions = await dividendDistributor.getDistributionCount();
      expect(distributions).to.be.gt(0);
    });
  });

  describe("SVPReporter", function () {
    before(async function () {
      const RFactory = await ethers.getContractFactory("SVPReporter");
      const acAddress = await accessControl.getAddress();
      const veAddress = await valuationEngine.getAddress();
      
      reporter_contract = await RFactory.deploy(acAddress, veAddress);
      await reporter_contract.waitForDeployment();
    });

    it("Should register reporter", async function () {
      const reporterAddress = await reporter.getAddress();
      
      const tx = await reporter_contract.connect(reporter).registerAsReporter(
        "Test Reporter",
        "US"
      );
      
      await expect(tx).to.emit(reporter_contract, "ReporterRegistered");
    });

    it("Should verify reporter", async function () {
      const reporterAddress = await reporter.getAddress();
      const ADMIN_ROLE = await accessControl.DEFAULT_ADMIN_ROLE();
      const adminAddress = await admin.getAddress();
      
      await accessControl.grantRole(ADMIN_ROLE, adminAddress);
      
      const tx = await reporter_contract.connect(admin).verifyReporter(reporterAddress);
      await expect(tx).to.emit(reporter_contract, "ReporterVerified");
    });
  });

  describe("SVPFactory", function () {
    before(async function () {
      const FFactory = await ethers.getContractFactory("SVPFactory");
      const acAddress = await accessControl.getAddress();
      
      factory = await FFactory.deploy(acAddress);
      await factory.waitForDeployment();
    });

    it("Should deploy instance", async function () {
      const tAddress = await token.getAddress();
      const gAddress = await governance.getAddress();
      const vAddress = await vault.getAddress();
      
      const tx = await factory.deployInstance(
        tAddress,
        gAddress,
        vAddress,
        ethers.ZeroAddress,
        "Test Instance"
      );
      
      await expect(tx).to.emit(factory, "SVPInstanceDeployed");
    });

    it("Should track deployments", async function () {
      const deploymentCount = await factory.deploymentCount();
      expect(deploymentCount).to.be.gt(0);
    });
  });

  describe("Integration Tests", function () {
    it("Should complete full workflow", async function () {
      // This is a placeholder for a complete end-to-end test
      // combining multiple contracts in realistic scenarios
      
      // 1. Register asset
      // 2. Submit financial data
      // 3. Create token instance
      // 4. Mint and distribute tokens
      // 5. Create proposal
      // 6. Vote on proposal
      // 7. Execute proposal
      // 8. Distribute dividends
      
      expect(true).to.be.true;
    });
  });
});
