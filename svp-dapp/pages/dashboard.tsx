import React from 'react';
import { useSelector } from 'react-redux';
import { RootState } from '@/store';
import { useWallet } from '@/hooks/useWallet';
import { useVault } from '@/hooks/useVault';
import { useDividends } from '@/hooks/useDividends';
import { Container, Card, Badge, LoadingSkeleton } from '@/components/common';
import { formatTokenAmount } from '@/lib/web3';

export default function Dashboard() {
  const walletState = useSelector((state: RootState) => state.wallet);
  const vaultState = useSelector((state: RootState) => state.vault);
  const dividendState = useSelector((state: RootState) => state.dividend);
  const governanceState = useSelector((state: RootState) => state.governance);

  const { isConnected } = useWallet();
  const { fetchVaultData } = useVault();
  const { fetchDividendData } = useDividends();

  if (!isConnected) {
    return (
      <div className="space-y-8">
        <div className="text-center py-12">
          <h1 className="text-4xl font-bold mb-4">Welcome to SVP Protocol</h1>
          <p className="text-xl text-gray-600 dark:text-gray-400 mb-8">
            Connect your wallet to manage governance, vault, and dividends
          </p>
          <p className="text-gray-500 dark:text-gray-500">
            Click "Connect Wallet" in the top-right corner to begin
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
        {/* Portfolio Value */}
        <Card>
          <div className="p-6">
            <h3 className="text-sm font-medium text-gray-600 dark:text-gray-400 mb-2">
              Portfolio Value
            </h3>
            <div className="text-2xl font-bold mb-2">
              {vaultState.isLoading ? (
                <LoadingSkeleton height="h-8" />
              ) : (
                `$${formatTokenAmount(vaultState.userPosition?.assets || '0', 18, 2)}`
              )}
            </div>
            <Badge variant="success" size="sm">
              +{vaultState.apy}% APY
            </Badge>
          </div>
        </Card>

        {/* Pending Dividends */}
        <Card>
          <div className="p-6">
            <h3 className="text-sm font-medium text-gray-600 dark:text-gray-400 mb-2">
              Pending Dividends
            </h3>
            <div className="text-2xl font-bold mb-2">
              {dividendState.isLoading ? (
                <LoadingSkeleton height="h-8" />
              ) : (
                `$${formatTokenAmount(dividendState.pendingDividends, 18, 2)}`
              )}
            </div>
            <Badge variant="warning" size="sm">
              {dividendState.allocations.filter((a) => !a.claimed).length} unclaimed
            </Badge>
          </div>
        </Card>

        {/* Voting Power */}
        <Card>
          <div className="p-6">
            <h3 className="text-sm font-medium text-gray-600 dark:text-gray-400 mb-2">
              Voting Power
            </h3>
            <div className="text-2xl font-bold mb-2">
              {formatTokenAmount(governanceState.userVotingPower, 18, 0)}
            </div>
            <Badge variant="info" size="sm">
              {governanceState.proposals.length} active proposals
            </Badge>
          </div>
        </Card>

        {/* Performance Score */}
        <Card>
          <div className="p-6">
            <h3 className="text-sm font-medium text-gray-600 dark:text-gray-400 mb-2">
              Performance Score
            </h3>
            <div className="text-2xl font-bold mb-2">
              {dividendState.performanceScore}/100
            </div>
            <div className="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-2">
              <div
                className="bg-gradient-primary h-2 rounded-full"
                style={{ width: `${dividendState.performanceScore}%` }}
              />
            </div>
          </div>
        </Card>
      </div>

      {/* Recent Activity */}
      <Card>
        <div className="p-6 border-b border-gray-200 dark:border-gray-700">
          <h2 className="text-xl font-bold">Recent Activity</h2>
        </div>
        <div className="p-6">
          <div className="text-center text-gray-500 dark:text-gray-400 py-8">
            <p>No recent activity yet</p>
            <p className="text-sm mt-2">
              Your transactions will appear here
            </p>
          </div>
        </div>
      </Card>

      {/* Quick Actions */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <Card hover>
          <div className="p-6 text-center">
            <h3 className="text-lg font-semibold mb-2">Deposit to Vault</h3>
            <p className="text-sm text-gray-600 dark:text-gray-400 mb-4">
              Start earning yield on your assets
            </p>
            <button className="w-full px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors font-medium">
              Deposit
            </button>
          </div>
        </Card>

        <Card hover>
          <div className="p-6 text-center">
            <h3 className="text-lg font-semibold mb-2">Claim Dividends</h3>
            <p className="text-sm text-gray-600 dark:text-gray-400 mb-4">
              Claim your pending dividend allocations
            </p>
            <button
              className="w-full px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors font-medium disabled:opacity-50"
              disabled={dividendState.pendingDividends === '0'}
            >
              Claim
            </button>
          </div>
        </Card>

        <Card hover>
          <div className="p-6 text-center">
            <h3 className="text-lg font-semibold mb-2">Vote on Proposals</h3>
            <p className="text-sm text-gray-600 dark:text-gray-400 mb-4">
              Participate in protocol governance
            </p>
            <button className="w-full px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors font-medium">
              Vote
            </button>
          </div>
        </Card>
      </div>
    </div>
  );
}
