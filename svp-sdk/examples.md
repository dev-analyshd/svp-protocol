# Examples - SVP Protocol SDK

## Example 1: Basic Governance Voting

```typescript
import { SVPProtocol } from 'svp-sdk';
import { ethers } from 'ethers';

async function voteOnProposal() {
  // Setup
  const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);
  const signer = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
  
  const config = {
    governanceAddress: process.env.GOVERNANCE_ADDRESS!,
    vaultAddress: process.env.VAULT_ADDRESS!,
    tokenAddress: process.env.TOKEN_ADDRESS!,
    dividendTrackerAddress: process.env.DIVIDEND_TRACKER_ADDRESS!,
  };

  const svp = new SVPProtocol(signer, config);

  // Get voting power
  const votingPower = await svp.governance.getVotingPower(signer.address);
  console.log(`Your voting power: ${svp.utils.formatTokenAmount(votingPower)}`);

  // Get proposals
  const proposals = await svp.governance.getProposals();
  console.log(`Active proposals: ${proposals.length}`);

  // Vote on first proposal (1 = For)
  const tx = await svp.governance.castVote(proposals[0].id, 1);
  const receipt = await tx.wait();
  console.log(`Vote cast in tx: ${receipt.transactionHash}`);
}

voteOnProposal().catch(console.error);
```

## Example 2: Vault Deposit & Withdrawal

```typescript
import { SVPProtocol } from 'svp-sdk';
import { ethers } from 'ethers';

async function manageVaultPosition() {
  const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);
  const signer = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
  
  const config = {
    governanceAddress: process.env.GOVERNANCE_ADDRESS!,
    vaultAddress: process.env.VAULT_ADDRESS!,
    tokenAddress: process.env.TOKEN_ADDRESS!,
    dividendTrackerAddress: process.env.DIVIDEND_TRACKER_ADDRESS!,
  };

  const svp = new SVPProtocol(signer, config);

  // Check balance
  const balance = await svp.token.balanceOf(signer.address);
  console.log(`Token balance: ${svp.utils.formatTokenAmount(balance)}`);

  // Approve token for vault
  const amount = svp.utils.parseTokenAmount('100', 18);
  const approveTx = await svp.token.approve(config.vaultAddress, amount);
  await approveTx.wait();
  console.log('Tokens approved');

  // Preview deposit
  const sharesOut = await svp.vault.previewDeposit(amount);
  console.log(`You will receive: ${svp.utils.formatTokenAmount(sharesOut)} shares`);

  // Deposit
  const depositTx = await svp.vault.deposit(amount, signer.address);
  await depositTx.wait();
  console.log('Deposit successful');

  // Check position
  const position = await svp.vault.getPosition(signer.address);
  console.log(`Your position: ${svp.utils.formatTokenAmount(position.assets)} assets`);
  console.log(`Current APY: ${position.apy}%`);

  // Withdraw later
  const withdrawAmount = svp.utils.parseTokenAmount('50', 18);
  const withdrawTx = await svp.vault.withdraw(withdrawAmount, signer.address, signer.address);
  await withdrawTx.wait();
  console.log('Withdrawal successful');
}

manageVaultPosition().catch(console.error);
```

## Example 3: Dividend Claims

```typescript
import { SVPProtocol } from 'svp-sdk';
import { ethers } from 'ethers';

async function claimDividends() {
  const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);
  const signer = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
  
  const config = {
    governanceAddress: process.env.GOVERNANCE_ADDRESS!,
    vaultAddress: process.env.VAULT_ADDRESS!,
    tokenAddress: process.env.TOKEN_ADDRESS!,
    dividendTrackerAddress: process.env.DIVIDEND_TRACKER_ADDRESS!,
  };

  const svp = new SVPProtocol(signer, config);

  // Check pending dividends
  const pending = await svp.dividend.getPendingDividends(signer.address);
  console.log(`Pending dividends: ${svp.utils.formatTokenAmount(pending)}`);

  // Get allocations
  const allocations = await svp.dividend.getAllocations(signer.address);
  console.log(`You have ${allocations.length} dividend allocations`);

  allocations.forEach(alloc => {
    console.log(`- Allocation ${alloc.id}: ${svp.utils.formatTokenAmount(alloc.amount)} (Claimed: ${alloc.claimed})`);
  });

  // Claim all pending
  const claimTx = await svp.dividend.claimAllDividends();
  await claimTx.wait();
  console.log('Dividends claimed');

  // Check claimed total
  const claimed = await svp.dividend.getClaimedAmount(signer.address);
  console.log(`Total claimed: ${svp.utils.formatTokenAmount(claimed)}`);
}

claimDividends().catch(console.error);
```

## Example 4: Listen to Events

```typescript
import { SVPProtocol } from 'svp-sdk';
import { ethers } from 'ethers';

async function setupEventListeners() {
  const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);
  
  const config = {
    governanceAddress: process.env.GOVERNANCE_ADDRESS!,
    vaultAddress: process.env.VAULT_ADDRESS!,
    tokenAddress: process.env.TOKEN_ADDRESS!,
    dividendTrackerAddress: process.env.DIVIDEND_TRACKER_ADDRESS!,
  };

  const svp = new SVPProtocol(provider, config);

  // Listen for new proposals
  svp.governance.onProposalCreated((event) => {
    console.log(`New proposal: ${event.proposalId}`);
  });

  // Listen for votes
  svp.governance.onVoteCast((event) => {
    console.log(`Vote cast by ${event.voter}`);
  });

  // Listen for deposits
  svp.vault.onDeposit((event) => {
    console.log(`Deposit: ${event.assets} from ${event.sender}`);
  });

  // Listen for dividends
  svp.dividend.onDividendClaimed((event) => {
    console.log(`Dividend claimed: ${event.amount}`);
  });

  // Listen for transfers
  svp.token.onTransfer((event) => {
    console.log(`Transfer: ${event.value} from ${event.from} to ${event.to}`);
  });

  console.log('Event listeners setup');
}

setupEventListeners().catch(console.error);
```

## Example 5: Portfolio Dashboard

```typescript
import { SVPProtocol } from 'svp-sdk';
import { ethers } from 'ethers';

async function showPortfolioDashboard(userAddress: string) {
  const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);
  
  const config = {
    governanceAddress: process.env.GOVERNANCE_ADDRESS!,
    vaultAddress: process.env.VAULT_ADDRESS!,
    tokenAddress: process.env.TOKEN_ADDRESS!,
    dividendTrackerAddress: process.env.DIVIDEND_TRACKER_ADDRESS!,
  };

  const svp = new SVPProtocol(provider, config);

  // Get token balance
  const tokenBalance = await svp.token.balanceOf(userAddress);
  
  // Get vault position
  const vaultPosition = await svp.vault.getPosition(userAddress);
  
  // Get pending dividends
  const pendingDividends = await svp.dividend.getPendingDividends(userAddress);
  
  // Get voting power
  const votingPower = await svp.governance.getVotingPower(userAddress);

  // Calculate total portfolio value (mock calculation)
  const tokenValue = parseFloat(svp.utils.formatTokenAmount(tokenBalance, 18));
  const vaultValue = parseFloat(svp.utils.formatTokenAmount(vaultPosition.assets, 18));
  const dividendValue = parseFloat(svp.utils.formatTokenAmount(pendingDividends, 18));
  const totalValue = tokenValue + vaultValue + dividendValue;

  console.log('=== Portfolio Dashboard ===');
  console.log(`Total Value: $${totalValue.toFixed(2)}`);
  console.log('');
  console.log('Assets:');
  console.log(`  Token Balance: ${svp.utils.formatTokenAmount(tokenBalance, 18)}`);
  console.log(`  Vault Position: ${svp.utils.formatTokenAmount(vaultPosition.assets, 18)} (${vaultPosition.shares} shares)`);
  console.log(`  Vault APY: ${vaultPosition.apy}%`);
  console.log(`  Pending Dividends: ${svp.utils.formatTokenAmount(pendingDividends, 18)}`);
  console.log('');
  console.log('Governance:');
  console.log(`  Voting Power: ${svp.utils.formatTokenAmount(votingPower, 18)}`);
  console.log('');
}

showPortfolioDashboard('0x...').catch(console.error);
```

## Example 6: Delegation

```typescript
import { SVPProtocol } from 'svp-sdk';
import { ethers } from 'ethers';

async function delegateVotingPower() {
  const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);
  const signer = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
  
  const config = {
    governanceAddress: process.env.GOVERNANCE_ADDRESS!,
    vaultAddress: process.env.VAULT_ADDRESS!,
    tokenAddress: process.env.TOKEN_ADDRESS!,
    dividendTrackerAddress: process.env.DIVIDEND_TRACKER_ADDRESS!,
  };

  const svp = new SVPProtocol(signer, config);

  // Delegate to another address
  const delegateAddress = '0x...';
  const tx = await svp.governance.delegate(delegateAddress);
  await tx.wait();
  
  console.log(`Voting power delegated to ${delegateAddress}`);

  // Verify delegation
  const votingPower = await svp.governance.getVotingPower(delegateAddress);
  console.log(`${delegateAddress} now has ${svp.utils.formatTokenAmount(votingPower)} voting power`);
}

delegateVotingPower().catch(console.error);
```

## Example 7: Error Handling

```typescript
import { SVPProtocol } from 'svp-sdk';
import { ethers } from 'ethers';

async function safeTransfer(to: string, amount: string) {
  const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);
  const signer = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
  
  const config = {
    governanceAddress: process.env.GOVERNANCE_ADDRESS!,
    vaultAddress: process.env.VAULT_ADDRESS!,
    tokenAddress: process.env.TOKEN_ADDRESS!,
    dividendTrackerAddress: process.env.DIVIDEND_TRACKER_ADDRESS!,
  };

  const svp = new SVPProtocol(signer, config);

  try {
    // Validate address
    if (!svp.utils.isValidAddress(to)) {
      throw new Error('Invalid recipient address');
    }

    // Check balance
    const balance = await svp.token.balanceOf(signer.address);
    const transferAmount = svp.utils.parseTokenAmount(amount, 18);

    if (balance.lt(transferAmount)) {
      throw new Error('Insufficient balance');
    }

    // Execute transfer
    const tx = await svp.token.transfer(to, transferAmount);
    const receipt = await tx.wait();

    console.log(`Transfer successful: ${receipt.transactionHash}`);
    return receipt;

  } catch (error: any) {
    if (error.code === 'INSUFFICIENT_FUNDS') {
      console.error('Not enough gas for transaction');
    } else if (error.code === 'ACTION_REJECTED') {
      console.error('User rejected transaction');
    } else if (error.message.includes('Insufficient balance')) {
      console.error('Not enough tokens to transfer');
    } else {
      console.error('Transfer failed:', error.message);
    }
    throw error;
  }
}

safeTransfer('0x...', '100').catch(console.error);
```
