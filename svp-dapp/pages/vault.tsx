import React, { useState } from 'react';
import { useVault } from '@/hooks/useVault';
import { useWallet } from '@/hooks/useWallet';
import { Container, Card, Badge, LoadingSkeleton } from '@/components/common';
import { useSelector } from 'react-redux';
import { RootState } from '@/store';

const VaultPage: React.FC = () => {
  const { address, isConnected } = useWallet();
  const {
    vaultData,
    deposit,
    withdraw,
    loading,
    error,
    approveToken,
    approving,
    depositPending,
    withdrawPending,
  } = useVault();
  const [depositAmount, setDepositAmount] = useState('');
  const [withdrawAmount, setWithdrawAmount] = useState('');
  const [depositError, setDepositError] = useState('');
  const [withdrawError, setWithdrawError] = useState('');

  const vaultState = useSelector((state: RootState) => state.vault);

  const handleDeposit = async (e: React.FormEvent) => {
    e.preventDefault();
    setDepositError('');
    if (!depositAmount || isNaN(Number(depositAmount)) || Number(depositAmount) <= 0) {
      setDepositError('Enter a valid amount');
      return;
    }
    try {
      await deposit(depositAmount);
      setDepositAmount('');
    } catch (err: any) {
      setDepositError(err.message || 'Deposit failed');
    }
  };

  const handleWithdraw = async (e: React.FormEvent) => {
    e.preventDefault();
    setWithdrawError('');
    if (!withdrawAmount || isNaN(Number(withdrawAmount)) || Number(withdrawAmount) <= 0) {
      setWithdrawError('Enter a valid amount');
      return;
    }
    try {
      await withdraw(withdrawAmount);
      setWithdrawAmount('');
    } catch (err: any) {
      setWithdrawError(err.message || 'Withdraw failed');
    }
  };

  return (
    <Container size="lg">
      <h1 className="text-3xl font-bold mb-6">Vault Management</h1>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <Card>
          <h2 className="text-xl font-semibold mb-4">Deposit Assets</h2>
          <form onSubmit={handleDeposit} className="space-y-4">
            <input
              type="number"
              min="0"
              step="any"
              value={depositAmount}
              onChange={e => setDepositAmount(e.target.value)}
              className="w-full px-3 py-2 border rounded focus:outline-none focus:ring"
              placeholder="Amount to deposit"
              disabled={depositPending || approving}
            />
            {depositError && <div className="text-red-500 text-sm">{depositError}</div>}
            <button
              type="submit"
              className="w-full bg-primary text-white py-2 rounded font-semibold hover:bg-primary-dark transition"
              disabled={depositPending || approving}
            >
              {approving ? 'Approving...' : depositPending ? 'Depositing...' : 'Deposit'}
            </button>
          </form>
        </Card>
        <Card>
          <h2 className="text-xl font-semibold mb-4">Withdraw Assets</h2>
          <form onSubmit={handleWithdraw} className="space-y-4">
            <input
              type="number"
              min="0"
              step="any"
              value={withdrawAmount}
              onChange={e => setWithdrawAmount(e.target.value)}
              className="w-full px-3 py-2 border rounded focus:outline-none focus:ring"
              placeholder="Amount to withdraw"
              disabled={withdrawPending}
            />
            {withdrawError && <div className="text-red-500 text-sm">{withdrawError}</div>}
            <button
              type="submit"
              className="w-full bg-secondary text-white py-2 rounded font-semibold hover:bg-secondary-dark transition"
              disabled={withdrawPending}
            >
              {withdrawPending ? 'Withdrawing...' : 'Withdraw'}
            </button>
          </form>
        </Card>
      </div>
      <div className="mt-8">
        <Card>
          <h2 className="text-xl font-semibold mb-4">Your Vault Position</h2>
          {loading ? (
            <LoadingSkeleton height={80} />
          ) : error ? (
            <div className="text-red-500">{error}</div>
          ) : (
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              <div>
                <div className="text-sm text-gray-500">Total Assets</div>
                <div className="text-lg font-bold">{vaultData.totalAssets}</div>
              </div>
              <div>
                <div className="text-sm text-gray-500">Your Shares</div>
                <div className="text-lg font-bold">{vaultData.userShares}</div>
              </div>
              <div>
                <div className="text-sm text-gray-500">APY</div>
                <div className="text-lg font-bold">{vaultData.apy}%</div>
              </div>
              <div>
                <div className="text-sm text-gray-500">Share Price</div>
                <div className="text-lg font-bold">{vaultData.sharePrice}</div>
              </div>
            </div>
          )}
        </Card>
      </div>
    </Container>
  );
};

export default VaultPage;
