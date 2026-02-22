'use client';

import { useEffect } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { ContractManager } from '@/lib/contracts';
import {
  setDividendData,
  setAllocations,
  claimDividend as claimDividendAction,
  setError: setDividendError,
} from '@/store/slices/dividendSlice';
import { RootState } from '@/store';
import { ethers } from 'ethers';

export function useDividends() {
  const dispatch = useDispatch();
  const dividendState = useSelector((state: RootState) => state.dividend);
  const walletState = useSelector((state: RootState) => state.wallet);

  const fetchDividendData = async () => {
    if (!walletState.signer || !walletState.address) {
      return;
    }

    try {
      const contractManager = new ContractManager(walletState.signer);

      // Fetch pending dividends
      const pendingDividends = await contractManager.getPendingDividends(walletState.address);

      // Fetch claim history
      const claimHistory = await contractManager.getClaimHistory(walletState.address);

      // Fetch holder snapshot
      const snapshot = await contractManager.getHolderSnapshot(walletState.address);

      const claimedTotal = claimHistory.reduce((sum, claim) => {
        return sum.add(claim.amount);
      }, ethers.BigNumber.from(0));

      dispatch(
        setDividendData({
          pendingDividends: pendingDividends.toString(),
          claimedDividends: claimedTotal.toString(),
          totalDistributed: '0', // Would fetch from contract
          performanceScore: snapshot.claimStreak ? 
            Math.min(50 + snapshot.claimStreak * 5, 100) : 0,
        })
      );
    } catch (err) {
      const errorMessage =
        err instanceof Error ? err.message : 'Failed to fetch dividend data';
      dispatch(setDividendError(errorMessage));
    }
  };

  const claimDividend = async (allocationId: number) => {
    if (!walletState.signer) {
      throw new Error('Wallet not connected');
    }

    try {
      const contractManager = new ContractManager(walletState.signer);
      const tx = await contractManager.claimDividend(allocationId);
      await tx.wait();

      dispatch(claimDividendAction(allocationId.toString()));
      await fetchDividendData();
    } catch (err) {
      throw err;
    }
  };

  const claimMultipleDividends = async (allocationIds: number[]) => {
    if (!walletState.signer) {
      throw new Error('Wallet not connected');
    }

    try {
      const contractManager = new ContractManager(walletState.signer);
      const tx = await contractManager.claimMultipleDividends(allocationIds);
      await tx.wait();

      await fetchDividendData();
    } catch (err) {
      throw err;
    }
  };

  useEffect(() => {
    if (walletState.isConnected) {
      fetchDividendData();
    }
  }, [walletState.isConnected, walletState.address]);

  return {
    ...dividendState,
    fetchDividendData,
    claimDividend,
    claimMultipleDividends,
  };
}
