'use client';

import { useEffect } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { ContractManager } from '@/lib/contracts';
import { ethers } from 'ethers';
import {
  setVaultData,
  setUserPosition,
  setError as setVaultError,
} from '@/store/slices/vaultSlice';
import { RootState } from '@/store';

export function useVault() {
  const dispatch = useDispatch();
  const vaultState = useSelector((state: RootState) => state.vault);
  const walletState = useSelector((state: RootState) => state.wallet);

  const fetchVaultData = async () => {
    if (!walletState.signer) {
      return;
    }

    try {
      const contractManager = new ContractManager(walletState.signer);
      const totalAssets = await contractManager.getTotalAssets();
      const sharePrice = ethers.utils.parseEther('1'); // Simplified, should calculate properly

      dispatch(
        setVaultData({
          totalAssets: totalAssets.toString(),
          totalShares: '0', // Would need to fetch from contract
          sharePrice: sharePrice.toString(),
          apy: '8.5', // Would fetch from oracle
          tvl: ethers.utils.formatEther(totalAssets),
        })
      );
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to fetch vault data';
      dispatch(setVaultError(errorMessage));
    }
  };

  const deposit = async (amount: string) => {
    if (!walletState.signer || !walletState.address) {
      throw new Error('Wallet not connected');
    }

    try {
      const contractManager = new ContractManager(walletState.signer);
      const parsedAmount = ethers.utils.parseEther(amount);

      // First approve
      const tokenAddress = process.env.NEXT_PUBLIC_TOKEN_ADDRESS;
      const vaultAddress = process.env.NEXT_PUBLIC_VAULT_ADDRESS;

      await contractManager.approve(vaultAddress, parsedAmount);

      // Then deposit
      const tx = await contractManager.deposit(parsedAmount, walletState.address);
      await tx.wait();

      // Refresh vault data
      await fetchVaultData();
    } catch (err) {
      throw err;
    }
  };

  const withdraw = async (amount: string) => {
    if (!walletState.signer || !walletState.address) {
      throw new Error('Wallet not connected');
    }

    try {
      const contractManager = new ContractManager(walletState.signer);
      const parsedAmount = ethers.utils.parseEther(amount);

      const tx = await contractManager.withdraw(
        parsedAmount,
        walletState.address,
        walletState.address
      );
      await tx.wait();

      // Refresh vault data
      await fetchVaultData();
    } catch (err) {
      throw err;
    }
  };

  useEffect(() => {
    if (walletState.isConnected) {
      fetchVaultData();
    }
  }, [walletState.isConnected]);

  return {
    ...vaultState,
    fetchVaultData,
    deposit,
    withdraw,
  };
}
