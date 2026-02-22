import { createSlice, PayloadAction } from '@reduxjs/toolkit';

export interface VaultPosition {
  shares: string;
  assets: string;
  yieldGenerated: string;
  entryTimestamp: number;
  partitions: string[];
}

interface VaultState {
  totalAssets: string;
  totalShares: string;
  userPosition: VaultPosition | null;
  sharePrice: string;
  apy: string;
  tvl: string;
  isLoading: boolean;
  error: string | null;
}

const initialState: VaultState = {
  totalAssets: '0',
  totalShares: '0',
  userPosition: null,
  sharePrice: '0',
  apy: '0',
  tvl: '0',
  isLoading: false,
  error: null,
};

const vaultSlice = createSlice({
  name: 'vault',
  initialState,
  reducers: {
    setVaultData: (
      state,
      action: PayloadAction<{
        totalAssets: string;
        totalShares: string;
        sharePrice: string;
        apy: string;
        tvl: string;
      }>
    ) => {
      state.totalAssets = action.payload.totalAssets;
      state.totalShares = action.payload.totalShares;
      state.sharePrice = action.payload.sharePrice;
      state.apy = action.payload.apy;
      state.tvl = action.payload.tvl;
    },
    setUserPosition: (state, action: PayloadAction<VaultPosition | null>) => {
      state.userPosition = action.payload;
    },
    updateUserPosition: (state, action: PayloadAction<Partial<VaultPosition>>) => {
      if (state.userPosition) {
        Object.assign(state.userPosition, action.payload);
      }
    },
    setLoading: (state, action: PayloadAction<boolean>) => {
      state.isLoading = action.payload;
    },
    setError: (state, action: PayloadAction<string | null>) => {
      state.error = action.payload;
    },
  },
});

export const {
  setVaultData,
  setUserPosition,
  updateUserPosition,
  setLoading,
  setError,
} = vaultSlice.actions;

export default vaultSlice.reducer;
