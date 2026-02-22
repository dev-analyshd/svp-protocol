# SVP Protocol - Deployment & Testing Guide
## Complete Instructions for Mainnet Deployment

**Date**: February 22, 2026  
**Version**: 1.0.0-rc.1  
**Network**: Arbitrum Sepolia (Testnet) / Production Ready

---

## 🚀 DEPLOYMENT PIPELINE OVERVIEW

The SVP Protocol deployment consists of **3 main phases**:

1. **📦 Compilation Phase** - Compile all Solidity contracts
2. **🚀 Deployment Phase** - Deploy contracts to blockchain
3. **🧪 Testing Phase** - Verify functionality and performance

---

## 📋 PRE-DEPLOYMENT CHECKLIST

### Environment Setup

- [ ] Node.js v16+ installed
- [ ] npm or yarn package manager ready
- [ ] `.env` file created with all required variables
- [ ] Testnet ETH available in deployer wallet
- [ ] RPC endpoint verified and accessible
- [ ] API keys obtained (Etherscan, BlockScout)

### Required Environment Variables

```bash
# Network & Accounts
PRIVATE_KEY=0x... # Your deployer private key
RPC_URL=https://sepolia-rollup.arbitrum.io/rpc
DEPLOYER_ADDRESS=0x4e42bd090a58d8CC7a99C540b04492B31777096A
ADMIN_ADDRESS=0x... # Multi-sig or admin wallet

# RPC Endpoints
ARBITRUM_SEPOLIA_RPC=https://sepolia-rollup.arbitrum.io/rpc
POLYGON_MUMBAI_RPC=https://rpc-mumbai.maticvigil.com
ETHEREUM_SEPOLIA_RPC=https://sepolia.infura.io/v3/YOUR_KEY

# Block Explorer APIs
ETHERSCAN_API_KEY=41WX1MNRU4QTD5VBNIB94N67Q34UDDPEQ5
ARBISCAN_API_KEY=YOUR_ARBISCAN_KEY
POLYGON_SCAN_API_KEY=YOUR_POLYGONSCAN_KEY

# Optional: Robinhood Chain
ROBINHOOD_RPC=https://testnet.rpc.robinhoodchain.com
ROBINHOOD_CHAIN_ID=46630

# Deployment Config
REPORT_GAS=true
COINMARKETCAP_API_KEY=YOUR_API_KEY
```

---

## 🔧 STEP-BY-STEP DEPLOYMENT

### Step 1: Install Dependencies

```bash
cd svp-protocol
npm install
```

**Expected output:**
```
added XXX packages
audited XXX packages
found 0 vulnerabilities
```

### Step 2: Verify Environment

```bash
npm run pre-deployment-check
```

**Expected checks:**
- [ ] Network connectivity verified
- [ ] Deployer account has sufficient balance
- [ ] RPC endpoint is responsive
- [ ] Required dependencies installed

### Step 3: Compile Smart Contracts

```bash
npm run compile
```

**Expected output:**
```
Compiling 20 smart contracts...
✓ SVPAccessControl.sol
✓ SVPValuationEngine.sol
✓ SVPAssetRegistry.sol
✓ SVPToken.sol
✓ SVPGovernance.sol
[... more contracts ...]
Compilation successful!
Artifacts written to ./artifacts
TypeChain types generated
```

### Step 4: Deploy All Contracts

```bash
npm run deploy:testnet
```

OR for Robinhood Chain:

```bash
npm run deploy:robinhood
```

**Deployment will execute in this order:**

| Phase | Contract | Purpose |
|-------|----------|---------|
| 1 | SVPAccessControl | Role-based access control |
| 2 | SVPValuationEngine | Asset valuation logic |
| 3 | SVPAssetRegistry | Asset registration & tracking |
| 4 | SVPToken | Governance & utility token |
| 5 | SVPGovernance | Voting & governance system |
| 6 | SVPSPVVault | Main vault for assets |
| 7 | SVPDividendDistributor | Dividend distribution |
| 8 | SVPReporter | Data validation |
| 9 | SVPFactory | Factory pattern for instances |

**Expected output:**
```
🚀 Starting SVP Protocol Deployment
==================================

📋 Deployment Configuration:
   Network: arbitrum-sepolia
   Deployer: 0x4e42bd090a58d8CC7a99C540b04492B31777096A
   Admin: 0x4e42bd090a58d8CC7a99C540b04492B31777096A
   Reporters: none

💰 Deployer Balance: 5.234 ETH

📦 Phase 1: Deploying RBAC Foundation
-----------------------------------
✨ SVPAccessControl deployed: 0x...
[... more deployment logs ...]
```

### Step 5: Verify Deployed Contracts

```bash
npm run verify -- --network arbitrumSepolia --contract-name SVPToken
```

This verifies contracts on Etherscan/Arbiscan for transparency.

---

## 🧪 TESTING & VALIDATION

### Run Unit Tests

```bash
npm run test
```

**Test Suites:**
- ✅ Access Control Tests (3 tests)
- ✅ SVP Token Tests (5 tests)
- ✅ Governance Tests (3 tests)
- ✅ Vault Tests (3 tests)
- ✅ Asset Registry Tests (1 test)
- ✅ Integration Tests (2 tests)
- ✅ Security Tests (3 tests)
- ✅ Protocol Behavior Tests (2 tests)
- ✅ Gas Optimization Tests (2 tests)

**Expected output:**
```
SVP Protocol - Complete Test Suite
  1️⃣ Access Control Tests
    ✓ Should have deployed with correct admin (XXms)
    ✓ Should grant roles to users (XXms)
    ✓ Should revoke roles from users (XXms)
  
  2️⃣ SVP Token Tests
    ✓ Should deploy with correct initial supply (XXms)
    ✓ Should mint to deployer address (XXms)
    ... [more test results]

====================================
27 passing (XXs)
```

### Run DApp Integration Tests

```bash
npm run test -- test/dapp.integration.test.ts
```

**Tests cover:**
- Wallet connection
- API connectivity
- Blockchain interaction
- Transaction simulation
- State management
- Error handling
- Performance metrics
- Security validation
- User flow simulation

### Generate Gas Report

```bash
REPORT_GAS=true npm run test
```

**Output:**
```
·────────────────────────────┬──────────┬────────┬───────────┐
│ Contract                   ┊ Method   ┊ Calls  ┊ Gas Used  │
├────────────────────────────┼──────────┼────────┼───────────┤
│ SVPToken                   ┊ transfer ┊ 5      ┊ 445,239   │
│ SVPGovernance              ┊ propose  ┊ 2      ┊ 1,234,567 │
[... more gas metrics ...]
```

---

## 📊 DEPLOYMENT VERIFICATION

### Check Deployed Contracts

After deployment, verify all contracts are properly deployed:

```bash
cat deployments/arbitrum-sepolia-*.json
```

**Output format:**
```json
{
  "timestamp": "2026-02-22T10:00:00.000Z",
  "network": "arbitrum-sepolia",
  "chainId": 421614,
  "deployer": "0x4e42bd090a58d8CC7a99C540b04492B31777096A",
  "contracts": {
    "SVPAccessControl": "0x...",
    "SVPValuationEngine": "0x...",
    "SVPToken": "0x...",
    [... more contracts ...]
  }
}
```

### Query Contract State

```bash
# Check token balance
npx hardhat run scripts/query.ts --network arbitrumSepolia

# Example output:
# Token Total Supply: 1,000,000 SVP
# Deployer Balance: 1,000,000 SVP
# Vault Assets: 0 SVP
```

---

## 🔒 PRODUCTION DEPLOYMENT

### Before Mainnet Launch

1. **Code Review**
   - [ ] All contracts reviewed by security team
   - [ ] No hardcoded addresses or secrets
   - [ ] All upgrade paths approved

2. **Audit**
   - [ ] External security audit completed
   - [ ] All findings addressed
   - [ ] Audit report publicly available

3. **Final Testing**
   - [ ] All tests passing (100% coverage)
   - [ ] Gas optimization verified
   - [ ] Performance benchmarks met

4. **Governance Setup**
   - [ ] Admin roles properly configured
   - [ ] Multi-sig wallet addresses set
   - [ ] Timelock delays configured

### Production Deployment Command

```bash
# For Ethereum Mainnet
npm run deploy -- --network ethereum

# For Arbitrum One
npm run deploy -- --network arbitrumOne

# For Robinhood Chain Mainnet
npm run deploy -- --network robinhoodChainMainnet
```

---

## 📈 POST-DEPLOYMENT ACTIVITIES

### 1. Verify on Block Explorer

Visit the block explorer URLs and verify:
- Contract addresses match deployment record
- Source code can be verified
- Contract interactions appear in transaction history

**Arbitrum Sepolia:**
https://sepolia.arbiscan.io/address/0x...

**Robinhood Chain:**
https://explorer.testnet.chain.robinhood.com/address/0x...

### 2. Initialize Protocol

```bash
npx hardhat run scripts/initialize.ts --network arbitrumSepolia
```

This script will:
- Set governance parameters
- Configure asset types
- Initialize dividend settings
- Grant admin roles

### 3. Monitor Deployment

```bash
npm run monitor
```

Real-time monitoring:
- Contract balance
- Transaction history
- Event logs
- Gas price trends

### 4. Update Frontend Config

Update your DApp frontend with deployed contract addresses:

```javascript
// config/contracts.ts
export const CONTRACTS = {
  network: 'arbitrum-sepolia',
  chainId: 421614,
  tokens: {
    SVP: '0x...',
    VAULT: '0x...',
  },
  governance: {
    GOVERNANCE: '0x...',
    TIMELOCK: '0x...',
  },
  // ... more contracts
};
```

---

## 🐛 TROUBLESHOOTING

### Common Issues

#### Issue: "Insufficient balance for gas"
```bash
Solution: Fund deployer account with more testnet ETH
```

#### Issue: "Contract verification failed"
```bash
Solution: Ensure ETHERSCAN_API_KEY is valid and has quota
```

#### Issue: "RPC endpoint timeout"
```bash
Solution: Check RPC URL is correct and service is operational
```

#### Issue: "Contract already deployed"
```bash
Solution: Use different deployer address or clear deployments folder
```

### Debug Mode

```bash
# Enable verbose logging
DEBUG=hardhat:* npm run deploy:testnet

# Check contract state
npx hardhat run scripts/debug.ts --network arbitrumSepolia

# Validate deployment
npm run verify-deployment
```

---

## 📞 SUPPORT & DOCUMENTATION

- **Documentation**: See [README.md](../README.md)
- **API Reference**: See [docs/API.md](../docs/API.md)
- **Contract ABI**: See [artifacts/contracts/](../artifacts/contracts/)
- **Test Reports**: See [test-results/](../test-results/)

---

## ✅ DEPLOYMENT CHECKLIST - FINAL

- [ ] All dependencies installed
- [ ] Environment variables configured
- [ ] Pre-deployment checks passed
- [ ] Contracts compiled successfully
- [ ] All contracts deployed
- [ ] Unit tests passing (27/27)
- [ ] Integration tests passing
- [ ] DApp tests passing
- [ ] Gas reports reviewed
- [ ] Deployment verified on explorer
- [ ] Frontend configuration updated
- [ ] Monitoring enabled
- [ ] Governance initialized
- [ ] Documentation updated

---

## 🎉 DEPLOYMENT COMPLETE

When all checks pass, your SVP Protocol is ready for:
- ✅ Testnet production use
- ✅ Further security audits
- ✅ User beta testing
- ✅ Gradual mainnet rollout

**Next Steps:**
1. Monitor contract activity
2. Gather user feedback
3. Perform load testing
4. Plan mainnet migration
5. Execute governance proposals for upgrades

---

**Status**: ✅ **READY FOR DEPLOYMENT**  
**Last Updated**: February 22, 2026  
**Version**: 1.0.0-rc.1
