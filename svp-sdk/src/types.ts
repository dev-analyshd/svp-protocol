import { BigNumber, Contract, providers } from 'ethers';

export interface SVPConfig {
  governanceAddress: string;
  vaultAddress: string;
  tokenAddress: string;
  dividendTrackerAddress: string;
  chainId?: number;
}

export interface Proposal {
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

export interface VaultPosition {
  shares: BigNumber;
  assets: BigNumber;
  apy: number;
}

export interface DividendAllocation {
  id: string;
  amount: BigNumber;
  claimed: boolean;
  timestamp: number;
}

export type ProviderOrSigner = providers.Provider | providers.JsonRpcSigner;
