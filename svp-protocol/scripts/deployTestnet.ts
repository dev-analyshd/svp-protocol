/**
 * SVP Protocol Testnet Deployment Script
 * Deploys all core contracts to Arbitrum Sepolia or Robinhood testnet
 * Usage: npx hardhat run scripts/deployTestnet.ts --network <arbitrumSepolia|robinhoodChain>
 */

import { ethers } from "hardhat";
import * as fs from "fs";

async function main() {
  const [deployer] = await ethers.getSigners();
  const network = hre.network.name;
  
  console.log("\n🚀 SVP Protocol Testnet Deployment");
  console.log("=====================================");
  console.log(`📍 Network: ${network}`);
  console.log(`👤 Deployer: ${deployer.address}`);

  // Check balance
  const balance = await deployer.getBalance();
  console.log(`💰 Balance: ${ethers.utils.formatEther(balance)} ETH\n`);

  if (balance.eq(0)) {
    console.error("❌ Deployer has no balance!");
    process.exit(1);
  }

  const deployments: any = {
    network,
    timestamp: new Date().toISOString(),
    deployer: deployer.address,
    contracts: {}
  };

  try {
    // 1️⃣ Deploy SVPAccessControl
    console.log("1️⃣  Deploying SVPAccessControl...");
    const AccessControl = await ethers.getContractFactory("SVPAccessControl");
    const accessControl = await AccessControl.deploy();
    await accessControl.deployed();
    deployments.contracts.SVPAccessControl = {
      address: accessControl.address,
      tx: accessControl.deployTransaction?.hash
    };
    console.log(`   ✅ SVPAccessControl: ${accessControl.address}`);

    // 2️⃣ Deploy SVPValuationEngine
    console.log("\n2️⃣  Deploying SVPValuationEngine...");
    const ValuationEngine = await ethers.getContractFactory("SVPValuationEngine");
    const valuationEngine = await ValuationEngine.deploy();
    await valuationEngine.deployed();
    deployments.contracts.SVPValuationEngine = {
      address: valuationEngine.address,
      tx: valuationEngine.deployTransaction?.hash
    };
    console.log(`   ✅ SVPValuationEngine: ${valuationEngine.address}`);

    // 3️⃣ Deploy SVPAssetRegistry
    console.log("\n3️⃣  Deploying SVPAssetRegistry...");
    const AssetRegistry = await ethers.getContractFactory("SVPAssetRegistry");
    const assetRegistry = await AssetRegistry.deploy();
    await assetRegistry.deployed();
    deployments.contracts.SVPAssetRegistry = {
      address: assetRegistry.address,
      tx: assetRegistry.deployTransaction?.hash
    };
    console.log(`   ✅ SVPAssetRegistry: ${assetRegistry.address}`);

    // 4️⃣ Deploy SVPToken
    console.log("\n4️⃣  Deploying SVPToken...");
    const Token = await ethers.getContractFactory("SVPToken");
    const token = await Token.deploy(
      "SVP Protocol Token",
      "SVP",
      assetRegistry.address,
      "ipfs://QmSVPProtocol",
      ethers.utils.parseEther("1000000")
    );
    await token.deployed();
    deployments.contracts.SVPToken = {
      address: token.address,
      tx: token.deployTransaction?.hash
    };
    console.log(`   ✅ SVPToken: ${token.address}`);

    // 5️⃣ Deploy SVPToken1400 (alternative token standard)
    console.log("\n5️⃣  Deploying SVPToken1400...");
    const Token1400 = await ethers.getContractFactory("SVPToken1400");
    const token1400 = await Token1400.deploy(
      accessControl.address,
      "SVP 1400 Token",
      "SVP1400",
      ethers.utils.parseEther("1000000")
    );
    await token1400.deployed();
    deployments.contracts.SVPToken1400 = {
      address: token1400.address,
      tx: token1400.deployTransaction?.hash
    };
    console.log(`   ✅ SVPToken1400: ${token1400.address}`);

    // 6️⃣ Deploy SVPGovernanceEnhanced
    console.log("\n6️⃣  Deploying SVPGovernanceEnhanced...");
    const Governance = await ethers.getContractFactory("SVPGovernanceEnhanced");
    const governance = await Governance.deploy(
      token.address,
      valuationEngine.address,
      assetRegistry.address,
      token1400.address
    );
    await governance.deployed();
    deployments.contracts.SVPGovernanceEnhanced = {
      address: governance.address,
      tx: governance.deployTransaction?.hash
    };
    console.log(`   ✅ SVPGovernanceEnhanced: ${governance.address}`);

    // 7️⃣ Deploy SVPDividendDistributor
    console.log("\n7️⃣  Deploying SVPDividendDistributor...");
    const DividendDistributor = await ethers.getContractFactory("SVPDividendDistributor");
    const dividendDistributor = await DividendDistributor.deploy(token.address, token.address);
    await dividendDistributor.deployed();
    deployments.contracts.SVPDividendDistributor = {
      address: dividendDistributor.address,
      tx: dividendDistributor.deployTransaction?.hash
    };
    console.log(`   ✅ SVPDividendDistributor: ${dividendDistributor.address}`);

    // 8️⃣ Deploy SVPReporter
    console.log("\n8️⃣  Deploying SVPReporter...");
    const Reporter = await ethers.getContractFactory("SVPReporter");
    const reporter = await Reporter.deploy(valuationEngine.address, assetRegistry.address);
    await reporter.deployed();
    deployments.contracts.SVPReporter = {
      address: reporter.address,
      tx: reporter.deployTransaction?.hash
    };
    console.log(`   ✅ SVPReporter: ${reporter.address}`);

    // 9️⃣ Deploy SVPSPVVault (Base)
    console.log("\n9️⃣  Deploying SVPSPVVault...");
    const Vault = await ethers.getContractFactory("contracts/SVPSPVVault.sol:SVPSPVVault");
    const vault = await Vault.deploy(
      token.address,
      "SPV Vault",
      "vSPV"
    );
    await vault.deployed();
    deployments.contracts.SVPSPVVault = {
      address: vault.address,
      tx: vault.deployTransaction?.hash
    };
    console.log(`   ✅ SVPSPVVault: ${vault.address}`);

    // 🔟 Deploy SVPFactory
    console.log("\n🔟  Deploying SVPFactory...");
    const Factory = await ethers.getContractFactory("SVPFactory");
    const factory = await Factory.deploy();
    await factory.deployed();
    deployments.contracts.SVPFactory = {
      address: factory.address,
      tx: factory.deployTransaction?.hash
    };
    console.log(`   ✅ SVPFactory: ${factory.address}`);

    // 1️⃣1️⃣ Deploy Timelock
    console.log("\n1️⃣1️⃣  Deploying Timelock...");
    const Timelock = await ethers.getContractFactory("Timelock");
    const timelock = await Timelock.deploy(governance.address);
    await timelock.deployed();
    deployments.contracts.Timelock = {
      address: timelock.address,
      tx: timelock.deployTransaction?.hash
    };
    console.log(`   ✅ Timelock: ${timelock.address}`);

    // Summary
    console.log("\n\n✅ DEPLOYMENT COMPLETE!");
    console.log("================================");
    console.log(`Total Contracts Deployed: ${Object.keys(deployments.contracts).length}`);
    console.log("\n📋 Deployment Summary:");
    Object.entries(deployments.contracts).forEach(([name, details]: [string, any]) => {
      console.log(`  • ${name}: ${details.address}`);
    });

    // Save deployment records
    const deploymentsDir = "./deployments";
    if (!fs.existsSync(deploymentsDir)) {
      fs.mkdirSync(deploymentsDir, { recursive: true });
    }
    
    const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
    const filename = `${deploymentsDir}/${network}-${timestamp}.json`;
    fs.writeFileSync(filename, JSON.stringify(deployments, null, 2));
    console.log(`\n💾 Deployment record saved to: ${filename}`);

    // Also update latest deployment
    const latestFile = `${deploymentsDir}/${network}-latest.json`;
    fs.writeFileSync(latestFile, JSON.stringify(deployments, null, 2));
    console.log(`💾 Latest deployment saved to: ${latestFile}`);

  } catch (error: any) {
    console.error("\n❌ Deployment failed:");
    console.error(error.message);
    if (error.reason) console.error(`Reason: ${error.reason}`);
    process.exit(1);
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
