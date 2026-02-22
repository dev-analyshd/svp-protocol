# SVP Protocol - Quick Reference Guide

**Purpose:** Fast lookup for developers  
**Updated:** February 19, 2026

---

## 🚀 Quick Start (5 minutes)

```bash
# 1. Install dependencies
cd svp-protocol
npm install

# 2. Compile contracts
npm run compile

# 3. Run tests
npm run test

# 4. Deploy to local network
npx hardhat run scripts/deploy.ts --network localhost

# 5. Deploy to testnet
npm run deploy:testnet
```

---

## 📚 Documentation Map

| Need | File | Purpose |
|------|------|---------|
| **Overview** | [README.md](README.md) | Project intro, features, quick start |
| **Architecture** | [TECHNICAL_SPECIFICATION.md](TECHNICAL_SPECIFICATION.md) | System design, contracts, data flow |
| **Deployment** | [DEPLOYMENT.md](DEPLOYMENT.md) | Setup, configuration, troubleshooting |
| **Terminology** | [GLOSSARY.md](GLOSSARY.md) | Term definitions, acronyms |
| **Status** | [PROJECT_STATUS.md](PROJECT_STATUS.md) | Progress, metrics, next steps |
| **This File** | [QUICK_REFERENCE.md](QUICK_REFERENCE.md) | Fast lookups, common tasks |

---

## 🔑 Contract Quick Ref

### Access Control
```solidity
// Check role
bool hasRole = accessControl.hasRole(REPORTER_ROLE, address);

// Grant role
await accessControl.grantRole(REPORTER_ROLE, reporterAddress);

// Batch grant
await accessControl.grantRolesBatch(REPORTER_ROLE, [addr1, addr2]);

// Revoke role
await accessControl.revokeRole(REPORTER_ROLE, reporterAddress);
```

### Valuation Engine
```solidity
// Submit financial data
await valuationEngine.submitFinancialData(
  assetId,
  revenue,
  growthRate,
  assetValue,
  liabilities,
  riskFactor
);

// Calculate value
uint256 value = await valuationEngine.calculateIntrinsicValue(assetId);

// Get intrinsic value
uint256 current = await valuationEngine.getIntrinsicValue(assetId);
```

### Asset Registry
```solidity
// Register asset
await assetRegistry.registerAsset(
  ownerAddress,
  "Asset Name",
  "ipfs://metadata",
  "Industry",
  "US"
);

// Approve asset
await assetRegistry.approveAsset(assetId);

// Get asset
Asset asset = await assetRegistry.getAsset(assetId);

// Deactivate asset
await assetRegistry.deactivateAsset(assetId);
```

### Token
```solidity
// Mint tokens
await token.mint(recipientAddress, ethers.parseEther("100"));

// Transfer tokens
await token.transfer(toAddress, ethers.parseEther("50"));

// Burn tokens
await token.burn(ethers.parseEther("25"));

// Freeze account
await token.freezeAccount(frozenAddress);

// Unfreeze account
await token.unfreezeAccount(frozenAddress);

// Create snapshot
await token.snapshot(); // Returns snapshot ID

// Check balance at snapshot
uint256 historical = await token.balanceOfAt(address, snapshotId);
```

### Governance
```solidity
// Create proposal
await governance.createProposal(
  targetAddress,
  "Proposal Title",
  "Description"
);

// Cast vote (0=Against, 1=For, 2=Abstain)
await governance.castVote(proposalId, 1);

// Queue proposal
await governance.queueProposal(proposalId);

// Execute proposal
await governance.executeProposal(proposalId);

// Get voting power
uint256 power = await governance.getVotingPower(voterAddress);

// Get proposal state
ProposalState state = await governance.getProposalState(proposalId);
```

### SPV Vault
```solidity
// Deposit into vault
await vault.deposit(
  ethers.parseEther("1000"), // assets
  recipientAddress            // receiver
);

// Withdraw from vault
await vault.withdraw(
  ethers.parseEther("1000"), // assets
  recipientAddress,           // receiver
  ownerAddress               // owner
);

// Request redemption
await vault.requestRedemption(sharesAmount);

// Execute redemption
await vault.executeRedemption(redemptionId);

// Open position
await vault.openPosition(svpTokenAddress, amount);

// Close position
await vault.closePosition(svpTokenAddress);

// Calculate NAV
uint256 nav = await vault.calculateNAV();

// Rebalance
await vault.rebalance();
```

### Dividend Distributor
```solidity
// Deposit dividends
await dividendDistributor.depositDividends(
  ethers.parseEther("100"),    // amount
  rewardTokenAddress,          // token
  "Dividend for Q1"            // description
);

// Claim dividend
await dividendDistributor.claimDividend(distributionId);

// Claim all dividends
await dividendDistributor.claimAllDividends();

// Get pending dividends
uint256 pending = await dividendDistributor.getPendingDividends(claimantAddress);

// Get distribution count
uint256 count = await dividendDistributor.getDistributionCount();
```

### Reporter
```solidity
// Register as reporter
await reporter.registerAsReporter("Company Name", "US");

// Verify reporter (admin only)
await reporter.verifyReporter(reporterAddress);

// Submit financial data
await reporter.submitData(
  assetId,
  revenue,
  growthRate,
  assetValue,
  liabilities,
  riskFactor,
  ["ipfs://doc1", "ipfs://doc2"] // supporting docs
);

// Approve submission (validator only)
await reporter.approveSubmission(submissionId);

// Reject submission (validator only)
await reporter.rejectSubmission(submissionId, "Reason");

// Get reporter info
Reporter info = await reporter.getReporterInfo(reporterAddress);

// Get submission
DataSubmission sub = await reporter.getSubmission(submissionId);
```

### Factory
```solidity
// Deploy instance
await factory.deployInstance(
  tokenImplAddress,
  govImplAddress,
  vaultImplAddress,
  assetRegistryAddress,
  "Instance Name"
);

// Set implementations
await factory.setImplementations(
  newTokenImpl,
  newGovImpl,
  newVaultImpl
);

// Get deployment
Deployment dep = await factory.getDeployment(deploymentId);

// Deactivate deployment
await factory.deactivateDeployment(deploymentId);
```

---

## 🔗 Network Configuration

### Arbitrum Sepolia
```
Network: arbitrumSepolia
Chain ID: 421614
RPC: https://sepolia-rollup.arbitrum.io/rpc
Explorer: https://sepolia-explorer.arbitrum.io/
Symbol: ETH
```

### Robinhood Chain
```
Network: robinhoodChain
Chain ID: [Check docs]
RPC: https://testnet.rpc.robinhoodchain.com
Symbol: ETH
```

### Localhost
```
Network: localhost
Chain ID: 31337
RPC: http://127.0.0.1:8545
```

---

## 🧪 Testing Commands

```bash
# Run all tests
npm run test

# Run specific test file
npx hardhat test test/SVPProtocol.test.ts

# Run with gas report
npm run test -- --reporter-options showGasReport=true

# Generate coverage report
npm run coverage

# Run in watch mode
npx hardhat watch test/

# Run specific test
npx hardhat test --grep "should transfer tokens"
```

---

## 📦 Deployment Commands

```bash
# Compile contracts
npm run compile

# Deploy to Arbitrum Sepolia
npm run deploy:testnet

# Deploy to Robinhood Chain
npm run deploy:robinhood

# Deploy to localhost
npx hardhat run scripts/deploy.ts

# Verify on block explorer
npm run verify -- --network arbitrumSepolia <CONTRACT_ADDRESS>
```

---

## 🔧 Environment Setup

### .env File Template
```bash
# Network RPC URLs
ARBITRUM_SEPOLIA_RPC=https://sepolia-rollup.arbitrum.io/rpc
ROBINHOOD_RPC=https://testnet.rpc.robinhoodchain.com

# Private Key (keep secret!)
PRIVATE_KEY=0x...

# Admin Address (or leave empty to use deployer)
ADMIN_ADDRESS=0x...

# Initial Reporter Addresses (comma-separated)
REPORTER_ADDRESSES=0x...,0x...

# API Keys for verification
ETHERSCAN_API_KEY=...
ARBISCAN_API_KEY=...

# Network Configuration
INITIAL_ASSET=Test Asset
PAUSE_ON_DEPLOY=false
```

---

## 🎯 Role References

| Role | Purpose | Grant Method |
|------|---------|--------------|
| `DEFAULT_ADMIN_ROLE` | Full protocol control | AccessControl.grantRole |
| `REPORTER_ROLE` | Submit financial data | AccessControl.grantRole |
| `MINTER_ROLE` | Mint new tokens | AccessControl.grantRole |
| `GOVERNANCE_ROLE` | Create proposals | AccessControl.grantRole |
| `EMERGENCY_ROLE` | Pause/unpause | AccessControl.grantRole |
| `COMPLIANCE_ROLE` | Freeze accounts | AccessControl.grantRole |
| `VALIDATOR_ROLE` | Approve/reject data | AccessControl.grantRole |

---

## 📊 Gas Estimates

| Operation | Gas | Cost (1 gwei) |
|-----------|-----|---------------|
| Mint tokens | 60,000 | $0.00006 |
| Transfer tokens | 45,000 | $0.000045 |
| Create proposal | 85,000 | $0.000085 |
| Vote on proposal | 75,000 | $0.000075 |
| Deposit to vault | 120,000 | $0.00012 |
| Submit financial data | 150,000 | $0.00015 |
| Calculate valuation | 180,000 | $0.00018 |
| Deploy contract | 2,000,000 | $0.002 |

---

## 🚨 Common Issues & Solutions

### Compilation Errors

**Error:** `Compiler version not compatible`
```bash
npm install solc@0.8.20
npm run compile
```

**Error:** `OutOfMemory during compilation`
```bash
export NODE_OPTIONS=--max-old-space-size=4096
npm run compile
```

### Deployment Errors

**Error:** `Insufficient funds for gas`
- Get testnet ETH from faucet
- Wait for confirmation
- Try again

**Error:** `Nonce too high`
```bash
# Reset account nonce in Hardhat config
# Or use new wallet
```

### Runtime Errors

**Error:** `Call revert without reason`
- Check caller has required role
- Verify contract not paused
- Check function preconditions

**Error:** `Proxy contract not found`
- Verify UUPS proxy deployed correctly
- Check implementation address
- Ensure proxy delegation working

---

## 🔐 Security Reminders

- ✅ Never commit `.env` file
- ✅ Never share private keys
- ✅ Always verify contract addresses
- ✅ Use multisig for admin functions
- ✅ Test on testnet first
- ✅ Check gas prices before deploy
- ✅ Verify contracts on explorer
- ✅ Monitor for suspicious activity

---

## 📈 Useful Links

| Resource | Link |
|----------|------|
| Hardhat Docs | https://hardhat.org |
| OpenZeppelin | https://docs.openzeppelin.com |
| Solidity Docs | https://docs.soliditylang.org |
| Ethereum Development | https://ethereum.org/en/developers |
| Arbitrum Docs | https://docs.arbitrum.io |
| Block Explorer | https://sepolia-explorer.arbitrum.io |
| Faucet | https://faucet.quicknode.com |

---

## 📝 Code Style Guide

### Solidity Best Practices
```solidity
// Use custom errors (not require)
error Unauthorized();
if (!authorized) revert Unauthorized();

// Use events for all state changes
event ValueUpdated(uint256 indexed assetId, uint256 value);

// Use modifiers for access control
modifier onlyRole(bytes32 role) {
    _checkRole(role);
    _;
}

// Use immutable for constants set once
uint256 private immutable VERSION;

// Use external for functions not called internally
function doSomething() external onlyRole(ADMIN_ROLE) {}
```

### Function Organization
1. Constructor
2. External functions (public API)
3. Public functions (internal API)
4. Internal functions (helpers)
5. Private functions (implementation)
6. Fallback/receive (if applicable)

### Naming Conventions
- Constants: `UPPER_CASE`
- Functions: `lowerCamelCase`
- Private/Internal: `_leadingUnderscore`
- Interfaces: `IInterfaceName`
- Events: `PascalCase`
- Enums: `PascalCase`
- Modifiers: `lowerCamelCase`

---

## 🎓 Learning Resources

### For Solidity Beginners
- Read [GLOSSARY.md](GLOSSARY.md) for term definitions
- Study [TECHNICAL_SPECIFICATION.md](TECHNICAL_SPECIFICATION.md) section by section
- Review individual contract comments

### For Advanced Developers
- Review UUPS proxy pattern in SVPValuationEngine.sol
- Study access control implementation
- Examine valuation formula implementation
- Review governance voting mechanism

### For DevOps/Deployment
- Follow [DEPLOYMENT.md](DEPLOYMENT.md) step-by-step
- Review hardhat configuration
- Study deployment script
- Set up monitoring

---

## 🤝 Contributing

### Code Submission Process
1. Fork repository
2. Create feature branch: `git checkout -b feature/your-feature`
3. Commit changes: `git commit -am 'Add feature'`
4. Push to branch: `git push origin feature/your-feature`
5. Submit pull request

### Code Review Checklist
- [ ] Code follows style guide
- [ ] Tests written and passing
- [ ] Comments added
- [ ] No compiler warnings
- [ ] No security issues
- [ ] Gas optimized
- [ ] Documentation updated

---

## 📞 Support

**Found an issue?**
1. Check documentation first
2. Review code comments
3. Search existing issues
4. Submit detailed bug report

**Have a question?**
1. Check [GLOSSARY.md](GLOSSARY.md)
2. Review [TECHNICAL_SPECIFICATION.md](TECHNICAL_SPECIFICATION.md)
3. Check [README.md](README.md) FAQ section
4. Ask in community channels

---

**Version:** 1.0.0  
**Last Updated:** February 19, 2026  
**Next Update:** Upon Phase 3 completion
