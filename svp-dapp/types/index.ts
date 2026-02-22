import { ethers } from 'ethers';

export interface WalletState {
  address: string | null;
  chainId: number | null;
  balance: string;
  isConnecting: boolean;
  isConnected: boolean;
  provider: ethers.providers.Provider | null;
  signer: ethers.Signer | null;
  error: string | null;
}

export interface Proposal {
  id: string;
  title: string;
  description: string;
  proposer: string;
  startBlock: number;
  endBlock: number;
  forVotes: string;
  againstVotes: string;
  abstainVotes: string;
  canceled: boolean;
  executed: boolean;
  eta: number;
}

export interface Vote {
  proposalId: string;
  voter: string;
  votes: string;
  support: 0 | 1 | 2;
  timestamp: number;
}

export interface VaultPosition {
  shares: string;
  assets: string;
  yieldGenerated: string;
  entryTimestamp: number;
  partitions: string[];
}

export interface Dividend {
  allocationId: string;
  token: string;
  amount: string;
  claimed: boolean;
  claimTimestamp: number | null;
  type: 'STANDARD' | 'PERFORMANCE' | 'BONUS' | 'EMERGENCY';
}

export interface Transaction {
  hash: string;
  type: 'deposit' | 'withdraw' | 'vote' | 'claim' | 'delegate';
  status: 'pending' | 'confirmed' | 'failed';
  timestamp: number;
  amount?: string;
}

export type NotificationType = 'success' | 'error' | 'warning' | 'info';
