# SVP Protocol SDK - API Reference

## Overview

The SVP Protocol SDK provides TypeScript/JavaScript bindings for interacting with SVP Protocol smart contracts. It includes contract methods, event listeners, and utility functions.

## Installation

```bash
npm install svp-sdk ethers
```

## Quick Start

```typescript
import { SVPProtocol } from 'svp-sdk';
import { ethers } from 'ethers';

// Create SDK instance
const provider = new ethers.providers.JsonRpcProvider('https://your-rpc-url');
const config = {
  governanceAddress: '0x...',
  vaultAddress: '0x...',
  tokenAddress: '0x...',
  dividendTrackerAddress: '0x...',
};

const svp = new SVPProtocol(provider, config);

// Use the SDK
const proposals = await svp.governance.getProposals();
const votingPower = await svp.governance.getVotingPower('0x...');
```

## Governance Module

### Methods

#### `getProposals(): Promise<Proposal[]>`
Fetch all active and past proposals.

```typescript
const proposals = await svp.governance.getProposals();
proposals.forEach(p => {
  console.log(`Proposal ${p.id}: ${p.description}`);
  console.log(`For: ${p.forVotes}, Against: ${p.againstVotes}`);
});
```

#### `getProposal(proposalId: number): Promise<Proposal>`
Get details of a specific proposal.

```typescript
const proposal = await svp.governance.getProposal(1);
```

#### `getVotingPower(account: string): Promise<BigNumber>`
Get voting power for an account.

```typescript
const power = await svp.governance.getVotingPower('0x...');
console.log(`Voting power: ${power}`);
```

#### `delegate(to: string): Promise<Transaction>`
Delegate voting power to another account.

```typescript
const tx = await svp.governance.delegate('0x...');
await tx.wait();
```

#### `castVote(proposalId: number, support: number): Promise<Transaction>`
Cast a vote on a proposal (0=Against, 1=For, 2=Abstain).

```typescript
const tx = await svp.governance.castVote(1, 1); // Vote For
await tx.wait();
```

#### `castVoteWithReason(proposalId: number, support: number, reason: string): Promise<Transaction>`
Cast a vote with a reason.

```typescript
const tx = await svp.governance.castVoteWithReason(1, 1, 'Good proposal for protocol growth');
await tx.wait();
```

#### `createProposal(targets: string[], values: BigNumber[], calldatas: string[], description: string): Promise<Transaction>`
Create a new proposal.

```typescript
const targets = ['0x...'];
const values = [ethers.BigNumber.from(0)];
const calldatas = ['0x...'];
const description = 'Increase funding for development';

const tx = await svp.governance.createProposal(targets, values, calldatas, description);
await tx.wait();
```

### Events

#### `onProposalCreated(callback: (event: Event) => void)`
Listen for new proposals.

```typescript
svp.governance.onProposalCreated((event) => {
  console.log(`New proposal created: ${event.proposalId}`);
});
```

#### `onVoteCast(callback: (event: Event) => void)`
Listen for votes cast.

```typescript
svp.governance.onVoteCast((event) => {
  console.log(`Vote cast: ${event.voter} voted ${event.support}`);
});
```

---

## Vault Module

### Methods

#### `getTotalAssets(): Promise<BigNumber>`
Get total assets under management.

```typescript
const totalAssets = await svp.vault.getTotalAssets();
console.log(`TVL: ${svp.utils.formatTokenAmount(totalAssets)}`);
```

#### `getTotalShares(): Promise<BigNumber>`
Get total shares outstanding.

```typescript
const totalShares = await svp.vault.getTotalShares();
```

#### `getPosition(account: string): Promise<VaultPosition>`
Get user's vault position.

```typescript
const position = await svp.vault.getPosition('0x...');
console.log(`Shares: ${position.shares}, Assets: ${position.assets}, APY: ${position.apy}%`);
```

#### `previewDeposit(assets: BigNumber): Promise<BigNumber>`
Preview how many shares you'll get for depositing assets.

```typescript
const amount = svp.utils.parseTokenAmount('100', 18);
const sharesOut = await svp.vault.previewDeposit(amount);
```

#### `deposit(assets: BigNumber, receiver: string): Promise<Transaction>`
Deposit assets into the vault.

```typescript
const amount = svp.utils.parseTokenAmount('100', 18);
const tx = await svp.vault.deposit(amount, '0x...');
await tx.wait();
```

#### `withdraw(assets: BigNumber, receiver: string, owner: string): Promise<Transaction>`
Withdraw assets from the vault.

```typescript
const amount = svp.utils.parseTokenAmount('50', 18);
const tx = await svp.vault.withdraw(amount, '0x...', '0x...');
await tx.wait();
```

#### `getAPY(): Promise<BigNumber>`
Get current vault APY.

```typescript
const apy = await svp.vault.getAPY();
console.log(`APY: ${apy.toNumber() / 100}%`);
```

### Events

#### `onDeposit(callback: (event: Event) => void)`
Listen for deposits.

```typescript
svp.vault.onDeposit((event) => {
  console.log(`Deposit: ${event.assets} from ${event.sender}`);
});
```

#### `onWithdraw(callback: (event: Event) => void)`
Listen for withdrawals.

```typescript
svp.vault.onWithdraw((event) => {
  console.log(`Withdrawal: ${event.assets} to ${event.receiver}`);
});
```

---

## Token Module

### Methods

#### `balanceOf(account: string): Promise<BigNumber>`
Get token balance for an account.

```typescript
const balance = await svp.token.balanceOf('0x...');
console.log(`Balance: ${svp.utils.formatTokenAmount(balance)}`);
```

#### `allowance(owner: string, spender: string): Promise<BigNumber>`
Get token allowance.

```typescript
const allowance = await svp.token.allowance('0x...', '0x...');
```

#### `approve(spender: string, amount: BigNumber): Promise<Transaction>`
Approve token spending.

```typescript
const amount = svp.utils.parseTokenAmount('1000', 18);
const tx = await svp.token.approve('0x...', amount);
await tx.wait();
```

#### `transfer(to: string, amount: BigNumber): Promise<Transaction>`
Transfer tokens.

```typescript
const amount = svp.utils.parseTokenAmount('100', 18);
const tx = await svp.token.transfer('0x...', amount);
await tx.wait();
```

#### `transferFrom(from: string, to: string, amount: BigNumber): Promise<Transaction>`
Transfer tokens on behalf of another account.

```typescript
const amount = svp.utils.parseTokenAmount('100', 18);
const tx = await svp.token.transferFrom('0x...', '0x...', amount);
await tx.wait();
```

#### `name(): Promise<string>`
Get token name.

```typescript
const name = await svp.token.name();
```

#### `symbol(): Promise<string>`
Get token symbol.

```typescript
const symbol = await svp.token.symbol();
```

#### `decimals(): Promise<number>`
Get token decimals.

```typescript
const decimals = await svp.token.decimals();
```

#### `totalSupply(): Promise<BigNumber>`
Get total token supply.

```typescript
const supply = await svp.token.totalSupply();
```

### Events

#### `onTransfer(callback: (event: Event) => void)`
Listen for transfers.

```typescript
svp.token.onTransfer((event) => {
  console.log(`Transfer: ${event.value} from ${event.from} to ${event.to}`);
});
```

#### `onApproval(callback: (event: Event) => void)`
Listen for approvals.

```typescript
svp.token.onApproval((event) => {
  console.log(`Approval: ${event.spender} approved for ${event.value}`);
});
```

---

## Dividend Module

### Methods

#### `getPendingDividends(account: string): Promise<BigNumber>`
Get pending unclaimed dividends.

```typescript
const pending = await svp.dividend.getPendingDividends('0x...');
console.log(`Pending: ${svp.utils.formatTokenAmount(pending)}`);
```

#### `getAllocations(account: string): Promise<DividendAllocation[]>`
Get all dividend allocations for an account.

```typescript
const allocations = await svp.dividend.getAllocations('0x...');
allocations.forEach(alloc => {
  console.log(`Allocation ${alloc.id}: ${alloc.amount} (Claimed: ${alloc.claimed})`);
});
```

#### `claimDividend(allocationId: number): Promise<Transaction>`
Claim a specific dividend allocation.

```typescript
const tx = await svp.dividend.claimDividend(1);
await tx.wait();
```

#### `claimMultipleDividends(allocationIds: number[]): Promise<Transaction>`
Claim multiple dividends at once.

```typescript
const tx = await svp.dividend.claimMultipleDividends([1, 2, 3]);
await tx.wait();
```

#### `claimAllDividends(): Promise<Transaction>`
Claim all pending dividends.

```typescript
const tx = await svp.dividend.claimAllDividends();
await tx.wait();
```

#### `getClaimedAmount(account: string): Promise<BigNumber>`
Get total claimed dividends.

```typescript
const claimed = await svp.dividend.getClaimedAmount('0x...');
```

#### `getClaimHistory(account: string): Promise<any[]>`
Get claim history.

```typescript
const history = await svp.dividend.getClaimHistory('0x...');
```

#### `getHolderSnapshot(account: string, blockNumber: number): Promise<any>`
Get holder snapshot at a specific block.

```typescript
const snapshot = await svp.dividend.getHolderSnapshot('0x...', 12345678);
```

### Events

#### `onDividendClaimed(callback: (event: Event) => void)`
Listen for dividend claims.

```typescript
svp.dividend.onDividendClaimed((event) => {
  console.log(`Dividend claimed: ${event.amount}`);
});
```

#### `onAllocationCreated(callback: (event: Event) => void)`
Listen for new allocations.

```typescript
svp.dividend.onAllocationCreated((event) => {
  console.log(`New allocation: ${event.allocationId}`);
});
```

---

## Utility Functions

### `formatTokenAmount(amount: BigNumber, decimals?: number, precision?: number): string`
Format token amount for display.

```typescript
const amount = ethers.BigNumber.from('123456789000000000');
const formatted = svp.utils.formatTokenAmount(amount, 18, 2);
// Output: "0.12"
```

### `parseTokenAmount(amount: string, decimals?: number): BigNumber`
Parse token amount from user input.

```typescript
const amount = svp.utils.parseTokenAmount('100.5', 18);
```

### `isValidAddress(address: string): boolean`
Validate Ethereum address.

```typescript
if (svp.utils.isValidAddress('0x...')) {
  console.log('Valid address');
}
```

### `shortenAddress(address: string, chars?: number): string`
Shorten address for display.

```typescript
const short = svp.utils.shortenAddress('0x1234567890abcdef...');
// Output: "0x1234...cdef"
```

### `formatPercentage(value: number, decimals?: number): string`
Format percentage value.

```typescript
const pct = svp.utils.formatPercentage(0.1234, 2);
// Output: "12.34%"
```

### `getCurrentTimestamp(): number`
Get current Unix timestamp.

```typescript
const now = svp.utils.getCurrentTimestamp();
```

### `blockToDate(blockTimestamp: number): Date`
Convert block timestamp to Date.

```typescript
const date = svp.utils.blockToDate(1645000000);
console.log(date.toISOString());
```

---

## Error Handling

```typescript
try {
  const tx = await svp.governance.castVote(1, 1);
  await tx.wait();
} catch (error) {
  if (error.code === 'INSUFFICIENT_FUNDS') {
    console.error('Not enough gas');
  } else if (error.code === 'ACTION_REJECTED') {
    console.error('User rejected transaction');
  } else {
    console.error('Unexpected error:', error.message);
  }
}
```

---

## TypeScript Interfaces

```typescript
interface Proposal {
  id: string;
  proposer: string;
  description: string;
  startBlock: number;
  endBlock: number;
  forVotes: BigNumber;
  againstVotes: BigNumber;
  abstainVotes: BigNumber;
  executed: boolean;
  canceled: boolean;
}

interface VaultPosition {
  shares: BigNumber;
  assets: BigNumber;
  apy: number;
}

interface DividendAllocation {
  id: string;
  amount: BigNumber;
  claimed: boolean;
  timestamp: number;
}
```

---

## License

MIT
