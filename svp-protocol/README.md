# 🚀 SVP Protocol - Structured Valuation Protocol

**On-Chain Intrinsic Valuation Engine | Tokenized Equity Infrastructure | Value-Weighted Governance**

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Solidity](https://img.shields.io/badge/solidity-0.8.20-blue)
![Network](https://img.shields.io/badge/network-Arbitrum-purple)

---

## 📋 Overview

SVP Protocol is a **production-ready decentralized protocol** that enables:

- **On-Chain Asset Valuation**: Compute intrinsic value directly on blockchain without external oracles
- **Tokenized Equity**: Convert real-world assets into fractional, tradeable ERC-20/ERC-1400 tokens
- **Value-Weighted Governance**: Voting power = Token Balance × Intrinsic Value
- **Capital Pooling**: ERC-4626 SPV vaults for institutional-grade investment vehicles
- **Automated Revenue Distribution**: Pro-rata dividend distribution to token holders
- **Developer-Ready**: Complete TypeScript SDK, backend relayer, and indexer

**Invented by:** Hudu Yusuf (Analys)  
**Network:** Arbitrum One / Robinhood Chain Testnet  
**Status:** Production-Ready

---

## 🏗️ Architecture Overview

```
User Layer (dApp Frontend)
    ↓
TypeScript SDK Layer
    ↓
Smart Contract Layer
├── SVPValuationEngine (UUPS Upgradeable)
├── SVPAssetRegistry
├── SVPToken (ERC-20/ERC-1400)
├── SVPGovernance (Value-Weighted)
├── SVPSPVVault (ERC-4626)
├── SVPDividendDistributor
└── SVPReporter
    ↓
Blockchain (Arbitrum/Robinhood)
    ↓
Indexer (The Graph / Rust)
```

---

## 🔑 Key Features

### 1. Oracle-Free Valuation Engine

```solidity
IntrinsicValue = NetAssets + (Revenue × GrowthMultiplier) / RiskFactor
```

- No external oracle dependency
- On-chain formula computation
- Modular, pluggable valuation algorithms
- Historical tracking and recalculation

### 2. Value-Weighted Governance

```
Voting Power = TokenBalance × IntrinsicValue / BASE_UNIT
```

- Governance weight tied to asset valuation
- Fair voting proportional to value
- Proposal creation, voting, execution with timelock
- Emergency veto mechanisms

### 3. ERC-4626 SPV Vaults

- Investors deposit stablecoin (USDC/DAI)
- Mint SPV shares
- Vault invests in diversified SVP tokens
- Real-time NAV calculation
- Performance fee management

### 4. Automated Dividend Distribution

- Protocol revenue collected
- Pro-rata distribution to holders
- Claimable at any time
- Historical tracking per distribution

### 5. Security Hardening

- UUPS upgradeable proxy pattern
- Role-based access control (RBAC)
- Multisig admin with timelock
- Emergency pause mechanisms
- Reentrancy protection
- Rate limiting

---

## 📦 Smart Contracts

| Contract | Purpose | Pattern |
|----------|---------|---------|
| **SVPValuationEngine** | Intrinsic value computation | UUPS Upgradeable |
| **SVPAssetRegistry** | Asset registration & tracking | Standalone |
| **SVPToken** | Equity token (ERC-20 + snapshot) | Standalone |
| **SVPGovernance** | Value-weighted voting | Standalone |
| **SVPSPVVault** | Capital pooling (ERC-4626) | Standalone |
| **SVPDividendDistributor** | Revenue distribution | Standalone |
| **SVPReporter** | Data submission & validation | Standalone |
| **SVPFactory** | Instance deployment | Factory |
| **SVPAccessControl** | Centralized RBAC | Standalone |

---

## 🚀 Quick Start

### Prerequisites

- Node.js 18+
- Hardhat
- Arbitrum RPC endpoint (or Robinhood Chain)

### Installation

```bash
# Clone repository
git clone <repo-url>
cd svp-protocol

# Install dependencies
npm install

# Copy environment template
cp .env.example .env
# Edit .env with your values
```

### Compilation

```bash
npm run compile
```

### Testing

```bash
npm run test
npm run coverage
```

### Deployment

```bash
# Arbitrum Sepolia
npm run deploy:testnet

# Robinhood Chain
npm run deploy:robinhood
```

---

## 📚 Documentation

- [Technical Specification](./docs/TECHNICAL_SPECIFICATION.md) - Complete protocol architecture
- [Whitepaper](./docs/WHITEPAPER.md) - Problem statement & market analysis
- [Contract Guide](./docs/CONTRACTS.md) - Detailed contract documentation
- [SDK Reference](./sdk/README.md) - TypeScript SDK usage
- [Deployment Guide](./docs/DEPLOYMENT.md) - Testnet & mainnet deployment

---

## 💻 Smart Contract Deployment

### 1. Deploy Valuation Engine (UUPS)

```typescript
import { upgrades } from "hardhat";

const SVPValuationEngine = await ethers.getContractFactory("SVPValuationEngine");
const proxy = await upgrades.deployProxy(SVPValuationEngine, [], {
  initializer: "initialize",
});
```

### 2. Deploy Asset Registry

```typescript
const SVPAssetRegistry = await ethers.getContractFactory("SVPAssetRegistry");
const registry = await SVPAssetRegistry.deploy();
```

### 3. Deploy Token

```typescript
const SVPToken = await ethers.getContractFactory("SVPToken");
const token = await SVPToken.deploy("TechCorp", "TECH", assetAddress, metadataURI, supplyCap);
```

### 4. Deploy Governance

```typescript
const SVPGovernance = await ethers.getContractFactory("SVPGovernance");
const governance = await SVPGovernance.deploy(valuationEngine.address, token.address, assetAddress);
```

### 5. Deploy SPV Vault (ERC-4626)

```typescript
const SVPSPVVault = await ethers.getContractFactory("SVPSPVVault");
const vault = await SVPSPVVault.deploy(usdcAddress, "SVP SPV Fund", "SVPF");
```

---

## 🎯 Usage Examples

### Register an Asset

```typescript
const tx = await registry.registerAsset(
  assetAddress,
  "TechCorp Inc",
  "ipfs://Qm...",  // metadata
  "Technology",
  "United States"
);
```

### Submit Financial Data

```typescript
const tx = await reporter.submitData(
  assetAddress,
  ethers.parseEther("100000000"),  // $100M revenue
  ethers.parseEther("0.2"),         // 20% growth
  ethers.parseEther("500000000"),   // $500M assets
  ethers.parseEther("200000000"),   // $200M liabilities
  ethers.parseEther("1.5"),         // 1.5x risk
  "ipfs://Qm...",                   // data hash
  "ipfs://Qm..."                    // docs
);
```

### Calculate Valuation

```typescript
const intrinsicValue = await valuationEngine.calculateIntrinsicValue(assetAddress);
console.log("Intrinsic Value:", ethers.formatEther(intrinsicValue));
```

### Invest in SPV

```typescript
// Approve stablecoin
await usdc.approve(vault.address, ethers.parseUnits("10000", 6));

// Deposit
const tx = await vault.deposit(ethers.parseUnits("10000", 6), userAddress);

// Receive SPV shares
```

### Vote on Proposal

```typescript
const votingPower = await governance.getVotingPower(voterAddress);
console.log("Voting Power:", ethers.formatEther(votingPower));

// Cast vote
const tx = await governance.castVote(proposalId, 1, "For reasons...");
```

### Claim Dividends

```typescript
const pending = await distributor.getPendingDividends(userAddress);
const tx = await distributor.claimAllDividends();
```

---

## 🔐 Security Model

### Role-Based Access Control

```
DEFAULT_ADMIN_ROLE
  ├── Can grant/revoke roles
  ├── Can authorize upgrades
  └── Can pause protocol

REPORTER_ROLE
  └── Submit financial data

MINTER_ROLE
  └── Mint new tokens

GOVERNANCE_ROLE
  └── Execute proposals

EMERGENCY_ROLE
  └── Invoke pause mechanisms
```

### Multi-Sig Requirements

- Protocol upgrade: 3-of-5 multisig
- Critical parameters: 2-of-3 multisig
- Emergency pause: 1-of-2

### Timelocks

- Valuation updates: Immediate (admin-controlled)
- Governance execution: 2-day delay
- Contract upgrades: 1-day delay

---

## 📊 Valuation Formula

### Default Algorithm

```
NetAssets = Max(0, Assets - Liabilities)
GrowthMultiplier = 1 + GrowthRate
BaseRevenueValue = Revenue × GrowthMultiplier
RiskAdjustedRevenue = BaseRevenueValue / RiskFactor
IntrinsicValue = NetAssets + RiskAdjustedRevenue
```

### Example

```
Asset: "Growth Tech Inc"
Revenue: $100M
Growth Rate: 20% (1.20x)
Assets: $500M
Liabilities: $200M
Risk Factor: 1.5x

Calculation:
NetAssets = $500M - $200M = $300M
RevenueValue = ($100M × 1.20) / 1.5 = $80M
IntrinsicValue = $300M + $80M = $380M
```

---

## 🧪 Testing

### Test Coverage

- Unit tests for each contract
- Integration tests across modules
- Reentrancy attack simulations
- Overflow/underflow edge cases
- Governance attack scenarios

```bash
# Run all tests
npm run test

# Run specific test file
npm run test test/SVPValuationEngine.test.ts

# Generate coverage report
npm run coverage
```

### Test Structure

```
test/
├── unit/
│   ├── SVPValuationEngine.test.ts
│   ├── SVPToken.test.ts
│   ├── SVPGovernance.test.ts
│   ├── SVPSPVVault.test.ts
│   └── SVPDividendDistributor.test.ts
├── integration/
│   ├── AssetToGovernance.test.ts
│   ├── SPVFlow.test.ts
│   └── DividendFlow.test.ts
└── security/
    ├── ReentrancyAttacks.test.ts
    ├── AccessControl.test.ts
    └── OverflowProtection.test.ts
```

---

## 🌍 Networks Supported

### Currently Active

- **Arbitrum Sepolia Testnet** (Chain ID: 421614)
  - RPC: https://sepolia-rollup.arbitrum.io/rpc
  - Explorer: https://sepolia-explorer.arbitrum.io

- **Robinhood Chain Testnet**
  - RPC: https://testnet.rpc.robinhoodchain.com

### Future Support

- Arbitrum One (Mainnet)
- Ethereum (Mainnet)
- Polygon
- Optimism
- Base

---

## 📋 Protocol Roadmap

### Phase 1: ✅ Architecture & System Design
- Technical specification
- Contract modular breakdown
- Security model definition

### Phase 2: ✅ Core Smart Contracts
- UUPS Proxy pattern implementation
- All 9 core contracts deployed
- Full access control and security

### Phase 3: 🚧 Asset Tokenization (ERC-1400)
- Partition support
- Transfer restrictions
- Compliance hooks

### Phase 4: 🚧 SPV Vault Enhancement
- Portfolio rebalancing automation
- Performance tracking
- Advanced fee structures

### Phase 5: 🚧 Governance Voting
- Full proposal lifecycle
- Quorum calculations
- Emergency veto system

### Phase 6: 🚧 Frontend dApp
- Next.js dashboard
- Wallet integration (RainbowKit)
- Real-time valuation updates

### Phase 7: 🚧 TypeScript SDK
- Complete API bindings
- Integration examples
- Full documentation

### Phase 8: 🚧 Backend Relayer
- Data ingestion
- Off-chain caching
- Event listening

### Phase 9: 🚧 Testing & Security
- 80%+ code coverage
- External audit
- Bug bounty program

### Phase 10: 📅 Deployment
- Testnet deployment
- Mainnet readiness
- Documentation

---

## 🎓 Use Cases

### 1. **Small/Medium Business Tokenization**

```
1. Business registers with SVP
2. Submits quarterly financials
3. SVP calculates valuation
4. Issues equity tokens
5. Investors buy tokens
6. Dividends distributed automatically
```

### 2. **Investment Fund SPV**

```
1. Fund creates SPV vault
2. Investors deposit stablecoin
3. Vault invests in multiple SVP tokens
4. NAV tracked real-time
5. Fund manager rebalances
6. Performance fees collected
```

### 3. **Decentralized Governance**

```
1. Token holders vote on protocol decisions
2. Voting power = Balance × Value
3. Proposals execute after timelock
4. Community-driven development
```

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

**Guidelines:**
- Follow Solidity best practices
- Add tests for new features
- Update documentation
- Ensure 80%+ test coverage

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.

---

## 👥 Team

**Inventor:** Hudu Yusuf (Analys)

**Contributors:**
- Engineering Team
- Security Auditors
- Community Developers

---

## 📞 Support & Contact

- **Documentation**: [./docs/](./docs/)
- **Issues**: GitHub Issues
- **Discord**: [Community Server]
- **Twitter**: [@SVPProtocol]

---

## ⚖️ Disclaimer

SVP Protocol is provided as-is. Users should conduct their own due diligence and security audits before using in production. The protocol is currently in testing phase on Arbitrum Sepolia and Robinhood Chain testnets.

**Not Financial Advice**: This protocol is a technical infrastructure. Any use for financial instruments should comply with local regulations and laws.

---

## 🎉 Acknowledgments

- OpenZeppelin for contract libraries
- Arbitrum for high-performance EVM
- The Ethereum community for building blocks

---

**Built with ❤️ for decentralized finance**

Last Updated: February 19, 2026
