# SVP Protocol dApp

A comprehensive Next.js frontend application for the SVP Protocol, enabling governance participation, vault management, dividend claims, and analytics.

## Features

### 🏛️ Governance Dashboard
- View active proposals and voting history
- Vote on proposals with value-weighted voting power
- Delegate voting power to other addresses
- Track proposal status and execution

### 💰 Vault Management
- Deposit assets to earn yield
- Withdraw from vault positions
- Monitor APY and performance metrics
- View portfolio composition and allocation

### 🎁 Dividend Distribution
- View pending dividend allocations
- Claim individual or batch dividends
- Track historical claims and distributions
- Monitor performance-based bonuses

### 📊 Analytics & Monitoring
- Real-time contract metrics
- Historical performance tracking
- Revenue source monitoring
- Voting power analytics

## Tech Stack

- **Framework**: Next.js 14 (React 18)
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **State Management**: Redux Toolkit
- **Web3**: ethers.js v5
- **UI Components**: Custom components with Tailwind CSS

## Project Structure

```
svp-dapp/
├── components/          # Reusable React components
│   ├── common/         # Common UI components (Card, Badge, etc)
│   └── Layout.tsx      # Main layout wrapper
├── hooks/              # Custom React hooks
│   ├── useWallet.ts   # Wallet connection logic
│   ├── useGovernance.ts
│   ├── useVault.ts
│   └── useDividends.ts
├── lib/               # Utility functions
│   ├── web3.ts       # Web3 utilities
│   └── contracts.ts  # Contract interaction layer
├── pages/            # Next.js pages and routes
│   ├── _app.tsx
│   ├── _document.tsx
│   ├── dashboard.tsx
│   ├── governance.tsx
│   ├── vault.tsx
│   └── dividends.tsx
├── store/           # Redux store
│   ├── index.ts
│   └── slices/      # Redux slices for each feature
├── styles/          # Global styles
├── types/           # TypeScript type definitions
└── utils/           # Utility functions
```

## Setup & Installation

### Prerequisites
- Node.js 18+
- npm or yarn
- MetaMask or compatible Web3 wallet

### Installation

```bash
cd svp-dapp
npm install
```

### Environment Configuration

Copy `.env.example` to `.env.local` and update with your contract addresses:

```bash
cp .env.example .env.local
```

Edit `.env.local`:
```
NEXT_PUBLIC_CHAIN_ID=1
NEXT_PUBLIC_RPC_URL=http://localhost:8545
NEXT_PUBLIC_GOVERNANCE_ADDRESS=0x...
NEXT_PUBLIC_TOKEN_ADDRESS=0x...
NEXT_PUBLIC_VAULT_ADDRESS=0x...
NEXT_PUBLIC_DIVIDEND_TRACKER_ADDRESS=0x...
```

### Development

```bash
npm run dev
```

Navigate to `http://localhost:3000` in your browser.

### Production Build

```bash
npm run build
npm start
```

## Usage Guide

### Connecting Your Wallet

1. Click "Connect Wallet" in the top-right corner
2. Approve the connection in MetaMask
3. Your wallet address and balance will appear

### Dashboard

The dashboard provides an overview of:
- Portfolio value and APY
- Pending dividends
- Voting power
- Performance score
- Quick action shortcuts

### Governance

1. View all active proposals
2. Click "Vote on Proposal" to participate
3. Select your vote (For/Against/Abstain)
4. Confirm and sign the transaction

### Vault

1. Enter the amount to deposit
2. Approve the token spend
3. Confirm the deposit transaction
4. Monitor your vault position and yields

### Dividends

1. View pending dividend allocations
2. Click "Claim" on individual dividends
3. Or use "Claim All" for batch claiming
4. View your claim history and performance score

## State Management

Redux store manages:

- **Wallet**: Connection state, address, balance, provider
- **Governance**: Proposals, votes, voting power, delegation
- **Vault**: Position, total assets, APY, TVL
- **Dividend**: Pending/claimed amounts, allocations, performance score
- **UI**: Dark mode, sidebar state, notifications

## Custom Hooks

### useWallet()
```typescript
const { address, isConnected, balance, connect, disconnect, refreshBalance } = useWallet();
```

### useGovernance()
```typescript
const { proposals, userVotingPower, delegate, castVote, fetchVotingPower } = useGovernance();
```

### useVault()
```typescript
const { totalAssets, userPosition, deposit, withdraw, fetchVaultData } = useVault();
```

### useDividends()
```typescript
const { pendingDividends, claimedDividends, claimDividend, claimMultipleDividends } = useDividends();
```

## API Layer

Contract interactions are handled through `ContractManager` in `lib/contracts.ts`:

```typescript
const contractManager = new ContractManager(signer);
await contractManager.castVote(proposalId, support);
await contractManager.deposit(amount, receiver);
```

## Component Examples

### Card Component
```tsx
<Card hover>
  <div className="p-6">Content</div>
</Card>
```

### Badge Component
```tsx
<Badge variant="success" size="sm">Active</Badge>
```

### Loading Skeleton
```tsx
<LoadingSkeleton height="h-8" count={3} />
```

## Dark Mode

Dark mode is enabled by default. Toggle via the moon/sun icon in the header.

## Responsive Design

The dApp is fully responsive:
- Mobile: Single column layouts
- Tablet: 2-column grids
- Desktop: 3-4 column layouts

## Error Handling

All errors are displayed as toast notifications with:
- Type (success/error/warning/info)
- User-friendly messages
- Auto-dismiss after 5 seconds

## Gas Optimization

- Batch transaction processing
- Optimized re-renders with Redux selectors
- Lazy loading of data
- Memoized calculations

## Security Considerations

- Private keys never exposed in frontend
- All transactions signed client-side
- No sensitive data in Redux state
- HTTPS recommended for production
- CSP headers configured

## Deployment

### Vercel (Recommended)

```bash
vercel
```

### Self-Hosted

```bash
npm run build
npm start
```

## Browser Support

- Chrome 90+
- Firefox 88+
- Safari 14+
- Edge 90+

## Contributing

1. Create a feature branch
2. Make changes
3. Test locally: `npm run dev`
4. Submit PR

## License

MIT

## Support & Documentation

- Protocol Docs: [SVP Protocol Specification](../PHASE6_SUMMARY.md)
- Smart Contracts: [Smart Contract ABI Reference](../contracts/)
- Architecture: [System Architecture](../PHASE6_ARCHITECTURE.md)

## Roadmap

- [ ] TheGraph subgraph integration for efficient queries
- [ ] Advanced analytics dashboard
- [ ] Mobile app with React Native
- [ ] Multi-chain support
- [ ] Hardware wallet support (Ledger, Trezor)
- [ ] Advanced trading features
- [ ] Portfolio management tools
