import { BigNumber, Contract, ethers, EventFilter, Event } from 'ethers';
import { SVPConfig, ProviderOrSigner, Proposal, VaultPosition, DividendAllocation } from './types';
import { GovernanceABI, VaultABI, TokenABI, DividendTrackerABI } from './abi';
import { EventEmitter } from 'events';

/**
 * Main SVP Protocol SDK Class
 * Provides unified interface to all SVP Protocol modules
 */
export class SVPProtocol extends EventEmitter {
  public governance: GovernanceModule;
  public vault: VaultModule;
  public token: TokenModule;
  public dividend: DividendModule;
  public utils: UtilityFunctions;

  constructor(
    providerOrSigner: ProviderOrSigner,
    config: SVPConfig
  ) {
    super();
    this.governance = new GovernanceModule(providerOrSigner, config.governanceAddress);
    this.vault = new VaultModule(providerOrSigner, config.vaultAddress);
    this.token = new TokenModule(providerOrSigner, config.tokenAddress);
    this.dividend = new DividendModule(providerOrSigner, config.dividendTrackerAddress);
    this.utils = new UtilityFunctions();
  }
}

/**
 * Governance Module - Proposal, voting, and delegation management
 */
export class GovernanceModule extends EventEmitter {
  private contract: Contract;

  constructor(providerOrSigner: ProviderOrSigner, address: string) {
    super();
    this.contract = new Contract(address, GovernanceABI, providerOrSigner);
  }

  /**
   * Get all proposals
   */
  async getProposals(): Promise<Proposal[]> {
    const proposalCount = await this.contract.proposalCount();
    const proposals: Proposal[] = [];

    for (let i = 1; i <= proposalCount; i++) {
      const proposal = await this.contract.proposals(i);
      proposals.push({
        id: proposal.id.toString(),
        proposer: proposal.proposer,
        description: proposal.description,
        startBlock: proposal.startBlock.toNumber(),
        endBlock: proposal.endBlock.toNumber(),
        forVotes: proposal.forVotes,
        againstVotes: proposal.againstVotes,
        abstainVotes: proposal.abstainVotes,
        executed: proposal.executed,
        canceled: proposal.canceled,
      });
    }

    return proposals;
  }

  /**
   * Get a specific proposal by ID
   */
  async getProposal(proposalId: string | number): Promise<Proposal> {
    const proposal = await this.contract.proposals(proposalId);
    return {
      id: proposal.id.toString(),
      proposer: proposal.proposer,
      description: proposal.description,
      startBlock: proposal.startBlock.toNumber(),
      endBlock: proposal.endBlock.toNumber(),
      forVotes: proposal.forVotes,
      againstVotes: proposal.againstVotes,
      abstainVotes: proposal.abstainVotes,
      executed: proposal.executed,
      canceled: proposal.canceled,
    };
  }

  /**
   * Get voting power for an account
   */
  async getVotingPower(account: string): Promise<BigNumber> {
    return this.contract.getVotes(account);
  }

  /**
   * Get current block votes for an account
   */
  async getVotesAtBlock(account: string, blockNumber: number): Promise<BigNumber> {
    return this.contract.getPriorVotes(account, blockNumber);
  }

  /**
   * Delegate voting power
   */
  async delegate(to: string): Promise<any> {
    return this.contract.delegate(to);
  }

  /**
   * Delegate voting power from another account
   */
  async delegateBySig(delegatee: string, nonce: number, expiry: number, v: number, r: string, s: string): Promise<any> {
    return this.contract.delegateBySig(delegatee, nonce, expiry, v, r, s);
  }

  /**
   * Cast a vote on a proposal
   */
  async castVote(proposalId: string | number, support: number): Promise<any> {
    return this.contract.castVote(proposalId, support);
  }

  /**
   * Cast a vote with reason
   */
  async castVoteWithReason(proposalId: string | number, support: number, reason: string): Promise<any> {
    return this.contract.castVoteWithReason(proposalId, support, reason);
  }

  /**
   * Create a proposal
   */
  async createProposal(
    targets: string[],
    values: BigNumber[],
    calldatas: string[],
    description: string
  ): Promise<any> {
    return this.contract.propose(targets, values, calldatas, description);
  }

  /**
   * Queue a proposal for execution
   */
  async queueProposal(proposalId: string | number): Promise<any> {
    return this.contract.queue(proposalId);
  }

  /**
   * Execute a proposal
   */
  async executeProposal(proposalId: string | number): Promise<any> {
    return this.contract.execute(proposalId);
  }

  /**
   * Cancel a proposal
   */
  async cancelProposal(proposalId: string | number): Promise<any> {
    return this.contract.cancel(proposalId);
  }

  /**
   * Listen for proposal created events
   */
  onProposalCreated(callback: (event: Event) => void): void {
    this.contract.on('ProposalCreated', callback);
  }

  /**
   * Listen for vote cast events
   */
  onVoteCast(callback: (event: Event) => void): void {
    this.contract.on('VoteCast', callback);
  }

  /**
   * Remove all event listeners
   */
  removeAllListeners(): void {
    this.contract.removeAllListeners();
  }
}

/**
 * Vault Module - Deposit, withdrawal, and position management
 */
export class VaultModule extends EventEmitter {
  private contract: Contract;

  constructor(providerOrSigner: ProviderOrSigner, address: string) {
    super();
    this.contract = new Contract(address, VaultABI, providerOrSigner);
  }

  /**
   * Get total assets in vault
   */
  async getTotalAssets(): Promise<BigNumber> {
    return this.contract.totalAssets();
  }

  /**
   * Get total shares outstanding
   */
  async getTotalShares(): Promise<BigNumber> {
    return this.contract.totalSupply();
  }

  /**
   * Get user's vault position
   */
  async getPosition(account: string): Promise<VaultPosition> {
    const shares = await this.contract.balanceOf(account);
    const assets = await this.contract.convertToAssets(shares);
    const apy = await this.contract.getAPY();

    return {
      shares,
      assets,
      apy: apy.toNumber() / 100, // Convert from basis points
    };
  }

  /**
   * Preview deposit amount
   */
  async previewDeposit(assets: BigNumber): Promise<BigNumber> {
    return this.contract.previewDeposit(assets);
  }

  /**
   * Preview withdraw amount
   */
  async previewWithdraw(shares: BigNumber): Promise<BigNumber> {
    return this.contract.previewWithdraw(shares);
  }

  /**
   * Deposit assets into vault
   */
  async deposit(assets: BigNumber, receiver: string): Promise<any> {
    return this.contract.deposit(assets, receiver);
  }

  /**
   * Withdraw assets from vault
   */
  async withdraw(assets: BigNumber, receiver: string, owner: string): Promise<any> {
    return this.contract.withdraw(assets, receiver, owner);
  }

  /**
   * Mint shares by depositing assets
   */
  async mint(shares: BigNumber, receiver: string): Promise<any> {
    return this.contract.mint(shares, receiver);
  }

  /**
   * Burn shares to withdraw assets
   */
  async burn(shares: BigNumber, receiver: string, owner: string): Promise<any> {
    return this.contract.redeem(shares, receiver, owner);
  }

  /**
   * Get APY
   */
  async getAPY(): Promise<BigNumber> {
    return this.contract.getAPY();
  }

  /**
   * Listen for deposit events
   */
  onDeposit(callback: (event: Event) => void): void {
    this.contract.on('Deposit', callback);
  }

  /**
   * Listen for withdrawal events
   */
  onWithdraw(callback: (event: Event) => void): void {
    this.contract.on('Withdraw', callback);
  }

  /**
   * Remove all event listeners
   */
  removeAllListeners(): void {
    this.contract.removeAllListeners();
  }
}

/**
 * Token Module - Balance, approval, and transfer management
 */
export class TokenModule extends EventEmitter {
  private contract: Contract;

  constructor(providerOrSigner: ProviderOrSigner, address: string) {
    super();
    this.contract = new Contract(address, TokenABI, providerOrSigner);
  }

  /**
   * Get token balance
   */
  async balanceOf(account: string): Promise<BigNumber> {
    return this.contract.balanceOf(account);
  }

  /**
   * Get token allowance
   */
  async allowance(owner: string, spender: string): Promise<BigNumber> {
    return this.contract.allowance(owner, spender);
  }

  /**
   * Approve token spending
   */
  async approve(spender: string, amount: BigNumber): Promise<any> {
    return this.contract.approve(spender, amount);
  }

  /**
   * Approve and call
   */
  async approveAndCall(spender: string, amount: BigNumber, data: string): Promise<any> {
    return this.contract.approveAndCall(spender, amount, data);
  }

  /**
   * Transfer tokens
   */
  async transfer(to: string, amount: BigNumber): Promise<any> {
    return this.contract.transfer(to, amount);
  }

  /**
   * Transfer tokens from another account
   */
  async transferFrom(from: string, to: string, amount: BigNumber): Promise<any> {
    return this.contract.transferFrom(from, to, amount);
  }

  /**
   * Get token name
   */
  async name(): Promise<string> {
    return this.contract.name();
  }

  /**
   * Get token symbol
   */
  async symbol(): Promise<string> {
    return this.contract.symbol();
  }

  /**
   * Get token decimals
   */
  async decimals(): Promise<number> {
    return this.contract.decimals();
  }

  /**
   * Get total supply
   */
  async totalSupply(): Promise<BigNumber> {
    return this.contract.totalSupply();
  }

  /**
   * Listen for transfer events
   */
  onTransfer(callback: (event: Event) => void): void {
    this.contract.on('Transfer', callback);
  }

  /**
   * Listen for approval events
   */
  onApproval(callback: (event: Event) => void): void {
    this.contract.on('Approval', callback);
  }

  /**
   * Remove all event listeners
   */
  removeAllListeners(): void {
    this.contract.removeAllListeners();
  }
}

/**
 * Dividend Module - Dividend tracking and claiming
 */
export class DividendModule extends EventEmitter {
  private contract: Contract;

  constructor(providerOrSigner: ProviderOrSigner, address: string) {
    super();
    this.contract = new Contract(address, DividendTrackerABI, providerOrSigner);
  }

  /**
   * Get pending dividends for an account
   */
  async getPendingDividends(account: string): Promise<BigNumber> {
    return this.contract.getPendingDividends(account);
  }

  /**
   * Get all allocations for an account
   */
  async getAllocations(account: string): Promise<DividendAllocation[]> {
    const allocations = await this.contract.getHolderAllocations(account);
    return allocations.map((alloc: any) => ({
      id: alloc.id.toString(),
      amount: alloc.amount,
      claimed: alloc.claimed,
      timestamp: alloc.timestamp.toNumber(),
    }));
  }

  /**
   * Claim dividend for a specific allocation
   */
  async claimDividend(allocationId: string | number): Promise<any> {
    return this.contract.claimDividend(allocationId);
  }

  /**
   * Claim multiple dividends at once
   */
  async claimMultipleDividends(allocationIds: (string | number)[]): Promise<any> {
    return this.contract.claimMultipleDividends(allocationIds);
  }

  /**
   * Claim all pending dividends
   */
  async claimAllDividends(): Promise<any> {
    return this.contract.claimAll();
  }

  /**
   * Get allocation details
   */
  async getAllocationDetails(allocationId: string | number): Promise<any> {
    return this.contract.allocations(allocationId);
  }

  /**
   * Get claimed amount for an account
   */
  async getClaimedAmount(account: string): Promise<BigNumber> {
    return this.contract.getClaimedAmount(account);
  }

  /**
   * Get claim history for an account
   */
  async getClaimHistory(account: string): Promise<any[]> {
    return this.contract.getClaimHistory(account);
  }

  /**
   * Get holder snapshot at a block
   */
  async getHolderSnapshot(account: string, blockNumber: number): Promise<any> {
    return this.contract.getHolderSnapshot(account, blockNumber);
  }

  /**
   * Listen for dividend claimed events
   */
  onDividendClaimed(callback: (event: Event) => void): void {
    this.contract.on('DividendClaimed', callback);
  }

  /**
   * Listen for allocation created events
   */
  onAllocationCreated(callback: (event: Event) => void): void {
    this.contract.on('AllocationCreated', callback);
  }

  /**
   * Remove all event listeners
   */
  removeAllListeners(): void {
    this.contract.removeAllListeners();
  }
}

/**
 * Utility Functions - Formatting, validation, parsing
 */
export class UtilityFunctions {
  /**
   * Format token amount with decimals
   */
  formatTokenAmount(amount: BigNumber, decimals: number = 18, precision: number = 2): string {
    const divisor = BigNumber.from(10).pow(decimals);
    const whole = amount.div(divisor);
    const remainder = amount.mod(divisor);
    const wholeStr = whole.toString();
    const remainderStr = remainder.mul(BigNumber.from(10).pow(precision)).div(divisor).toString().padStart(precision, '0');
    return `${wholeStr}.${remainderStr}`;
  }

  /**
   * Parse token amount with decimals
   */
  parseTokenAmount(amount: string, decimals: number = 18): BigNumber {
    return ethers.utils.parseUnits(amount, decimals);
  }

  /**
   * Validate Ethereum address
   */
  isValidAddress(address: string): boolean {
    return ethers.utils.isAddress(address);
  }

  /**
   * Shorten address for display
   */
  shortenAddress(address: string, chars: number = 4): string {
    if (!this.isValidAddress(address)) return '';
    return `${address.substring(0, chars + 2)}...${address.substring(42 - chars)}`;
  }

  /**
   * Convert percentage (bps) to decimal
   */
  bpsToDecimal(bps: number): number {
    return bps / 10000;
  }

  /**
   * Convert decimal to percentage (bps)
   */
  decimalToBps(decimal: number): number {
    return decimal * 10000;
  }

  /**
   * Format percentage
   */
  formatPercentage(value: number, decimals: number = 2): string {
    return `${(value * 100).toFixed(decimals)}%`;
  }

  /**
   * Get current timestamp
   */
  getCurrentTimestamp(): number {
    return Math.floor(Date.now() / 1000);
  }

  /**
   * Convert block time to date
   */
  blockToDate(blockTimestamp: number): Date {
    return new Date(blockTimestamp * 1000);
  }

  /**
   * Wait for transaction
   */
  async waitForTransaction(txHash: string, provider: any, confirmations: number = 1): Promise<any> {
    return provider.waitForTransaction(txHash, confirmations);
  }
}

export default SVPProtocol;
