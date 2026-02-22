import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";
import "@nomicfoundation/hardhat-foundry";
import "solidity-coverage";
import "hardhat-gas-reporter";

require("dotenv").config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
        details: {
          yul: true,
        },
      },
      viaIR: true,
    },
  },
  
  networks: {
    hardhat: {
      forking: {
        enabled: process.env.FORKING === "true",
        url: process.env.RPC_URL || "",
      },
    },
    
    arbitrumSepolia: {
      url: process.env.ARBITRUM_SEPOLIA_RPC || "https://sepolia-rollup.arbitrum.io/rpc",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 421614,
    },
    
    robinhoodChain: {
      url: process.env.ROBINHOOD_RPC || "https://testnet.rpc.robinhoodchain.com",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: process.env.ROBINHOOD_CHAIN_ID ? parseInt(process.env.ROBINHOOD_CHAIN_ID) : 1,
    },
    
    localhost: {
      url: "http://127.0.0.1:8545",
    },
  },
  
  etherscan: {
    apiKey: {
      arbitrumSepolia: process.env.ARBISCAN_API_KEY || "",
      robinhoodChain: process.env.ROBINHOOD_API_KEY || "",
    },
  },
  
  gasReporter: {
    enabled: process.env.REPORT_GAS === "true",
    currency: "USD",
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
  },
  
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  
  typechain: {
    outDir: "typechain-types",
    target: "ethers-v5",
  },
};

export default config;
