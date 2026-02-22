'use client';

import { useEffect, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { ethers } from 'ethers';
import {
  setWalletConnection,
  setConnecting,
  setBalance,
  setError,
  disconnect,
} from '@/store/slices/walletSlice';
import { connectWallet, getBalance } from '@/lib/web3';
import { RootState } from '@/store';

export function useWallet() {
  const dispatch = useDispatch();
  const walletState = useSelector((state: RootState) => state.wallet);
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  const connect = async () => {
    if (!mounted) return;

    dispatch(setConnecting(true));
    try {
      const { address, provider, signer, chainId } = await connectWallet();
      const balance = await getBalance(address, provider);

      dispatch(
        setWalletConnection({
          address,
          chainId,
          balance,
          provider,
          signer,
        })
      );

      // Set up listener for account changes
      if (window.ethereum) {
        window.ethereum.on('accountsChanged', (accounts: string[]) => {
          if (accounts.length === 0) {
            dispatch(disconnect());
          } else {
            handleAccountChange(accounts[0]);
          }
        });

        window.ethereum.on('chainChanged', () => {
          window.location.reload();
        });
      }
    } catch (err) {
      const errorMessage =
        err instanceof Error ? err.message : 'Failed to connect wallet';
      dispatch(setError(errorMessage));
    } finally {
      dispatch(setConnecting(false));
    }
  };

  const handleAccountChange = async (newAddress: string) => {
    const provider = walletState.provider;
    if (provider) {
      const balance = await getBalance(newAddress, provider);
      dispatch(
        setWalletConnection({
          address: newAddress,
          balance,
        })
      );
    }
  };

  const refreshBalance = async () => {
    if (walletState.address && walletState.provider) {
      const balance = await getBalance(walletState.address, walletState.provider);
      dispatch(setBalance(balance));
    }
  };

  const handleDisconnect = () => {
    dispatch(disconnect());
  };

  return {
    ...walletState,
    connect,
    disconnect: handleDisconnect,
    refreshBalance,
  };
}
