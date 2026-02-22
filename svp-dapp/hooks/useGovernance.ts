'use client';

import { useEffect } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { ContractManager } from '@/lib/contracts';
import {
  setProposals,
  setUserVotingPower,
  setError as setGovernanceError,
} from '@/store/slices/governanceSlice';
import { RootState } from '@/store';

export function useGovernance() {
  const dispatch = useDispatch();
  const governanceState = useSelector((state: RootState) => state.governance);
  const walletState = useSelector((state: RootState) => state.wallet);

  const fetchVotingPower = async () => {
    if (!walletState.signer || !walletState.address) {
      return;
    }

    try {
      const contractManager = new ContractManager(walletState.signer);
      const votingPower = await contractManager.getVotingPower(walletState.address);
      dispatch(setUserVotingPower(votingPower.toString()));
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to fetch voting power';
      dispatch(setGovernanceError(errorMessage));
    }
  };

  const delegate = async (delegatee: string) => {
    if (!walletState.signer) {
      throw new Error('Wallet not connected');
    }

    try {
      const contractManager = new ContractManager(walletState.signer);
      const tx = await contractManager.delegate(delegatee);
      await tx.wait();
    } catch (err) {
      throw err;
    }
  };

  const castVote = async (proposalId: number, support: number) => {
    if (!walletState.signer) {
      throw new Error('Wallet not connected');
    }

    try {
      const contractManager = new ContractManager(walletState.signer);
      const tx = await contractManager.castVote(proposalId, support);
      await tx.wait();
    } catch (err) {
      throw err;
    }
  };

  useEffect(() => {
    if (walletState.isConnected) {
      fetchVotingPower();
    }
  }, [walletState.isConnected, walletState.address]);

  return {
    ...governanceState,
    fetchVotingPower,
    delegate,
    castVote,
  };
}
