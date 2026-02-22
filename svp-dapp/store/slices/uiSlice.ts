import { createSlice, PayloadAction } from '@reduxjs/toolkit';

interface UIState {
  darkMode: boolean;
  sidebarOpen: boolean;
  showTestnetWarning: boolean;
  notificationType: 'success' | 'error' | 'warning' | 'info' | null;
  notificationMessage: string | null;
  isTransactionPending: boolean;
  transactionHash: string | null;
}

const initialState: UIState = {
  darkMode: true,
  sidebarOpen: true,
  showTestnetWarning: true,
  notificationType: null,
  notificationMessage: null,
  isTransactionPending: false,
  transactionHash: null,
};

const uiSlice = createSlice({
  name: 'ui',
  initialState,
  reducers: {
    toggleDarkMode: (state) => {
      state.darkMode = !state.darkMode;
    },
    toggleSidebar: (state) => {
      state.sidebarOpen = !state.sidebarOpen;
    },
    setSidebarOpen: (state, action: PayloadAction<boolean>) => {
      state.sidebarOpen = action.payload;
    },
    showNotification: (
      state,
      action: PayloadAction<{
        type: 'success' | 'error' | 'warning' | 'info';
        message: string;
      }>
    ) => {
      state.notificationType = action.payload.type;
      state.notificationMessage = action.payload.message;
    },
    hideNotification: (state) => {
      state.notificationType = null;
      state.notificationMessage = null;
    },
    setTransactionPending: (
      state,
      action: PayloadAction<{ isPending: boolean; hash?: string }>
    ) => {
      state.isTransactionPending = action.payload.isPending;
      if (action.payload.hash) {
        state.transactionHash = action.payload.hash;
      }
    },
    setTestnetWarning: (state, action: PayloadAction<boolean>) => {
      state.showTestnetWarning = action.payload;
    },
  },
});

export const {
  toggleDarkMode,
  toggleSidebar,
  setSidebarOpen,
  showNotification,
  hideNotification,
  setTransactionPending,
  setTestnetWarning,
} = uiSlice.actions;

export default uiSlice.reducer;
