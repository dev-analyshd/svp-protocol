/**
 * SVP Protocol Simple Deployment Script (ethers v5 compatible)
 * Usage: npx hardhat run scripts/simpleDeploy.ts --network <network>
 */

import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("\n🚀 SVP Protocol Deployment Started");
  console.log("=====================================");
  console.log(`📍 Network: ${process.env.HARDHAT_NETWORK || 'hardhat'}`);
  console.log(`👤 Deployer: ${deployer.address}`);

  // Check balance
  const balance = await deployer.getBalance();
  console.log(`💰 Balance: ${ethers.utils.formatEther(balance)} ETH\n`);

  if (balance.eq(0)) {
    console.error("❌ Deployer has no balance!");
    process.exit(1);
  }

  try {
    // Deploy SVPAccessControl
    console.log("1️⃣  Deploying SVPAccessControl...");
    const AccessControl = await ethers.getContractFactory("SVPAccessControl");
    const accessControl = await AccessControl.deploy();
    await accessControl.deployed();
    console.log(`   ✅ SVPAccessControl: ${accessControl.address}`);

    // Deploy SVPValuationEngine
    console.log("\n2️⃣  Deploying SVPValuationEngine...");
    const ValuationEngine = await ethers.getContractFactory("SVPValuationEngine");
    const valuationEngine = await ValuationEngine.deploy();
    await valuationEngine.deployed();
    console.log(`   ✅ SVPValuationEngine: ${valuationEngine.address}`);

    // Deploy SVPAssetRegistry
    console.log("\n3️⃣  Deploying SVPAssetRegistry...");
    const AssetRegistry = await ethers.getContractFactory("SVPAssetRegistry");
    const assetRegistry = await AssetRegistry.deploy();
    await assetRegistry.deployed();
    console.log(`   ✅ SVPAssetRegistry: ${assetRegistry.address}`);

    // Deploy SVPToken
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
    console.log(`   ✅ SVPToken: ${token.address}`);

    // Deploy SVPGovernanceEnhanced
    console.log("\n5️⃣  Deploying SVPGovernanceEnhanced...");
    const Governance = await ethers.getContractFactory("SVPGovernanceEnhanced");
    const governance = await Governance.deploy(token.address);
    await governance.deployed();
    console.log(`   ✅ SVPGovernanceEnhanced: ${governance.address}`);

    // Deploy SVPDividendDistributor
    console.log("\n6️⃣  Deploying SVPDividendDistributor...");
    const DividendDistributor = await ethers.getContractFactory("SVPDividendDistributor");
    const dividendDistributor = await DividendDistributor.deploy(token.address);
    await dividendDistributor.deployed();
    console.log(`   ✅ SVPDividendDistributor: ${dividendDistributor.address}`);

    // Deploy SVPReporter
    console.log("\n7️⃣  Deploying SVPReporter...");
    const Reporter = await ethers.getContractFactory("SVPReporter");
    const reporter = await Reporter.deploy(accessControl.address);
    await reporter.deployed();
    console.log(`   ✅ SVPReporter: ${reporter.address}`);

    // Deploy SVPFactory
    console.log("\n8️⃣  Deploying SVPFactory...");
    const Factory = await ethers.getContractFactory("SVPFactory");
    const factory = await Factory.deploy(accessControl.address, assetRegistry.address);
    await factory.deployed();
    console.log(`   ✅ SVPFactory: ${factory.address}`);

    // Save deployment addresses
    const deploymentRecord = {
      network: process.env.HARDHAT_NETWORK || 'hardhat',
      timestamp: new Date().toISOString(),
      deployer: deployer.address,
      contracts: {
        SVPAccessControl: accessControl.address,
        SVPValuationEngine: valuationEngine.address,
        SVPAssetRegistry: assetRegistry.address,
        SVPToken: token.address,
        SVPGovernanceEnhanced: governance.address,
        SVPDividendDistributor: dividendDistributor.address,
        SVPReporter: reporter.address,
        SVPFactory: factory.address,
      }
    };

    const fs = require("fs");
    const path = require("path");
    const deployDir = path.join(__dirname, "../deployments");
    if (!fs.existsSync(deployDir)) {
      fs.mkdirSync(deployDir, { recursive: true });
    }
    
    const networkName = process.env.HARDHAT_NETWORK || 'hardhat';
    const filename = path.join(deployDir, `${networkName}-${Date.now()}.json`);
    fs.writeFileSync(filename, JSON.stringify(deploymentRecord, null, 2));

    console.log(`\n✅ Deployment Complete!`);
    console.log(`📄 Addresses saved to: ${filename}`);
    console.log("\n📋 Contract Addresses:");
    console.log("========================");
    Object.entries(deploymentRecord.contracts).forEach(([name, address]) => {
      console.log(`${name}: ${address}`);
    });

  } catch (error) {
    console.error("\n❌ Deployment failed:", error);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
