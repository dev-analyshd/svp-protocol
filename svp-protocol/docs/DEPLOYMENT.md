# SVP Protocol - Deployment Checklist & Guide

**Date:** February 19, 2026  
**Status:** Ready for Testnet Deployment  
**Networks:** Arbitrum Sepolia, Robinhood Chain

---

## 📋 Pre-Deployment Checklist

### Environment Setup
- [ ] Node.js 18+ installed
- [ ] npm or yarn installed
- [ ] Hardhat installed globally: `npm install -g hardhat`
- [ ] Git configured
- [ ] .env file created with all required variables

### Configuration
- [ ] `.env` file has PRIVATE_KEY set
- [ ] `.env` has correct RPC_URL for target network
- [ ] `.env` has ADMIN_ADDRESS set (multisig or deployer)
- [ ] `.env` has API keys for block explorers (optional, for verification)
- [ ] Network gas settings configured (gwei price estimated)

### Code Review
- [ ] All 9 contracts reviewed for security
- [ ] No hardcoded addresses (except safe defaults)
- [ ] All events properly emitted
- [ ] Error messages clear and descriptive
- [ ] Comments complete and accurate

### Testing
- [ ] Unit tests pass (when available)
- [ ] Integration tests pass
- [ ] Coverage > 70% (minimum, target 80%+)
- [ ] Security tests pass
- [ ] Gas estimates reasonable

### Documentation
- [ ] README.md complete
- [ ] Technical Specification reviewed
- [ ] Contract documentation complete
- [ ] Deployment guide written
- [ ] Known issues documented

---

## 🚀 Deployment Steps

### Phase 1: Local Testing

```bash
# 1. Install dependencies
cd svp-protocol
npm install

# 2. Compile contracts
npm run compile

# 3. Run tests
npm run test

# 4. Check gas estimates
npm run test -- --reporter-options showGasReport=true

# 5. Verify all contracts compile without errors
hardhat compile --show-progress
```

### Phase 2: Configure Environment

```bash
# 1. Copy environment template
cp .env.example .env

# 2. Edit .env with your values
# Required variables:
# - PRIVATE_KEY (deployer account)
# - ARBITRUM_SEPOLIA_RPC (or your network RPC)
# - ADMIN_ADDRESS (or use deployer)
# - REPORTER_ADDRESSES (comma-separated, optional)
```

### Phase 3: Deploy to Testnet

```bash
# 1. Deploy to Arbitrum Sepolia
npm run deploy:testnet

# 2. Or deploy to Robinhood Chain
npm run deploy:robinhood

# 3. Script outputs:
# - Contract addresses
# - Transaction hashes
# - Deployed role assignments
```

### Phase 4: Verify Contracts

```bash
# 1. Verify on block explorer (if API key provided)
npm run verify -- --network arbitrumSepolia

# 2. Or manually verify:
# - Go to block explorer
# - Paste contract address
# - Upload contract code
# - Set compiler version (0.8.20)
# - Set optimization (enabled, 200 runs)
```

### Phase 5: Initialize Protocol

```bash
# 1. Grant initial roles
# - REPORTER_ROLE to data providers
# - VALIDATOR_ROLE to validators
# - MANAGER_ROLE to vault managers

# 2. Set initial parameters
# - Update governance parameters
# - Set validation rules
# - Configure rate limits

# 3. Register first asset (optional test asset)
```

---

## 🔑 Key Addresses After Deployment

After deployment, you'll have:

```
SVPProxy (UUPS): 0x...
SVPValuationEngine (impl): 0x...
SVPAssetRegistry: 0x...
SVPToken (template): 0x...
SVPGovernance (template): 0x...
SVPSPVVault (template): 0x...
SVPDividendDistributor (template): 0x...
SVPReporter: 0x...
SVPFactory: 0x...
```

**Save these addresses!**

---

## 🔗 Network Information

### Arbitrum Sepolia Testnet

```
Network Name: Arbitrum Sepolia
RPC URL: https://sepolia-rollup.arbitrum.io/rpc
Chain ID: 421614
Explorer: https://sepolia-explorer.arbitrum.io/
Faucet: https://faucet.quicknode.com/arbitrum/sepolia
Block Time: ~0.25 seconds
Finality: ~15 seconds
```

### Robinhood Chain (Testnet)

```
Network Name: Robinhood Chain
RPC URL: https://testnet.rpc.robinhoodchain.com
Chain ID: 1 (verify in deployment)
Explorer: [Check RPC provider]
Faucet: [Check RPC provider]
Block Time: ~1-2 seconds
Finality: ~30 seconds
```

---

## 📊 Gas Estimates (Arbitrum)

| Operation | Estimated Gas | Cost (at 1 gwei) |
|-----------|---------------|------------------|
| Deploy SVPValuationEngine | 2,500,000 | $0.0025 |
| Deploy SVPAssetRegistry | 1,200,000 | $0.0012 |
| Deploy SVPToken | 1,500,000 | $0.0015 |
| Deploy SVPGovernance | 800,000 | $0.0008 |
| Deploy SVPSPVVault | 1,800,000 | $0.0018 |
| Deploy SVPDividendDistributor | 1,200,000 | $0.0012 |
| Deploy SVPReporter | 1,200,000 | $0.0012 |
| Deploy SVPFactory | 600,000 | $0.0006 |
| **Total Deployment** | **12,000,000** | **$0.012** |

**Note:** Gas prices on Arbitrum L2 are significantly lower than Ethereum L1.

---

## ✅ Post-Deployment Verification

### Check Contract Deployment

```bash
# 1. Verify contracts exist on chain
hardhat verify --network arbitrumSepolia <CONTRACT_ADDRESS> <CONSTRUCTOR_ARGS>

# 2. Verify via block explorer
# Visit: https://sepolia-explorer.arbitrum.io/address/<CONTRACT_ADDRESS>

# 3. Check contract code is displayed
# Check "Is this a proxy?" status
```

### Verify Roles

```bash
# 1. Check DEFAULT_ADMIN_ROLE
hasRole(DEFAULT_ADMIN_ROLE, DEPLOYER_ADDRESS)

# 2. Check REPORTER_ROLE
hasRole(REPORTER_ROLE, REPORTER_ADDRESS)

# 3. Check other roles similarly
```

### Verify Configuration

```bash
# 1. Check valuation parameters
params() -> (votingDelay, votingPeriod, quorum, etc.)

# 2. Check asset registry empty
getAssetCount() -> 0

# 3. Check no proposals yet
proposalCount() -> 0
```

---

## 🐛 Troubleshooting

### Compilation Errors

**Error:** `Compiler version not compatible`

**Solution:**
```bash
# Check Solidity version
solc --version

# Install correct version if needed
npm install solc@0.8.20
```

**Error:** `OutOfMemory` during compilation

**Solution:**
```bash
# Increase Node memory
export NODE_OPTIONS=--max-old-space-size=4096
npm run compile
```

### Deployment Errors

**Error:** `Insufficient funds for gas`

**Solution:**
```bash
# Get testnet ETH/tokens from faucet
# Wait for confirmation
# Try deployment again
```

**Error:** `Nonce too high`

**Solution:**
```bash
# Reset nonce in Hardhat
# Edit hardhat.config.ts to include:
hardhat: {
  allowUnlimitedContractSize: true,
}
```

### Contract Interaction Errors

**Error:** `Call revert without reason`

**Solution:**
```bash
# Check caller has required role
# Check all preconditions met
# Verify contract not paused
# Check block is after voting period for gov calls
```

**Error:** `Proxy contract not found`

**Solution:**
```bash
# Verify UUPS proxy deployed correctly
# Check implementation address set
# Verify proxy delegation working
```

---

## 📋 Role Assignment Script

After deployment, assign roles:

```typescript
// Example role assignment
const SVP = await ethers.getContractAt("SVPValuationEngine", proxyAddress);
const REPORTER_ROLE = await SVP.REPORTER_ROLE();

// Grant role
const tx = await SVP.grantRole(REPORTER_ROLE, REPORTER_ADDRESS);
await tx.wait();

console.log(`Granted REPORTER_ROLE to ${REPORTER_ADDRESS}`);
```

---

## 🔐 Security Checkpoints

- [ ] Deployer account has sufficient balance
- [ ] Private key never committed to repository
- [ ] All contracts verified on block explorer
- [ ] Multisig admin properly configured
- [ ] Emergency roles assigned
- [ ] No test addresses left in production
- [ ] Rate limits set appropriately
- [ ] Pause mechanism tested
- [ ] Access control verified
- [ ] Upgrade path tested

---

## 📞 Monitoring After Deployment

### Set Up Monitoring

```bash
# 1. Watch contract events via RPC
# 2. Monitor gas prices
# 3. Set up alerts for:
#    - High gas usage
#    - Unusual transaction patterns
#    - Role changes
#    - Protocol pauses
```

### Health Checks

```bash
# Run daily:
# 1. Check contract balance
# 2. Verify no unresolved proposals
# 3. Check asset count
# 4. Monitor fee accumulation
# 5. Verify dividend distributions
```

---

## 🚨 Emergency Procedures

### Pause Protocol

```typescript
// If emergency detected
const ADMIN_ROLE = await SVP.ADMIN_ROLE();
const tx = await SVP.pause();
await tx.wait();

console.log("Protocol paused");
```

### Freeze Account

```typescript
// If compromised account detected
const COMPLIANCE_ROLE = await token.COMPLIANCE_ROLE();
const tx = await token.freezeAccount(compromisedAddress);
await tx.wait();

console.log("Account frozen");
```

### Emergency Upgrade

```typescript
// Only if critical vulnerability found
const newImpl = await deployNewImplementation();
const tx = await proxy.upgradeTo(newImpl.address);
await tx.wait();

console.log("Upgraded to new implementation");
```

---

## 📊 Deployment Logs Example

```
=== SVP Protocol Deployment ===
Network: Arbitrum Sepolia
Deployer: 0x1234...
Timestamp: 2024-02-19T10:30:00Z

Deploying SVPValuationEngine...
✓ Deployed at: 0xaaaa...
✓ Initialized successfully

Deploying SVPAssetRegistry...
✓ Deployed at: 0xbbbb...
✓ Ready for use

Deploying SVPToken...
✓ Deployed at: 0xcccc...
✓ Configured with cap

Deploying SVPGovernance...
✓ Deployed at: 0xdddd...
✓ Linked to valuation engine

[... more contracts ...]

=== Deployment Complete ===
Total Gas Used: 12,345,678
Total Cost: ~$0.015 @ 1 gwei
Transactions: 9
Block Range: 1234567 - 1234575

Next Steps:
1. Verify contracts on explorer
2. Assign roles
3. Run post-deployment tests
4. Monitor for 24 hours
```

---

## 📚 Reference Documentation

- [Hardhat Deployment Guide](https://hardhat.org/hardhat-runner/docs/guides/deploying)
- [OpenZeppelin UUPS Proxy](https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable)
- [Arbitrum RPC Docs](https://docs.arbitrum.io/build-decentralized-apps/arbitrum-ecosystem/dev-tools#rpc)
- [Robinhood Chain Docs](https://docs.robinhoodchain.com/)

---

## ✅ Deployment Verification Checklist

After deployment completes:

- [ ] All 9 contracts deployed
- [ ] Proxy properly configured
- [ ] Roles assigned correctly
- [ ] Events emit properly
- [ ] Contracts verified on explorer
- [ ] Valuation engine operational
- [ ] Asset registry empty and ready
- [ ] Token deployable
- [ ] Governance initialized
- [ ] SPV vault ready
- [ ] Dividend distributor ready
- [ ] Reporter functional
- [ ] Factory operational
- [ ] No compilation warnings
- [ ] No runtime errors in logs
- [ ] Multisig configured (if needed)
- [ ] Emergency procedures tested
- [ ] Monitoring active

---

**Deployment Ready!** ✅

For questions or issues, refer to the [Technical Specification](./TECHNICAL_SPECIFICATION.md) or [README](./README.md).

---

**Last Updated:** February 19, 2026  
**Version:** 1.0.0
