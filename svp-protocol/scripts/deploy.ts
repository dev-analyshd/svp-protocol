/**
 * SVP Protocol Deployment Script
 * 
 * Deploys all core protocol contracts with proper initialization
 * Usage: npx hardhat run scripts/deploy.ts --network <network>
 * 
 * Deployment Order:
 * 1. SVPAccessControl (RBAC foundation)
 * 2. SVPValuationEngine (Core valuation logic)
 * 3. SVPAssetRegistry (Asset registration)
 * 4. SVPToken (Security token template)
 * 5. SVPGovernance (Voting system template)
 * 6. SVPSPVVault (Vault template)
 * 7. SVPDividendDistributor (Distribution system)
 * 8. SVPReporter (Data validation)
 * 9. SVPFactory (Instance factory)
 */

import { ethers, upgrades } from "hardhat";
import * as fs from "fs";
import * as path from "path";

// Deployment configuration
const CONFIG = {
  network: process.env.HARDHAT_NETWORK || "hardhat",
  adminAddress: process.env.ADMIN_ADDRESS || "", // Will use deployer if empty
  reporterAddresses: (process.env.REPORTER_ADDRESSES || "").split(",").filter(Boolean),
  initialAsset: process.env.INITIAL_ASSET || "Test Asset",
  pauseOnDeploy: false, // For safety during testing
};

// Contract addresses registry
interface DeploymentRecord {
  timestamp: string;
  network: string;
  deployer: string;
  contracts: {
    [key: string]: string;
  };
}

const deploymentRecord: DeploymentRecord = {
  timestamp: new Date().toISOString(),
  network: CONFIG.network,
  deployer: "",
  contracts: {},
};

/**
 * Main deployment function
 */
async function main() {
  console.log("🚀 Starting SVP Protocol Deployment");
  console.log("==================================\n");

  // Get deployer account
  const [deployer] = await ethers.getSigners();
  deploymentRecord.deployer = deployer.address;
  const adminAddress = CONFIG.adminAddress || deployer.address;

  console.log(`📋 Deployment Configuration:`);
  console.log(`   Network: ${CONFIG.network}`);
  console.log(`   Deployer: ${deployer.address}`);
  console.log(`   Admin: ${adminAddress}`);
  console.log(`   Reporters: ${CONFIG.reporterAddresses.length || "none"}`);
  console.log("");

  // Check balance
  const balance = await deployer.getBalance();
  console.log(`💰 Deployer Balance: ${ethers.utils.formatEther(balance)} ETH\n`);

  if (balance.toString() === "0") {
    console.error("❌ ERROR: Deployer account has no balance!");
    process.exit(1);
  }

  try {
    // Phase 1: Deploy Access Control (foundational)
    console.log("📦 Phase 1: Deploying RBAC Foundation");
    console.log("-----------------------------------");
    const accessControl = await deployAccessControl();
    console.log("");

    // Phase 2: Deploy Valuation Engine (core logic)
    console.log("📦 Phase 2: Deploying Valuation Engine");
    console.log("-------------------------------------");
    const valuationEngine = await deployValuationEngine(accessControl.address);
    console.log("");

    // Phase 3: Deploy Asset Registry
    console.log("📦 Phase 3: Deploying Asset Registry");
    console.log("----------------------------------");
    const assetRegistry = await deployAssetRegistry(accessControl.address);
    console.log("");

    // Phase 4: Deploy Token
    console.log("📦 Phase 4: Deploying SVP Token");
    console.log("------------------------------");
    const token = await deployToken(accessControl.address);
    console.log("");

    // Phase 5: Deploy Governance
    console.log("📦 Phase 5: Deploying Governance");
    console.log("-------------------------------");
    const governance = await deployGovernance(accessControl.address, valuationEngine.address);
    console.log("");

    // Phase 6: Deploy SPV Vault
    console.log("📦 Phase 6: Deploying SPV Vault");
    console.log("------------------------------");
    const vault = await deploySPVVault(accessControl.address);
    console.log("");

    // Phase 7: Deploy Dividend Distributor
    console.log("📦 Phase 7: Deploying Dividend Distributor");
    console.log("-----------------------------------------");
    const dividends = await deployDividendDistributor(accessControl.address);
    console.log("");

    // Phase 8: Deploy Reporter
    console.log("📦 Phase 8: Deploying Reporter");
    console.log("-----------------------------");
    const reporter = await deployReporter(accessControl.address, valuationEngine.address);
    console.log("");

    // Phase 9: Deploy Factory
    console.log("📦 Phase 9: Deploying Factory");
    console.log("---------------------------");
    const factory = await deployFactory(accessControl.address);
    console.log("");

    // Post-deployment setup
    console.log("⚙️  Running Post-Deployment Setup");
    console.log("-------------------------------");
    await setupRoles(accessControl.address, adminAddress);
    console.log("");

    // Save deployment record
    const recordPath = path.join(__dirname, `../deployments/${CONFIG.network}-${Date.now()}.json`);
    if (!fs.existsSync(path.dirname(recordPath))) {
      fs.mkdirSync(path.dirname(recordPath), { recursive: true });
    }
    fs.writeFileSync(recordPath, JSON.stringify(deploymentRecord, null, 2));

    // Summary
    console.log("✅ Deployment Complete!");
    console.log("=======================\n");
    console.log("Contract Addresses:");
    console.log(JSON.stringify(deploymentRecord.contracts, null, 2));
    console.log(`\n📁 Deployment record saved to: ${recordPath}`);
    console.log("\n📖 Next Steps:");
    console.log("1. Verify contracts on block explorer");
    console.log("2. Register initial assets");
    console.log("3. Run post-deployment tests");
    console.log("4. Monitor contracts for 24 hours");

  } catch (error) {
    console.error("\n❌ Deployment failed:", error);
    process.exit(1);
  }
}

/**
 * Deploy SVPAccessControl contract
 */
async function deployAccessControl() {
  console.log("Deploying SVPAccessControl...");
  const AccessControl = await ethers.getContractFactory("SVPAccessControl");
  const contract = await AccessControl.deploy();
  await contract.waitForDeployment();
  const address = await contract.getAddress();
  deploymentRecord.contracts.SVPAccessControl = address;
  console.log(`✓ SVPAccessControl deployed at: ${address}`);
  return { address };
}

/**
 * Deploy SVPValuationEngine with UUPS proxy
 */
async function deployValuationEngine(accessControlAddress: string) {
  console.log("Deploying SVPValuationEngine (UUPS proxy)...");
  const ValuationEngine = await ethers.getContractFactory("SVPValuationEngine");
  
  // Deploy proxy
  const proxy = await upgrades.deployProxy(
    ValuationEngine,
    [accessControlAddress],
    {
      kind: "uups",
      initializer: "initialize",
    }
  );
  await proxy.waitForDeployment();
  const proxyAddress = await proxy.getAddress();
  deploymentRecord.contracts.SVPValuationEngineProxy = proxyAddress;
  console.log(`✓ SVPValuationEngine deployed at: ${proxyAddress}`);
  
  // Get implementation address
  const implAddress = await upgrades.erc1967.getImplementationAddress(proxyAddress);
  deploymentRecord.contracts.SVPValuationEngineImpl = implAddress;
  console.log(`✓ Implementation at: ${implAddress}`);
  
  return { address: proxyAddress, implementation: implAddress };
}

/**
 * Deploy SVPAssetRegistry contract
 */
async function deployAssetRegistry(accessControlAddress: string) {
  console.log("Deploying SVPAssetRegistry...");
  const AssetRegistry = await ethers.getContractFactory("SVPAssetRegistry");
  const contract = await AssetRegistry.deploy(accessControlAddress);
  await contract.waitForDeployment();
  const address = await contract.getAddress();
  deploymentRecord.contracts.SVPAssetRegistry = address;
  console.log(`✓ SVPAssetRegistry deployed at: ${address}`);
  return { address };
}

/**
 * Deploy SVPToken contract
 */
async function deployToken(accessControlAddress: string) {
  console.log("Deploying SVPToken...");
  const Token = await ethers.getContractFactory("SVPToken");
  const contract = await Token.deploy(
    accessControlAddress,
    "SVP Token",
    "SVP",
    ethers.parseEther("1000000") // 1M token cap
  );
  await contract.waitForDeployment();
  const address = await contract.getAddress();
  deploymentRecord.contracts.SVPToken = address;
  console.log(`✓ SVPToken deployed at: ${address}`);
  return { address };
}

/**
 * Deploy SVPGovernance contract
 */
async function deployGovernance(accessControlAddress: string, valuationEngineAddress: string) {
  console.log("Deploying SVPGovernance...");
  const Governance = await ethers.getContractFactory("SVPGovernance");
  const contract = await Governance.deploy(
    accessControlAddress,
    valuationEngineAddress
  );
  await contract.waitForDeployment();
  const address = await contract.getAddress();
  deploymentRecord.contracts.SVPGovernance = address;
  console.log(`✓ SVPGovernance deployed at: ${address}`);
  return { address };
}

/**
 * Deploy SVPSPVVault contract
 */
async function deploySPVVault(accessControlAddress: string) {
  console.log("Deploying SVPSPVVault...");
  const Vault = await ethers.getContractFactory("SVPSPVVault");
  const contract = await Vault.deploy(
    accessControlAddress,
    ethers.ZeroAddress, // Underlying asset (set to USDC on mainnet)
    "SVP Vault",
    "svpVault"
  );
  await contract.waitForDeployment();
  const address = await contract.getAddress();
  deploymentRecord.contracts.SVPSPVVault = address;
  console.log(`✓ SVPSPVVault deployed at: ${address}`);
  return { address };
}

/**
 * Deploy SVPDividendDistributor contract
 */
async function deployDividendDistributor(accessControlAddress: string) {
  console.log("Deploying SVPDividendDistributor...");
  const Distributor = await ethers.getContractFactory("SVPDividendDistributor");
  const contract = await Distributor.deploy(accessControlAddress);
  await contract.waitForDeployment();
  const address = await contract.getAddress();
  deploymentRecord.contracts.SVPDividendDistributor = address;
  console.log(`✓ SVPDividendDistributor deployed at: ${address}`);
  return { address };
}

/**
 * Deploy SVPReporter contract
 */
async function deployReporter(accessControlAddress: string, valuationEngineAddress: string) {
  console.log("Deploying SVPReporter...");
  const Reporter = await ethers.getContractFactory("SVPReporter");
  const contract = await Reporter.deploy(
    accessControlAddress,
    valuationEngineAddress
  );
  await contract.waitForDeployment();
  const address = await contract.getAddress();
  deploymentRecord.contracts.SVPReporter = address;
  console.log(`✓ SVPReporter deployed at: ${address}`);
  return { address };
}

/**
 * Deploy SVPFactory contract
 */
async function deployFactory(accessControlAddress: string) {
  console.log("Deploying SVPFactory...");
  const Factory = await ethers.getContractFactory("SVPFactory");
  const contract = await Factory.deploy(accessControlAddress);
  await contract.waitForDeployment();
  const address = await contract.getAddress();
  deploymentRecord.contracts.SVPFactory = address;
  console.log(`✓ SVPFactory deployed at: ${address}`);
  return { address };
}

/**
 * Setup roles and permissions
 */
async function setupRoles(accessControlAddress: string, adminAddress: string) {
  console.log("Setting up roles and permissions...");
  
  const ac = await ethers.getContractAt("SVPAccessControl", accessControlAddress);
  const REPORTER_ROLE = await ac.REPORTER_ROLE();
  
  // Grant reporter roles if specified
  for (const reporter of CONFIG.reporterAddresses) {
    try {
      const tx = await ac.grantRole(REPORTER_ROLE, reporter);
      await tx.wait();
      console.log(`✓ Granted REPORTER_ROLE to ${reporter}`);
    } catch (error) {
      console.warn(`⚠️  Failed to grant role to ${reporter}: ${error}`);
    }
  }
  
  console.log("✓ Roles and permissions configured");
}

// Run deployment
main().catch(console.error);
