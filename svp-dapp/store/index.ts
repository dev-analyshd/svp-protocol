import { configureStore } from '@reduxjs/toolkit';
import walletReducer from './slices/walletSlice';
import governanceReducer from './slices/governanceSlice';
import vaultReducer from './slices/vaultSlice';
import dividendReducer from './slices/dividendSlice';
import uiReducer from './slices/uiSlice';

export const store = configureStore({
  reducer: {
    wallet: walletReducer,
    governance: governanceReducer,
    vault: vaultReducer,
    dividend: dividendReducer,
    ui: uiReducer,
  },
  middleware: (getDefaultMiddleware) =>
    getDefaultMiddleware({
      serializableCheck: {
        ignoredActions: ['wallet/setProvider', 'wallet/setSigner'],
        ignoredPaths: ['wallet.provider', 'wallet.signer'],
      },
    }),
});

export type RootState = ReturnType<typeof store.getState>;
export type AppDispatch = typeof store.dispatch;
