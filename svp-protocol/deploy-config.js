/**
 * SVP Protocol - Deployment Configuration
 * Centralized configuration for all testnet deployments
 */

const deploymentConfig = {
  networks: {
    arbitrumSepolia: {
      name: "Arbitrum Sepolia",
      chainId: 421614,
      rpc: "https://sepolia-rollup.arbitrum.io/rpc",
      blockExplorer: "https://sepolia-explorer.arbitrum.io",
      blockTime: 0.25,
      gasToken: "ETH",
      verifier: "arbitrumSepolia",
      faucet: "https://faucet.arbitrum.io/",
      enabled: true,
      priority: 1,
    },
    polygonMumbai: {
      name: "Polygon Mumbai",
      chainId: 80001,
      rpc: "https://rpc-mumbai.maticvigil.com/",
      blockExplorer: "https://mumbai.polygonscan.com",
      blockTime: 2,
      gasToken: "MATIC",
      verifier: "mumbai",
      faucet: "https://faucet.polygon.technology/",
      enabled: true,
      priority: 2,
    },
    ethereumSepolia: {
      name: "Ethereum Sepolia",
      chainId: 11155111,
      rpc: "https://sepolia.infura.io/v3/YOUR_INFURA_KEY",
      blockExplorer: "https://sepolia.etherscan.io",
      blockTime: 12,
      gasToken: "ETH",
      verifier: "sepolia",
      faucet: "https://sepoliafaucet.com/",
      enabled: false, // Optional
      priority: 3,
    },
  },

  // Deployment order by dependency
  deploymentOrder: [
    "SVPToken",
    "SVPGovernance",
    "SVPTimeLock",
    "SVPSPVVault",
    "NAVCalculator",
    "YieldCalculator",
    "SnapshotManager",
    "PerformanceTracker",
    "DividendTracker",
    "RevenueRouter",
    "MultiAssetRevenueRouter",
    "EnhancedDividendTracker",
    "PerformanceYieldCalculator",
    "SVPAccessControl",
    "SVPEventManager",
    "TokenRegistry",
    "VaultRegistry",
    "GovernanceRegistry",
    "StateManager",
    "EmergencyPause",
    "UpgradeManager",
  ],

  // Contract initialization parameters (can be overridden per network)
  initializationParams: {
    SVPToken: {
      name: "SVP Protocol Token",
      symbol: "SVP",
      initialSupply: "1000000000000000000000000000", // 1B tokens with 18 decimals
    },
    SVPGovernance: {
      votingDelay: "1", // 1 block
      votingPeriod: "50400", // 1 week in blocks (Arbitrum)
      proposalThreshold: "1000000000000000000000000", // 1M tokens
      quorumNumerator: "20", // 20%
    },
    SVPTimeLock: {
      minDelay: "172800", // 2 days in seconds
    },
    SVPSPVVault: {
      managementFee: "2000", // 2% (in basis points)
      performanceFee: "20000", // 20%
      slippageTolerance: "500", // 0.5%
    },
  },

  // Addresses for contract roles and initialization
  addresses: {
    admin: process.env.ADMIN_ADDRESS || "0x0000000000000000000000000000000000000000",
    manager: process.env.MANAGER_ADDRESS || "0x0000000000000000000000000000000000000000",
    reporter: process.env.REPORTER_ADDRESSES || [],
    validator: process.env.VALIDATOR_ADDRESSES || [],
    stablecoin: {
      arbitrumSepolia: "0x0000000000000000000000000000000000000000", // To be set
      polygonMumbai: "0x0000000000000000000000000000000000000000", // USDC on Mumbai
      ethereumSepolia: "0x0000000000000000000000000000000000000000", // USDC on Sepolia
    },
  },

  // Gas optimization settings
  gas: {
    // Optimization from Phase 9
    estimationMultiplier: 1.2, // 20% buffer
    enableOptimization: true,
    reportGas: true,

    // Per-network gas limits
    gasLimits: {
      arbitrumSepolia: {
        standard: 3000000,
        verification: 2000000,
      },
      polygonMumbai: {
        standard: 4000000,
        verification: 3000000,
      },
      ethereumSepolia: {
        standard: 8000000,
        verification: 6000000,
      },
    },
  },

  // Testing configuration
  testing: {
    runInitTests: true,
    runIntegrationTests: true,
    runStressTests: false, // Can be enabled after initial deployment
    testTimeout: 60000, // 60 seconds
  },

  // Verification settings
  verification: {
    enabled: true,
    retries: 3,
    retryDelay: 5000, // 5 seconds between retries
    timeout: 30000, // 30 seconds per verification
  },

  // Monitoring settings
  monitoring: {
    enabled: true,
    pollInterval: 30000, // Poll every 30 seconds
    healthCheckInterval: 300000, // Health check every 5 minutes
    errorAlertThreshold: 3, // Alert after 3 consecutive errors
  },

  // Reporting settings
  reporting: {
    generateGasReport: true,
    generateDeploymentReport: true,
    generateHealthReport: true,
    outputFormat: "json", // json, csv, markdown
  },

  // Rollback settings
  rollback: {
    enabled: true,
    keepBackups: true,
    backupDirectory: "./deployment-backups",
    maxBackupAge: 604800000, // 7 days in milliseconds
  },
};

// Environment-specific overrides
const environmentOverrides = {
  development: {
    networks: {
      arbitrumSepolia: {
        enabled: true,
        priority: 1,
      },
    },
    testing: {
      runStressTests: false,
    },
  },
  staging: {
    networks: {
      arbitrumSepolia: {
        enabled: true,
        priority: 1,
      },
      polygonMumbai: {
        enabled: true,
        priority: 2,
      },
    },
    testing: {
      runStressTests: true,
    },
  },
  production: {
    networks: {
      arbitrumSepolia: {
        enabled: true,
        priority: 1,
      },
      polygonMumbai: {
        enabled: true,
        priority: 2,
      },
      ethereumSepolia: {
        enabled: true,
        priority: 3,
      },
    },
    testing: {
      runStressTests: true,
    },
  },
};

// Apply environment overrides
const env = process.env.DEPLOYMENT_ENV || "development";
const config = {
  ...deploymentConfig,
  ...environmentOverrides[env],
};

module.exports = config;
