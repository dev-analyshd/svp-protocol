import { createSlice, PayloadAction } from '@reduxjs/toolkit';

export interface Dividend {
  allocationId: string;
  token: string;
  amount: string;
  claimed: boolean;
  claimTimestamp: number | null;
  type: 'STANDARD' | 'PERFORMANCE' | 'BONUS' | 'EMERGENCY';
}

interface DividendState {
  pendingDividends: string;
  claimedDividends: string;
  allocations: Dividend[];
  claimHistory: Dividend[];
  totalDistributed: string;
  performanceScore: number;
  isLoading: boolean;
  error: string | null;
}

const initialState: DividendState = {
  pendingDividends: '0',
  claimedDividends: '0',
  allocations: [],
  claimHistory: [],
  totalDistributed: '0',
  performanceScore: 0,
  isLoading: false,
  error: null,
};

const dividendSlice = createSlice({
  name: 'dividend',
  initialState,
  reducers: {
    setDividendData: (
      state,
      action: PayloadAction<{
        pendingDividends: string;
        claimedDividends: string;
        totalDistributed: string;
        performanceScore: number;
      }>
    ) => {
      state.pendingDividends = action.payload.pendingDividends;
      state.claimedDividends = action.payload.claimedDividends;
      state.totalDistributed = action.payload.totalDistributed;
      state.performanceScore = action.payload.performanceScore;
    },
    setAllocations: (state, action: PayloadAction<Dividend[]>) => {
      state.allocations = action.payload;
    },
    addAllocation: (state, action: PayloadAction<Dividend>) => {
      state.allocations.push(action.payload);
    },
    claimDividend: (state, action: PayloadAction<string>) => {
      const allocation = state.allocations.find((a) => a.allocationId === action.payload);
      if (allocation) {
        allocation.claimed = true;
        allocation.claimTimestamp = Math.floor(Date.now() / 1000);
        state.claimHistory.push(allocation);
        state.pendingDividends = (
          BigInt(state.pendingDividends) - BigInt(allocation.amount)
        ).toString();
        state.claimedDividends = (
          BigInt(state.claimedDividends) + BigInt(allocation.amount)
        ).toString();
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
  setDividendData,
  setAllocations,
  addAllocation,
  claimDividend,
  setLoading,
  setError,
} = dividendSlice.actions;

export default dividendSlice.reducer;
