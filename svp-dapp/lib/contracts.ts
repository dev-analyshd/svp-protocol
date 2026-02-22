import { ethers } from 'ethers';

// Minimal ABIs for contract interactions
export const GOVERNANCE_ABI = [
  'function createProposal(string memory description, bytes[] memory calldatas, string[] memory signatures, uint256[] memory values) returns (uint256)',
  'function castVote(uint256 proposalId, uint8 support)',
  'function getProposals() view returns (tuple(uint256 id, address proposer, string description, uint256 startBlock, uint256 endBlock, uint256 forVotes, uint256 againstVotes, bool canceled, bool executed)[])',
  'function getVotingPower(address account) view returns (uint256)',
  'function delegate(address delegatee)',
  'function votingPower(address account, uint256 blockNumber) view returns (uint256)',
];

export const TOKEN_ABI = [
  'function balanceOf(address account) view returns (uint256)',
  'function approve(address spender, uint256 amount) returns (bool)',
  'function transfer(address to, uint256 amount) returns (bool)',
  'function totalSupply() view returns (uint256)',
  'function decimals() view returns (uint8)',
  'function allowance(address owner, address spender) view returns (uint256)',
];

export const VAULT_ABI = [
  'function totalAssets() view returns (uint256)',
  'function totalSupply() view returns (uint256)',
  'function balanceOf(address account) view returns (uint256)',
  'function previewDeposit(uint256 assets) view returns (uint256)',
  'function deposit(uint256 assets, address receiver) returns (uint256)',
  'function withdraw(uint256 assets, address receiver, address owner) returns (uint256)',
  'function convertToShares(uint256 assets) view returns (uint256)',
  'function convertToAssets(uint256 shares) view returns (uint256)',
];

export const DIVIDEND_TRACKER_ABI = [
  'function getPendingDividend(address holder, uint256 allocationId) view returns (uint256)',
  'function getTotalPendingDividends(address holder) view returns (uint256)',
  'function claimDividend(uint256 allocationId) returns (uint256)',
  'function claimMultipleDividends(uint256[] allocationIds) returns (uint256)',
  'function getClaimHistory(address holder) view returns (tuple(address holder, address token, uint256 amount, uint256 allocationId, uint256 claimTime)[])',
  'function getHolderSnapshot(address holder) view returns (tuple(address holder, uint256 dividendBalance, uint256 historicalClaimed, uint256 claimStreak))',
];

export class ContractManager {
  private governance: ethers.Contract;
  private token: ethers.Contract;
  private vault: ethers.Contract;
  private dividendTracker: ethers.Contract;

  constructor(signer: ethers.Signer) {
    const governanceAddress = process.env.NEXT_PUBLIC_GOVERNANCE_ADDRESS;
    const tokenAddress = process.env.NEXT_PUBLIC_TOKEN_ADDRESS;
    const vaultAddress = process.env.NEXT_PUBLIC_VAULT_ADDRESS;
    const dividendTrackerAddress = process.env.NEXT_PUBLIC_DIVIDEND_TRACKER_ADDRESS;

    this.governance = new ethers.Contract(governanceAddress, GOVERNANCE_ABI, signer);
    this.token = new ethers.Contract(tokenAddress, TOKEN_ABI, signer);
    this.vault = new ethers.Contract(vaultAddress, VAULT_ABI, signer);
    this.dividendTracker = new ethers.Contract(
      dividendTrackerAddress,
      DIVIDEND_TRACKER_ABI,
      signer
    );
  }

  // Governance methods
  async createProposal(
    description: string,
    calldatas: string[],
    signatures: string[],
    values: number[]
  ): Promise<ethers.ContractTransaction> {
    return this.governance.createProposal(description, calldatas, signatures, values);
  }

  async castVote(proposalId: number, support: number): Promise<ethers.ContractTransaction> {
    return this.governance.castVote(proposalId, support);
  }

  async getVotingPower(address: string): Promise<ethers.BigNumber> {
    return this.governance.getVotingPower(address);
  }

  async delegate(delegatee: string): Promise<ethers.ContractTransaction> {
    return this.governance.delegate(delegatee);
  }

  // Token methods
  async balanceOf(address: string): Promise<ethers.BigNumber> {
    return this.token.balanceOf(address);
  }

  async approve(spender: string, amount: ethers.BigNumber): Promise<ethers.ContractTransaction> {
    return this.token.approve(spender, amount);
  }

  async transfer(to: string, amount: ethers.BigNumber): Promise<ethers.ContractTransaction> {
    return this.token.transfer(to, amount);
  }

  // Vault methods
  async getTotalAssets(): Promise<ethers.BigNumber> {
    return this.vault.totalAssets();
  }

  async deposit(
    assets: ethers.BigNumber,
    receiver: string
  ): Promise<ethers.ContractTransaction> {
    return this.vault.deposit(assets, receiver);
  }

  async withdraw(
    assets: ethers.BigNumber,
    receiver: string,
    owner: string
  ): Promise<ethers.ContractTransaction> {
    return this.vault.withdraw(assets, receiver, owner);
  }

  async previewDeposit(assets: ethers.BigNumber): Promise<ethers.BigNumber> {
    return this.vault.previewDeposit(assets);
  }

  // Dividend methods
  async getPendingDividends(address: string): Promise<ethers.BigNumber> {
    return this.dividendTracker.getTotalPendingDividends(address);
  }

  async claimDividend(allocationId: number): Promise<ethers.ContractTransaction> {
    return this.dividendTracker.claimDividend(allocationId);
  }

  async claimMultipleDividends(
    allocationIds: number[]
  ): Promise<ethers.ContractTransaction> {
    return this.dividendTracker.claimMultipleDividends(allocationIds);
  }

  async getClaimHistory(address: string) {
    return this.dividendTracker.getClaimHistory(address);
  }

  async getHolderSnapshot(address: string) {
    return this.dividendTracker.getHolderSnapshot(address);
  }
}
