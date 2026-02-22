import { ethers } from 'ethers';

const RPC_URL = process.env.NEXT_PUBLIC_RPC_URL || 'http://localhost:8545';
const CHAIN_ID = parseInt(process.env.NEXT_PUBLIC_CHAIN_ID || '1', 10);

let provider: ethers.providers.Provider | null = null;

export function getProvider(): ethers.providers.Provider {
  if (!provider) {
    provider = new ethers.providers.JsonRpcProvider(RPC_URL, CHAIN_ID);
  }
  return provider;
}

export async function connectWallet(): Promise<{
  address: string;
  provider: ethers.providers.Web3Provider;
  signer: ethers.Signer;
  chainId: number;
}> {
  if (!window.ethereum) {
    throw new Error('MetaMask not detected. Please install MetaMask.');
  }

  const accounts = await window.ethereum.request({
    method: 'eth_requestAccounts',
  });

  const address = accounts[0];
  const provider = new ethers.providers.Web3Provider(window.ethereum);
  const signer = provider.getSigner();
  const chainId = (await provider.getNetwork()).chainId;

  return {
    address,
    provider,
    signer,
    chainId,
  };
}

export async function getBalance(
  address: string,
  provider: ethers.providers.Provider
): Promise<string> {
  const balance = await provider.getBalance(address);
  return ethers.utils.formatEther(balance);
}

export function isValidAddress(address: string): boolean {
  return ethers.utils.isAddress(address);
}

export function shortenAddress(address: string, chars = 4): string {
  if (!isValidAddress(address)) {
    return '';
  }
  return `${address.substring(0, chars + 2)}...${address.substring(42 - chars)}`;
}

export function formatTokenAmount(
  amount: string | ethers.BigNumber,
  decimals = 18,
  precision = 4
): string {
  const formatted = ethers.utils.formatUnits(amount, decimals);
  const num = parseFloat(formatted);
  return num.toLocaleString('en-US', {
    minimumFractionDigits: 0,
    maximumFractionDigits: precision,
  });
}

export function parseTokenAmount(amount: string, decimals = 18): ethers.BigNumber {
  return ethers.utils.parseUnits(amount, decimals);
}
