import React from 'react';
import Link from 'next/link';
import { useSelector, useDispatch } from 'react-redux';
import { useRouter } from 'next/router';
import clsx from 'clsx';
import { RootState } from '@/store';
import { useWallet } from '@/hooks/useWallet';
import {
  toggleDarkMode,
  setSidebarOpen,
  showNotification,
} from '@/store/slices/uiSlice';
import { formatTokenAmount, shortenAddress } from '@/lib/web3';
import { Container, Card } from '@/components/common';

interface LayoutProps {
  children: React.ReactNode;
}

export function Layout({ children }: LayoutProps) {
  const router = useRouter();
  const dispatch = useDispatch();
  const uiState = useSelector((state: RootState) => state.ui);
  const { address, isConnected, balance, connect, disconnect } = useWallet();

  const navItems = [
    { href: '/dashboard', label: 'Dashboard' },
    { href: '/governance', label: 'Governance' },
    { href: '/vault', label: 'Vault' },
    { href: '/dividends', label: 'Dividends' },
    { href: '/analytics', label: 'Analytics' },
  ];

  const handleConnect = async () => {
    try {
      await connect();
      dispatch(
        showNotification({
          type: 'success',
          message: 'Wallet connected successfully',
        })
      );
    } catch (err) {
      dispatch(
        showNotification({
          type: 'error',
          message: err instanceof Error ? err.message : 'Failed to connect wallet',
        })
      );
    }
  };

  return (
    <div className={uiState.darkMode ? 'dark' : ''}>
      <div className="min-h-screen bg-white dark:bg-dark-950">
        {/* Header */}
        <header className="border-b border-gray-200 dark:border-gray-700 bg-white dark:bg-dark-900">
          <Container>
            <div className="flex items-center justify-between h-16">
              <Link href="/">
                <div className="text-2xl font-bold bg-gradient-primary bg-clip-text text-transparent">
                  SVP Protocol
                </div>
              </Link>

              <nav className="hidden md:flex items-center gap-8">
                {navItems.map((item) => (
                  <Link key={item.href} href={item.href}>
                    <span
                      className={clsx(
                        'text-sm font-medium transition-colors',
                        router.pathname === item.href
                          ? 'text-primary-600 dark:text-primary-400'
                          : 'text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-200'
                      )}
                    >
                      {item.label}
                    </span>
                  </Link>
                ))}
              </nav>

              <div className="flex items-center gap-4">
                {/* Dark mode toggle */}
                <button
                  onClick={() => dispatch(toggleDarkMode())}
                  className="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-800"
                  aria-label="Toggle dark mode"
                >
                  {uiState.darkMode ? '☀️' : '🌙'}
                </button>

                {/* Wallet connection */}
                {isConnected ? (
                  <div className="flex items-center gap-2">
                    <Card className="px-4 py-2">
                      <div className="text-sm font-medium text-gray-600 dark:text-gray-400">
                        {shortenAddress(address || '', 6)}
                      </div>
                      <div className="text-xs text-gray-500 dark:text-gray-500">
                        {formatTokenAmount(balance, 18, 2)} ETH
                      </div>
                    </Card>
                    <button
                      onClick={disconnect}
                      className="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors text-sm font-medium"
                    >
                      Disconnect
                    </button>
                  </div>
                ) : (
                  <button
                    onClick={handleConnect}
                    className="px-4 py-2 bg-gradient-primary text-white rounded-lg hover:opacity-90 transition-opacity font-medium"
                  >
                    Connect Wallet
                  </button>
                )}
              </div>
            </div>
          </Container>
        </header>

        {/* Main content */}
        <main className="py-8">
          <Container>{children}</Container>
        </main>

        {/* Footer */}
        <footer className="border-t border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-dark-900 mt-12">
          <Container>
            <div className="py-8 text-center text-sm text-gray-600 dark:text-gray-400">
              <p>© 2026 SVP Protocol. All rights reserved.</p>
            </div>
          </Container>
        </footer>

        {/* Notifications */}
        {uiState.notificationMessage && (
          <Notification
            type={uiState.notificationType || 'info'}
            message={uiState.notificationMessage}
          />
        )}
      </div>
    </div>
  );
}

interface NotificationProps {
  type: 'success' | 'error' | 'warning' | 'info';
  message: string;
}

function Notification({ type, message }: NotificationProps) {
  const colors = {
    success: 'bg-success-500',
    error: 'bg-error-500',
    warning: 'bg-warning-500',
    info: 'bg-primary-500',
  };

  return (
    <div className={clsx('fixed bottom-4 right-4 px-4 py-3 rounded-lg text-white', colors[type])}>
      {message}
    </div>
  );
}
