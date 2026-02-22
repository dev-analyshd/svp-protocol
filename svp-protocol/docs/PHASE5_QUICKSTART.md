# Phase 5 Quickstart

This quickstart shows how to deploy and run the basic Phase 5 governance scaffolding locally.

Prerequisites
- Node 18+
- npm or yarn
- Hardhat installed (`npm install --save-dev hardhat @nomiclabs/hardhat-ethers ethers chai @types/chai @types/mocha ts-node typescript`)

Run tests
```bash
npm install
npx hardhat test test/governance.test.ts
```

Deploy locally (script)
```bash
npx hardhat run --network localhost scripts/deployGovernance.ts
```

Next steps
- Implement snapshot population in `GovernanceTokenSnapshot` via off-chain collector or on-chain calls
- Wire `SVPGovernanceEnhanced` to real token addresses and `SVPValuationEngine`
- Expand tests to cover proposals, voting, timelock execution, and emergency flows
