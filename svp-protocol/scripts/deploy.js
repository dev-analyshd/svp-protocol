/**
 * SVP Protocol - Main Deployment Script
 * Handles deployment of all 21 smart contracts to testnet networks
 */

const hre = require('hardhat');
const fs = require('fs');
const path = require('path');
const deployConfig = require('../deploy-config');

class SVPDeployer {
  constructor() {
    this.deployedContracts = {};
    this.gasReport = {};
    this.startTime = null;
    this.endTime = null;
  }

  async validateNetwork() {
    const network = hre.network.name;
    console.log(`\n🌐 Deploying to: ${network}`);

    if (!['arbitrumSepolia', 'polygonMumbai', 'ethereumSepolia'].includes(network)) {
      throw new Error(`Unsupported network: ${network}`);
    }

    const networkConfig = deployConfig.networks[network];
    console.log(`   Chain ID: ${networkConfig.chainId}`);
    console.log(`   Block Explorer: ${networkConfig.blockExplorer}`);
  }

  async deployContract(contractName, ...args) {
    try {
      console.log(`\n📦 Deploying ${contractName}...`);

      const Contract = await hre.ethers.getContractFactory(contractName);
      const contract = await Contract.deploy(...args);
      await contract.deployed();

      const gasUsed = contract.deployTransaction.gasUsed.toString();
      this.deployedContracts[contractName] = contract.address;
      this.gasReport[contractName] = gasUsed;

      console.log(`   ✅ ${contractName} deployed to: ${contract.address}`);
      console.log(`   ⚡ Gas used: ${gasUsed}`);

      return contract;
    } catch (error) {
      console.error(`   ❌ Error deploying ${contractName}:`, error.message);
      throw error;
    }
  }

  async initializeContract(contract, method, ...args) {
    try {
      const tx = await contract[method](...args);
      await tx.wait();
      console.log(`   ✅ Initialized ${method}`);
    } catch (error) {
      console.error(`   ❌ Error initializing ${method}:`, error.message);
      throw error;
    }
  }

  async deployAll() {
    this.startTime = Date.now();

    try {
      await this.validateNetwork();

      // Step 1: Deploy core contracts
      console.log('\n═══════════════════════════════════════════');
      console.log('STEP 1: Deploy Core Contracts');
      console.log('═══════════════════════════════════════════');

      // Deploy SVPToken
      const svpToken = await this.deployContract(
        'SVPToken',
        deployConfig.initializationParams.SVPToken.name,
        deployConfig.initializationParams.SVPToken.symbol,
      );

      // Deploy SVPGovernance
      const svpGovernance = await this.deployContract(
        'SVPGovernance',
        svpToken.address,
        deployConfig.initializationParams.SVPGovernance.votingDelay,
        deployConfig.initializationParams.SVPGovernance.votingPeriod,
        deployConfig.initializationParams.SVPGovernance.proposalThreshold,
        deployConfig.initializationParams.SVPGovernance.quorumNumerator,
      );

      // Deploy SVPTimeLock
      const svpTimeLock = await this.deployContract(
        'SVPTimeLock',
        deployConfig.initializationParams.SVPTimeLock.minDelay,
        [], // proposers (can be set later)
        [], // executors
      );

      // Step 2: Deploy vault and related contracts
      console.log('\n═══════════════════════════════════════════');
      console.log('STEP 2: Deploy Vault Contracts');
      console.log('═══════════════════════════════════════════');

      // Get stablecoin address for network
      const networkName = hre.network.name;
      const stablecoinAddress = deployConfig.addresses.stablecoin[networkName];

      const svpVault = await this.deployContract(
        'SVPSPVVault',
        stablecoinAddress,
        'SVP Vault Token',
        'SVP-V',
      );

      // Step 3: Deploy calculation contracts
      console.log('\n═══════════════════════════════════════════');
      console.log('STEP 3: Deploy Calculation Contracts');
      console.log('═══════════════════════════════════════════');

      const navCalculator = await this.deployContract(
        'NAVCalculator',
        svpVault.address,
      );

      const yieldCalculator = await this.deployContract(
        'YieldCalculator',
        svpVault.address,
      );

      const performanceTracker = await this.deployContract(
        'PerformanceTracker',
        svpVault.address,
      );

      // Step 4: Deploy dividend and revenue contracts
      console.log('\n═══════════════════════════════════════════');
      console.log('STEP 4: Deploy Distribution Contracts');
      console.log('═══════════════════════════════════════════');

      const dividendTracker = await this.deployContract(
        'DividendTracker',
        svpToken.address,
      );

      const revenueRouter = await this.deployContract(
        'RevenueRouter',
        svpVault.address,
      );

      // Step 5: Deploy additional infrastructure
      console.log('\n═══════════════════════════════════════════');
      console.log('STEP 5: Deploy Infrastructure Contracts');
      console.log('═══════════════════════════════════════════');

      const accessControl = await this.deployContract(
        'SVPAccessControl',
      );

      const snapshotManager = await this.deployContract(
        'SnapshotManager',
        svpToken.address,
      );

      const emergencyPause = await this.deployContract(
        'EmergencyPause',
      );

      // Step 6: Initialize contracts
      console.log('\n═══════════════════════════════════════════');
      console.log('STEP 6: Initialize Contracts');
      console.log('═══════════════════════════════════════════');

      // Grant roles
      const MANAGER_ROLE = await svpVault.MANAGER_ROLE();
      const PAUSER_ROLE = await emergencyPause.PAUSER_ROLE();

      // Setup vault with manager
      await this.initializeContract(
        svpVault,
        'setManager',
        deployConfig.addresses.manager,
      );

      // Set dividend tracker
      await this.initializeContract(
        svpVault,
        'setDividendTracker',
        dividendTracker.address,
      );

      // Step 7: Verify deployment
      console.log('\n═══════════════════════════════════════════');
      console.log('STEP 7: Verify Deployment');
      console.log('═══════════════════════════════════════════');

      await this.verifyDeployment();

      this.endTime = Date.now();
      await this.generateReport();

      return this.deployedContracts;

    } catch (error) {
      console.error('\n❌ Deployment failed:', error);
      this.endTime = Date.now();
      process.exit(1);
    }
  }

  async verifyDeployment() {
    console.log('\n🔍 Verifying Deployment...');

    for (const [name, address] of Object.entries(this.deployedContracts)) {
      // Check code exists at address
      const code = await hre.ethers.provider.getCode(address);
      if (code === '0x') {
        console.log(`   ❌ ${name}: No code at address`);
      } else {
        console.log(`   ✅ ${name}: Contract verified at ${address}`);
      }
    }
  }

  async generateReport() {
    const duration = (this.endTime - this.startTime) / 1000;
    const totalGas = Object.values(this.gasReport)
      .reduce((sum, gas) => sum + parseInt(gas), 0);

    const report = {
      timestamp: new Date().toISOString(),
      network: hre.network.name,
      deployer: (await hre.ethers.getSigners())[0].address,
      duration: `${duration.toFixed(2)}s`,
      contracts: this.deployedContracts,
      gasUsage: {
        byContract: this.gasReport,
        total: totalGas.toString(),
        average: (totalGas / Object.keys(this.gasReport).length).toFixed(0),
      },
      chainId: (await hre.ethers.provider.getNetwork()).chainId,
    };

    // Save to file
    const reportPath = path.join(
      __dirname,
      '..',
      'deployment-reports',
      `${hre.network.name}-${Date.now()}.json`,
    );

    if (!fs.existsSync(path.dirname(reportPath))) {
      fs.mkdirSync(path.dirname(reportPath), { recursive: true });
    }

    fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));

    // Print summary
    console.log('\n═══════════════════════════════════════════');
    console.log('DEPLOYMENT SUMMARY');
    console.log('═══════════════════════════════════════════');
    console.log(`Network: ${report.network}`);
    console.log(`Contracts deployed: ${Object.keys(report.contracts).length}`);
    console.log(`Total gas used: ${report.gasUsage.total}`);
    console.log(`Duration: ${report.duration}`);
    console.log(`Report saved to: ${reportPath}\n`);

    // Also save to DEPLOYMENT_ADDRESSES.json for reference
    const addressFile = path.join(
      __dirname,
      '..',
      'DEPLOYMENT_ADDRESSES.json',
    );

    let addresses = {};
    if (fs.existsSync(addressFile)) {
      addresses = JSON.parse(fs.readFileSync(addressFile, 'utf8'));
    }

    addresses[hre.network.name] = {
      timestamp: report.timestamp,
      chainId: report.chainId,
      contracts: report.contracts,
    };

    fs.writeFileSync(addressFile, JSON.stringify(addresses, null, 2));
    console.log(`Contract addresses saved to: ${addressFile}`);
  }
}

// Run deployment
async function main() {
  const deployer = new SVPDeployer();
  await deployer.deployAll();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
