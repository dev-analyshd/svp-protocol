# SVP Protocol - Structured Valuation Protocol

> A next-generation on-chain asset tokenization and value-weighted governance protocol built for Arbitrum.

## 🎯 Overview

SVP Protocol is a comprehensive blockchain solution that enables:
- **Asset Tokenization**: Tokenize real-world and digital assets on-chain
- **Value-Weighted Governance**: Voting power proportional to asset value
- **Dividend Distribution**: Automated revenue sharing for token holders
- **Multi-Asset Support**: ERC-20, ERC-1400, and custom token standards
- **Advanced Vault System**: ERC-4626 compliant vaults with performance tracking

## 📦 Project Structure

```
svp-protocol/              # Smart Contracts (Solidity 0.8.20)
├── contracts/             # Core contracts
│   ├── core/             # Essential contracts
│   ├── interfaces/       # Contract interfaces
│   └── libraries/        # Reusable libraries
├── scripts/              # Deployment scripts
├── test/                 # Test suites
├── deployments/          # Deployment records
└── package.json          # Dependencies

svp-dapp/                 # Frontend Application (Next.js 14)
├── pages/               # Next.js pages
├── components/          # React components
├── hooks/              # Custom React hooks
├── styles/             # Tailwind CSS
└── lib/               # Utilities and helpers

svp-sdk/                # TypeScript SDK
├── src/               # SDK source
└── examples.md        # Usage examples
```

## 🚀 Quick Start

### Prerequisites
- Node.js 16+ and npm/yarn
- Git
- MetaMask or Web3 wallet

### Installation

#### 1. Smart Contracts
```bash
cd svp-protocol
npm install --legacy-peer-deps
npm run compile
npm run test
```

#### 2. Frontend DApp
```bash
cd svp-dapp
npm install --legacy-peer-deps
npm run dev
# Opens http://localhost:3000
```

#### 3. SDK
```bash
cd svp-sdk
npm install
npm run build
```

## 🌐 Networks

### Testnet Deployments
| Network | Chain ID | Status | RPC |
|---------|----------|--------|-----|
| Arbitrum Sepolia | 421614 | ✅ Ready | https://sepolia-rollup.arbitrum.io/rpc |
| Robinhood Testnet | 1 | ✅ Ready | https://testnet.rpc.robinhoodchain.com |

### Configuration
Environment variables are pre-configured in `.env`. Update with your:
- `PRIVATE_KEY`: Deployer private key
- `RPC_URL`: Network RPC endpoint
- `ADMIN_ADDRESS`: Admin wallet
- `API_KEYS`: Block explorer verification keys

## 📋 Smart Contracts

### Core Contracts (10 Total)

1. **SVPAccessControl** - Role-based access control
2. **SVPValuationEngine** - Asset valuation logic
3. **SVPAssetRegistry** - Asset management
4. **SVPToken** - ERC-1400 security token
5. **SVPGovernanceEnhanced** - Enhanced voting system
6. **SVPSPVVaultOptimized** - ERC-4626 vault
7. **SVPDividendDistributor** - Revenue distribution
8. **SVPReporter** - Data validation
9. **SVPFactory** - Contract factory
10. **Timelock** - Time-locked governance

## 🧪 Testing

```bash
cd svp-protocol

# Run all tests
npm run test

# Run with coverage
npm run coverage

# Run specific test file
npm run test -- --grep "SVPToken"
```

### Test Statistics
- **Total Tests**: 99
- **Coverage**: >90% of contracts
- **Gas Reports**: Enabled and tracked

## 🚢 Deployment

### Local Hardhat
```bash
cd svp-protocol
npm run deploy:local
```

### Arbitrum Sepolia Testnet
```bash
cd svp-protocol
npm run deploy:arb
```

### Robinhood Testnet
```bash
cd svp-protocol
npm run deploy:robinhood
```

Deployments are saved to `deployments/` directory with timestamp.

## 💻 Frontend Features

- **Wallet Connection**: MetaMask, WalletConnect, Coinbase Wallet
- **Token Dashboard**: Real-time token metrics and analytics
- **Governance**: Create proposals, vote, view voting power
- **Vault Management**: Deposit, withdraw, track yields
- **Dividend Tracker**: Monitor dividends and claims
- **Asset Registry**: Browse all registered assets

### Tech Stack
- **Framework**: Next.js 14
- **Styling**: Tailwind CSS + PostCSS
- **State**: Redux Toolkit + Zustand
- **Web3**: ethers.js v5 + wagmi
- **Charting**: Recharts
- **Forms**: React Hook Form
- **UI**: Lucide Icons + Custom Components

## 🔐 Security

### Audit Status
- [x] Contract compilation verified
- [x] Dependency audit completed
- [x] Gas optimization applied
- [ ] Professional audit (scheduled)

### Security Features
- Access control with role-based permissions
- ReentrancyGuard on sensitive functions
- Safe math operations (OpenZeppelin)
- Event logging for all state changes
- Pausable pattern for emergency stops

## 📊 Gas Optimization

Contracts optimized with:
- IR-based compilation (Solidity 0.8.20)
- 200+ optimizer runs
- Efficient storage layout
- Minimal external calls

**Average Gas Usage**:
- Token Transfer: ~65k gas
- Governance Proposal: ~120k gas
- Vault Deposit: ~180k gas

## 🔗 API Documentation

### SDK Methods
```typescript
import { SVPClient } from '@svp-protocol/sdk';

const client = new SVPClient({
  rpcUrl: 'https://sepolia-rollup.arbitrum.io/rpc',
  contractAddresses: { /* ... */ }
});

// Get token balance
const balance = await client.getBalance(userAddress);

// Create proposal
const proposal = await client.governance.createProposal({
  title: 'Proposal Title',
  description: 'Description',
  actions: []
});

// Deposit to vault
const tx = await client.vault.deposit(vaultAddress, amount);
```

See [SDK Documentation](./svp-sdk/docs/API.md) for complete API reference.

## 📈 Roadmap

### Phase 1 (Current)
- [x] Core contracts deployed
- [x] Frontend MVP live
- [x] Testnet deployment
- [ ] Security audit

### Phase 2 (Q2 2026)
- [ ] Mainnet deployment
- [ ] Advanced features (cross-chain, auto-compounds)
- [ ] DAO governance
- [ ] Community programs

### Phase 3 (Q3 2026+)
- [ ] Institutional partnerships
- [ ] Integration with major DeFi protocols
- [ ] Advanced analytics and reporting
- [ ] Multi-chain support

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Development Standards
- TypeScript for all new code
- Follow existing code style
- Add tests for new features
- Update documentation

## 📄 License

MIT License - see [LICENSE](./LICENSE) file

## 📞 Support & Community

- **GitHub Issues**: Report bugs and request features
- **Discord**: [Join Community](https://discord.gg/svpprotocol) (Coming soon)
- **Email**: support@svpprotocol.dev
- **Docs**: https://docs.svpprotocol.dev (Coming soon)

## ⚠️ Disclaimer

This project is currently in BETA. Testnet only for now. Not audited. Use at own risk.

**Do not commit real funds until after professional security audit.**

## 🙏 Acknowledgments

- Built with [OpenZeppelin](https://openzeppelin.com/) contracts
- Using [Hardhat](https://hardhat.org/) for development
- Frontend powered by [Next.js](https://nextjs.org/) and [Tailwind CSS](https://tailwindcss.com/)
- Deployed on [Arbitrum](https://arbitrum.io/)

---

**Version**: 1.0.0 (Beta)  
**Last Updated**: February 22, 2026  
**Status**: Ready for Testnet Deployment
