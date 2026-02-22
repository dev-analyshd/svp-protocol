import { createSlice, PayloadAction } from '@reduxjs/toolkit';

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
  support: 0 | 1 | 2; // 0: against, 1: for, 2: abstain
  timestamp: number;
}

interface GovernanceState {
  proposals: Proposal[];
  votes: Vote[];
  userVotingPower: string;
  delegatee: string | null;
  isLoading: boolean;
  error: string | null;
}

const initialState: GovernanceState = {
  proposals: [],
  votes: [],
  userVotingPower: '0',
  delegatee: null,
  isLoading: false,
  error: null,
};

const governanceSlice = createSlice({
  name: 'governance',
  initialState,
  reducers: {
    setProposals: (state, action: PayloadAction<Proposal[]>) => {
      state.proposals = action.payload;
    },
    addProposal: (state, action: PayloadAction<Proposal>) => {
      state.proposals.unshift(action.payload);
    },
    updateProposal: (state, action: PayloadAction<Proposal>) => {
      const index = state.proposals.findIndex((p) => p.id === action.payload.id);
      if (index >= 0) {
        state.proposals[index] = action.payload;
      }
    },
    setVotes: (state, action: PayloadAction<Vote[]>) => {
      state.votes = action.payload;
    },
    addVote: (state, action: PayloadAction<Vote>) => {
      state.votes.push(action.payload);
    },
    setUserVotingPower: (state, action: PayloadAction<string>) => {
      state.userVotingPower = action.payload;
    },
    setDelegatee: (state, action: PayloadAction<string | null>) => {
      state.delegatee = action.payload;
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
  setProposals,
  addProposal,
  updateProposal,
  setVotes,
  addVote,
  setUserVotingPower,
  setDelegatee,
  setLoading,
  setError,
} = governanceSlice.actions;

export default governanceSlice.reducer;
