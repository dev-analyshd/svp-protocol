# Phase 10: Testnet Deployment Guide

**Status**: 🚀 **READY FOR DEPLOYMENT**
**Date**: February 22, 2026
**Target Networks**: Arbitrum Sepolia, Polygon Mumbai, Ethereum Sepolia
**Estimated Duration**: 2-4 hours (all three networks)
**Estimated Cost**: $50-150 USD in testnet gas

---

## 📖 Overview

Phase 10 marks the transition from development to public testing by deploying the SVP Protocol to three major testnets. This guide provides step-by-step instructions for deploying all 21 smart contracts, verifying deployments, and validating functionality on each network.

### Deployment Networks

| Network | Chain ID | RPC Endpoint | Block Explorer | Currency |
|---------|----------|--------------|-----------------|----------|
| **Arbitrum Sepolia** | 421614 | https://sepolia-rollup.arbitrum.io/rpc | https://sepolia.arbiscan.io | ETH |
| **Polygon Mumbai** | 80001 | https://rpc-mumbai.maticvigil.com | https://mumbai.polygonscan.com | MATIC |
| **Ethereum Sepolia** | 11155111 | https://sepolia.infura.io/v3/YOUR_KEY | https://sepolia.etherscan.io | ETH |

### Deployment Order
1. **Arbitrum Sepolia** (Primary testnet, most reliable)
2. **Polygon Mumbai** (Secondary testnet, faster finality)
3. **Ethereum Sepolia** (Final validation, Ethereum mainnet equivalent)

---

## 🎯 Pre-Deployment Preparation

### Step 1: Environment Setup

#### 1.1 Create .env Configuration File
```bash
cd svp-protocol
cp .env.example .env
```

#### 1.2 Configure Required Keys
Edit `.env` with your values:

```dotenv
# Private Key (KEEP SECURE - DO NOT COMMIT)
PRIVATE_KEY=0x... # Your testnet deployer private key

# Deployer Address
DEPLOYER_ADDRESS=0x... # Address corresponding to private key

# RPC Endpoints
ARBITRUM_SEPOLIA_RPC=https://sepolia-rollup.arbitrum.io/rpc
POLYGON_MUMBAI_RPC=https://rpc-mumbai.maticvigil.com
ETHEREUM_SEPOLIA_RPC=https://sepolia.infura.io/v3/YOUR_INFURA_KEY

# Block Explorer API Keys (for verification)
ARBISCAN_API_KEY=YOUR_ARBISCAN_KEY
POLYGON_SCAN_API_KEY=YOUR_POLYGON_SCAN_KEY
ETHERSCAN_API_KEY=YOUR_ETHERSCAN_KEY

# Default Deployment Network
DEPLOYMENT_NETWORK=arbitrum-sepolia

# Governance Parameters
VOTING_DELAY=1
VOTING_PERIOD=50400
QUORUM_PERCENTAGE=20
TIMELOCK_DELAY=172800

# Admin Addresses
ADMIN_ADDRESS=0x... # Your admin wallet
TREASURY_ADDRESS=0x... # Treasury receiver

# Vault Settings
WITHDRAWAL_FEE_BPS=50
MANAGEMENT_FEE_BPS=200
PERFORMANCE_FEE_BPS=1000

# Additional Settings
VERIFY_CONTRACTS=true
REPORT_GAS=true
```

#### 1.3 Obtain API Keys

**Arbiscan API Key**:
1. Visit https://arbiscan.io/apis
2. Create free account if needed
3. Generate API key
4. Add to `.env` as `ARBISCAN_API_KEY`

**PolygonScan API Key**:
1. Visit https://polygonscan.com/apis
2. Create free account
3. Generate API key
4. Add to `.env` as `POLYGON_SCAN_API_KEY`

**Etherscan API Key**:
1. Visit https://etherscan.io/apis
2. Create free account
3. Generate API key
4. Add to `.env` as `ETHERSCAN_API_KEY`

**Infura API Key** (for Ethereum Sepolia):
1. Visit https://infura.io
2. Create account
3. Create Ethereum Sepolia project
4. Copy project RPC URL
5. Update `ETHEREUM_SEPOLIA_RPC` in `.env`

### Step 2: Fund Deployer Wallet

#### 2.1 Arbitrum Sepolia Testnet Funds
1. Visit https://faucet.arbitrum.io/
2. Enter your deployer address
3. Claim 0.5 ETH (can repeat every 24 hours)
4. **Minimum for deployment**: 0.5 ETH

#### 2.2 Polygon Mumbai Testnet Funds
1. Visit https://faucet.polygon.technology/
2. Select "Polygon Mumbai" and "ETH"
3. Enter your deployer address
4. Claim 0.5 ETH
5. **Minimum for deployment**: 0.5 MATIC (can claim in same faucet)

#### 2.3 Ethereum Sepolia Testnet Funds
1. Visit https://sepoliafaucet.com/
2. Enter your deployer address
3. Claim 0.5 ETH
4. **Minimum for deployment**: 1 ETH (Sepolia is expensive)

**Verify Funds**:
```bash
npm run deployer-balance
```

### Step 3: Verify Setup

```bash
# Compile all contracts
npm run compile

# Check compilation
npm run build

# Run local tests
npm test

# Verify gas estimation
npm run estimate-gas
```

**Expected Output**:
```
✓ All 21 contracts compiled successfully
✓ TypeScript compilation successful
✓ 19 tests passing
✓ Gas estimates generated
```

---

## 🚀 Deployment Phase 1: Arbitrum Sepolia

### Phase 1.1: Pre-Deployment Checks

```bash
# Verify contract compilation
npm run compile

# Check deployer balance
npm run deployer-balance

# Expected output:
# Deployer: 0x...
# Arbitrum Sepolia: 0.75 ETH ✓
```

### Phase 1.2: Execute Deployment

```bash
# Deploy to Arbitrum Sepolia
npm run deploy:arbitrum-sepolia
```

**Deployment Progress** (estimated 5-10 minutes):
```
Starting deployment to Arbitrum Sepolia (Chain ID: 421614)...
Using RPC: https://sepolia-rollup.arbitrum.io/rpc
Deployer: 0x...

Deploying SVPToken...
Transaction: 0x... (confirmed in block #XXXXX)
✓ SVPToken deployed to: 0x[SVPToken]
Gas used: 1,234,567

Deploying SVPGovernance...
Transaction: 0x...
✓ SVPGovernance deployed to: 0x[SVPGovernance]
Gas used: 2,345,678

[... 19 more contracts ...]

Deploying EnhancedDividendTracker...
Transaction: 0x...
✓ EnhancedDividendTracker deployed to: 0x[Dividend]
Gas used: 890,123

Verifying contracts on Arbiscan...
✓ SVPToken verified
✓ SVPGovernance verified
[... all contracts verified ...]

Deployment Summary:
Total contracts: 21
Total gas used: ~8,456,789
Estimated cost: $XX.XX
Status: ✓ SUCCESS
```

### Phase 1.3: Save Contract Addresses

After deployment succeeds, save addresses to `deployments/arbitrum-sepolia/contracts.json`:

```json
{
  "chainId": 421614,
  "network": "arbitrum-sepolia",
  "timestamp": "2026-02-22T10:30:00Z",
  "deployer": "0x...",
  "contracts": {
    "SVPToken": {
      "address": "0x...",
      "blockNumber": 12345,
      "transactionHash": "0x...",
      "verified": true
    },
    "SVPGovernance": {
      "address": "0x...",
      "blockNumber": 12346,
      "transactionHash": "0x...",
      "verified": true
    },
    "SVPSPVVault": {
      "address": "0x...",
      "blockNumber": 12347,
      "transactionHash": "0x...",
      "verified": true
    },
    // ... 18 more contracts
  }
}
```

### Phase 1.4: Verify Deployment

#### Verify on Arbiscan
```bash
# Option 1: Automatic verification (included in deploy script)
npm run verify:arbitrum-sepolia
```

#### Manual Verification
1. Visit https://sepolia.arbiscan.io/
2. Search for contract address (e.g., SVPToken)
3. Verify source code displays correctly
4. Check "Is this a proxy?" status
5. Record verification status for each contract

**Checklist**:
- [ ] All 21 contracts appear on Arbiscan
- [ ] Source code visible for all contracts
- [ ] Contract names match deployment
- [ ] Constructor arguments match
- [ ] Bytecode matches compiled version

### Phase 1.5: Test Basic Functionality

```bash
# Test token transfers
npm run test:token:arbitrum-sepolia

# Test governance setup
npm run test:governance:arbitrum-sepolia

# Test vault initialization
npm run test:vault:arbitrum-sepolia
```

**Manual Testing** (using Arbiscan or Web3 tools):

```javascript
// Test 1: Check Token Balance
- Contract: SVPToken (0x...)
- Function: balanceOf(address)
- Input: [deployer_address]
- Expected: Initial supply minted to deployer

// Test 2: Check Governance Admin
- Contract: SVPGovernance (0x...)
- Function: admin()
- Expected: Should return deployer address

// Test 3: Check Vault Parameters
- Contract: SVPSPVVault (0x...)
- Function: asset()
- Expected: Should return USDC address (0x...)

// Test 4: Verify Initialization
- Contract: SVPSPVVault (0x...)
- Function: initialized()
- Expected: true
```

### Phase 1.6: Document Deployment

Create file: `deployments/arbitrum-sepolia/DEPLOYMENT_REPORT.md`

```markdown
# Arbitrum Sepolia Deployment Report

**Date**: February 22, 2026
**Network**: Arbitrum Sepolia (Chain ID: 421614)
**Deployer**: 0x...
**Total Contracts**: 21
**Deployment Status**: ✓ SUCCESS

## Contract Addresses

### Core Contracts
- SVPToken: 0x...
- SVPGovernance: 0x...
- SVPSPVVault: 0x...
- SVPRevenueRouter: 0x...
- SVPDividendTracker: 0x...

### [Complete list of all 21 contracts]

## Verification Status
- Contracts Verified: 21/21 ✓
- Block Explorer: Arbiscan (https://sepolia.arbiscan.io/)
- Verification Date: 2026-02-22

## Gas Usage
- Total Gas: ~8.45M
- Average per Contract: ~403K
- Estimated Cost: $XX.XX

## Test Results
- Token Transfer: ✓ PASS
- Governance Setup: ✓ PASS
- Vault Initialization: ✓ PASS
- Dividend Tracker: ✓ PASS

## Notes
[Any issues or observations during deployment]
```

---

## 🚀 Deployment Phase 2: Polygon Mumbai

### Phase 2.1: Pre-Deployment

```bash
# Wait 30 minutes for Arbitrum deployment to stabilize

# Verify setup for Polygon
npm run config:polygon-mumbai

# Check deployer balance
npm run balance:polygon-mumbai
# Expected: 0.5+ MATIC
```

### Phase 2.2: Execute Deployment

```bash
# Deploy to Polygon Mumbai
npm run deploy:polygon-mumbai
```

**Key Differences from Arbitrum**:
- Network speed: Faster (2-3 sec block time)
- Gas prices: Lower (typically 1-5 Gwei)
- Stablecoin: Different USDC address
  - Mumbai USDC: `0x9999a9B7A1b97b42d02dC1735d15b9c4fcE74b11`

### Phase 2.3: Verify on PolygonScan

```bash
npm run verify:polygon-mumbai
```

Manual verification:
1. Visit https://mumbai.polygonscan.com/
2. Search for each contract address
3. Verify all contracts appear correctly
4. Check governance parameters match Arbitrum deployment

### Phase 2.4: Run Smoke Tests

```bash
npm run test:smoke:polygon-mumbai
```

**Quick Tests**:
- Token transfer works
- Vault accepts deposits
- Governance proposals can be created
- Dividend claims process correctly

### Phase 2.5: Document Polygon Deployment

Create file: `deployments/polygon-mumbai/DEPLOYMENT_REPORT.md`

---

## 🚀 Deployment Phase 3: Ethereum Sepolia

### Phase 3.1: Pre-Deployment

```bash
# Wait 30 minutes for Polygon Mumbai to stabilize

# This is the final testnet - most critical
# Ethereum Sepolia is equivalent to mainnet behavior

# Verify setup
npm run config:ethereum-sepolia

# Check balance (needs more ETH - Sepolia is expensive)
npm run balance:ethereum-sepolia
# Expected: 1+ ETH
```

### Phase 3.2: Execute Deployment

```bash
# Deploy to Ethereum Sepolia
npm run deploy:ethereum-sepolia
```

**Key Points**:
- This is the production-equivalent testnet
- Verify thoroughly as mainnet prep
- Costs more in testnet gas
- Slower block finality (12 seconds)

### Phase 3.3: Comprehensive Verification

```bash
# Verify on Etherscan
npm run verify:ethereum-sepolia

# Run full test suite
npm run test:full:ethereum-sepolia

# Generate gas report
npm run gas-report:ethereum-sepolia
```

Manual verification on https://sepolia.etherscan.io/:
- All 21 contracts visible
- Source code verified
- Constructor args correct
- Initialization events logged

### Phase 3.4: Pre-Mainnet Validation

```bash
# Comprehensive checks before mainnet
npm run validate:ethereum-sepolia

# Check list:
# ✓ All contracts deployed
# ✓ All contracts verified
# ✓ State properly initialized
# ✓ Access controls set
# ✓ No critical warnings
```

### Phase 3.5: Document Ethereum Deployment

Create file: `deployments/ethereum-sepolia/DEPLOYMENT_REPORT.md`

---

## 📊 Post-Deployment Integration

### Step 1: Update Frontend dApp

**File**: `svp-dapp/lib/contracts.ts`

```typescript
export const CONTRACTS = {
  arbitrumSepolia: {
    chainId: 421614,
    svpToken: "0x...",
    svpGovernance: "0x...",
    svpVault: "0x...",
    dividendTracker: "0x...",
    // ... all 21 contracts
  },
  polygonMumbai: {
    chainId: 80001,
    svpToken: "0x...",
    svpGovernance: "0x...",
    svpVault: "0x...",
    // ... all 21 contracts
  },
  ethereumSepolia: {
    chainId: 11155111,
    svpToken: "0x...",
    svpGovernance: "0x...",
    svpVault: "0x...",
    // ... all 21 contracts
  },
};
```

### Step 2: Update SDK

**File**: `svp-sdk/src/contracts.ts`

```typescript
export const TESTNET_CONTRACTS = {
  arbitrumSepolia: {
    // Contract addresses
  },
  polygonMumbai: {
    // Contract addresses
  },
  ethereumSepolia: {
    // Contract addresses
  },
};
```

### Step 3: Test dApp Integration

```bash
# From svp-dapp directory
npm run dev

# Manual tests in browser:
# 1. Connect wallet to Arbitrum Sepolia
# 2. Check contract addresses load correctly
# 3. Test deposit/withdraw flow
# 4. Test governance voting
# 5. Test dividend claims

# Repeat for Polygon Mumbai and Ethereum Sepolia
```

### Step 4: Test SDK Methods

```bash
# From svp-sdk directory
npm test

# Expected: All tests pass with deployed contracts
```

---

## 🔍 Monitoring & Health Checks

### Real-Time Monitoring

Set up monitoring for all three networks:

```bash
# Start monitoring service
npm run monitor:all

# Monitors:
# - Transaction status
# - Gas usage trends
# - Error rates
# - Contract interactions
```

### Daily Health Checks

```bash
# Check all deployments are responsive
npm run health:all

# Verify:
# ✓ RPC endpoints responsive
# ✓ Contracts callable
# ✓ No state corruption
# ✓ Gas prices reasonable
# ✓ No critical errors
```

### Metrics to Track

**For Each Network**:
1. **Deployment Metrics**
   - Total contracts: 21
   - Verification rate: 100%
   - Average deployment time: XX minutes
   - Total gas: ~8.5M
   - Cost: $XX.XX

2. **Network Health**
   - Average block time
   - Current gas price
   - Network status
   - RPC endpoint latency

3. **Contract Health**
   - Total interactions: N
   - Successful transactions: X%
   - Failed transactions: Y%
   - Average gas per transaction: Z

4. **User Activity**
   - Unique addresses: N
   - Total transactions: N
   - Total value locked: $N
   - Average transaction size: $N

---

## 📋 Testing Scenarios

### Scenario 1: Complete User Journey

**Prerequisite**: User has testnet tokens (request from faucet if needed)

**Steps**:
1. Connect wallet to Arbitrum Sepolia
2. Approve USDC for vault
3. Deposit 100 USDC into vault
4. Receive SVP vault shares
5. Check dashboard for balance
6. Wait for dividend distribution
7. Claim dividends
8. Check claimed amount
9. Withdraw shares
10. Verify USDC returned

**Expected**: All steps complete without errors, balances accurate

### Scenario 2: Governance Workflow

**Steps**:
1. View active proposals
2. Create new proposal
3. Cast vote on proposal
4. Monitor voting period
5. Execute passed proposal
6. Verify proposal results

**Expected**: Governance functions correctly, voting counted accurately

### Scenario 3: Multi-Network Test

**Steps**:
1. Deploy on all 3 networks
2. Run same test on each network
3. Compare results
4. Verify consistency

**Expected**: Consistent behavior across all networks

### Scenario 4: Error Handling

**Tests**:
- Send insufficient funds (expect error)
- Send to wrong address (expect revert)
- Call unauthorized function (expect revert)
- Exceed limits (expect revert)

**Expected**: Clear error messages, no stuck transactions

---

## 🔧 Troubleshooting

### Issue: Deployment Fails with "Insufficient Balance"

**Solution**:
```bash
# Get more testnet funds from faucet
# Arbitrum: https://faucet.arbitrum.io/
# Polygon: https://faucet.polygon.technology/
# Ethereum: https://sepoliafaucet.com/

# Verify balance updated
npm run deployer-balance
```

### Issue: Contract Verification Fails

**Solution**:
```bash
# Manual verification
1. Copy source code from svp-protocol/contracts/
2. Go to block explorer
3. Contract -> Verify and Publish
4. Paste source code
5. Match compiler settings
6. Verify

# Or retry automatic verification
npm run verify:[network] --retry
```

### Issue: RPC Endpoint Timeout

**Solution**:
```dotenv
# Try alternative RPC in .env
# For Ethereum Sepolia, try Alchemy instead of Infura
ETHEREUM_SEPOLIA_RPC=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY

# Or use different Polygon provider
POLYGON_MUMBAI_RPC=https://polygon-mumbai.blockpi.network/v1/rpc/public
```

### Issue: Gas Estimation Way Off

**Solution**:
```bash
# Increase gas limit in deploy script
# Contracts should not revert if estimation is wrong

# Check for infinite loops or unbounded operations
npm run analyze:gas

# Review recent gas usage
cat gas-report.txt
```

### Issue: Contract Calls Fail on Frontend

**Solution**:
```bash
# Verify contract addresses in svp-dapp/lib/contracts.ts
# Verify ABI is current
# Verify network is connected correctly
# Check Web3 provider setup

# Test directly with ethers.js
npx hardhat console --network arbitrum-sepolia
> const token = await ethers.getContractAt("SVPToken", "0x...")
> const balance = await token.balanceOf("0x...")
```

---

## 📈 Post-Deployment Metrics

### Success Criteria

✅ **Deployment Success**:
- [ ] All 21 contracts deployed
- [ ] All contracts verified on block explorers
- [ ] Zero deployment errors
- [ ] Total gas under budget

✅ **Functionality**:
- [ ] Token transfer works
- [ ] Governance setup correct
- [ ] Vault accepts deposits
- [ ] Dividends calculate correctly
- [ ] All functions callable

✅ **Integration**:
- [ ] dApp connects to contracts
- [ ] SDK methods work
- [ ] Events emit correctly
- [ ] State consistent

✅ **Monitoring**:
- [ ] Monitoring active
- [ ] Alerts configured
- [ ] Health checks pass
- [ ] Logs available

### Metrics Dashboard

Create dashboard to track:
- Deployments per network
- Contract verification status
- Transaction count per day
- Active addresses
- Total value locked
- Average transaction cost
- Error rate
- Performance metrics

---

## 📞 Support & Documentation

### Documentation Files
- [PHASE10_DEPLOYMENT_CHECKLIST.md](./PHASE10_DEPLOYMENT_CHECKLIST.md) - Detailed checklist
- [TESTNET_CONTRACTS.md](./TESTNET_CONTRACTS.md) - All contract addresses
- [SECURITY_AUDIT_REPORT.md](./SECURITY_AUDIT_REPORT.md) - Security findings
- [README.md](./README.md) - Master documentation

### Useful Links

**Testnets**:
- Arbitrum Sepolia: https://sepolia.arbiscan.io/
- Polygon Mumbai: https://mumbai.polygonscan.com/
- Ethereum Sepolia: https://sepolia.etherscan.io/

**Faucets**:
- Arbitrum: https://faucet.arbitrum.io/
- Polygon: https://faucet.polygon.technology/
- Ethereum: https://sepoliafaucet.com/

**Tools**:
- MetaMask: https://metamask.io/ (browser extension)
- Hardhat: https://hardhat.org/ (development framework)
- Etherscan APIs: https://etherscan.io/apis

### Contact

**Issues**: Create GitHub issue with detailed logs
**Security**: security@svpprotocol.dev
**Deployment**: deployment@svpprotocol.dev
**General**: support@svpprotocol.dev

---

## ✅ Deployment Status

**Phase 10 Status**: 🚀 **READY FOR DEPLOYMENT**

**Next Steps**:
1. ✅ Follow this guide step-by-step
2. ✅ Deploy to Arbitrum Sepolia first
3. ✅ Verify and test thoroughly
4. ✅ Deploy to Polygon Mumbai
5. ✅ Deploy to Ethereum Sepolia
6. → Proceed to Phase 11: Public Testing Period

**Timeline**:
- Deployment: 2-4 hours
- Initial testing: 2-4 hours
- Public testing: 2 weeks
- Third-party audit: 2-4 weeks
- Mainnet: Ready after audit approval

---

**Last Updated**: February 22, 2026
**Version**: 1.0
**Status**: Production Ready ✅

