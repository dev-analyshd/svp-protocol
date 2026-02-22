import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import { ethers } from 'ethers';

interface WalletState {
  address: string | null;
  chainId: number | null;
  balance: string;
  isConnecting: boolean;
  isConnected: boolean;
  provider: ethers.providers.Provider | null;
  signer: ethers.Signer | null;
  error: string | null;
}

const initialState: WalletState = {
  address: null,
  chainId: null,
  balance: '0',
  isConnecting: false,
  isConnected: false,
  provider: null,
  signer: null,
  error: null,
};

const walletSlice = createSlice({
  name: 'wallet',
  initialState,
  reducers: {
    setWalletConnection: (state, action: PayloadAction<Partial<WalletState>>) => {
      Object.assign(state, action.payload);
      state.isConnected = !!action.payload.address;
    },
    setConnecting: (state, action: PayloadAction<boolean>) => {
      state.isConnecting = action.payload;
    },
    setBalance: (state, action: PayloadAction<string>) => {
      state.balance = action.payload;
    },
    setError: (state, action: PayloadAction<string | null>) => {
      state.error = action.payload;
    },
    disconnect: (state) => {
      state.address = null;
      state.chainId = null;
      state.balance = '0';
      state.isConnected = false;
      state.provider = null;
      state.signer = null;
      state.error = null;
    },
  },
});

export const {
  setWalletConnection,
  setConnecting,
  setBalance,
  setError,
  disconnect,
} = walletSlice.actions;

export default walletSlice.reducer;
