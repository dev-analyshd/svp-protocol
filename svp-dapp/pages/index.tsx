import React from 'react';
import Link from 'next/link';
import { Container, Card } from '@/components/common';

export default function Home() {
  const features = [
    {
      title: 'Governance',
      description: 'Participate in protocol governance with value-weighted voting',
      link: '/governance',
      icon: '🏛️',
    },
    {
      title: 'Vault Management',
      description: 'Deposit assets and earn optimized yields',
      link: '/vault',
      icon: '💰',
    },
    {
      title: 'Dividend Distribution',
      description: 'Claim performance-based dividends and rewards',
      link: '/dividends',
      icon: '🎁',
    },
    {
      title: 'Analytics Dashboard',
      description: 'Monitor protocol metrics and your portfolio performance',
      link: '/analytics',
      icon: '📊',
    },
  ];

  return (
    <div className="space-y-12">
      {/* Hero Section */}
      <div className="text-center py-12 md:py-20">
        <h1 className="text-5xl md:text-6xl font-bold mb-6 bg-gradient-primary bg-clip-text text-transparent">
          SVP Protocol
        </h1>
        <p className="text-xl md:text-2xl text-gray-600 dark:text-gray-400 mb-8 max-w-2xl mx-auto">
          Secure, transparent, and efficient asset tokenization, governance, and dividend distribution
        </p>
        <div className="flex gap-4 justify-center">
          <Link href="/dashboard">
            <button className="px-8 py-3 bg-gradient-primary text-white rounded-lg hover:opacity-90 transition-opacity font-semibold">
              Open dApp
            </button>
          </Link>
          <a href="https://github.com/svp-protocol" target="_blank" rel="noopener noreferrer">
            <button className="px-8 py-3 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors font-semibold">
              View on GitHub
            </button>
          </a>
        </div>
      </div>

      {/* Features Grid */}
      <div>
        <h2 className="text-3xl font-bold text-center mb-12">Core Features</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {features.map((feature) => (
            <Link key={feature.link} href={feature.link}>
              <Card hover className="cursor-pointer">
                <div className="p-8">
                  <div className="text-4xl mb-4">{feature.icon}</div>
                  <h3 className="text-xl font-bold mb-2">{feature.title}</h3>
                  <p className="text-gray-600 dark:text-gray-400">
                    {feature.description}
                  </p>
                  <div className="mt-4 text-primary-600 dark:text-primary-400 font-semibold">
                    Explore →
                  </div>
                </div>
              </Card>
            </Link>
          ))}
        </div>
      </div>

      {/* Stats Section */}
      <Card>
        <div className="p-12">
          <h2 className="text-3xl font-bold mb-8 text-center">Protocol Statistics</h2>
          <div className="grid grid-cols-1 md:grid-cols-4 gap-8 text-center">
            <div>
              <div className="text-4xl font-bold text-primary-600 dark:text-primary-400">
                $125M+
              </div>
              <p className="text-gray-600 dark:text-gray-400 mt-2">Total Value Locked</p>
            </div>
            <div>
              <div className="text-4xl font-bold text-primary-600 dark:text-primary-400">
                8.5%
              </div>
              <p className="text-gray-600 dark:text-gray-400 mt-2">Average APY</p>
            </div>
            <div>
              <div className="text-4xl font-bold text-primary-600 dark:text-primary-400">
                12.3k+
              </div>
              <p className="text-gray-600 dark:text-gray-400 mt-2">Active Participants</p>
            </div>
            <div>
              <div className="text-4xl font-bold text-primary-600 dark:text-primary-400">
                256+
              </div>
              <p className="text-gray-600 dark:text-gray-400 mt-2">Governance Proposals</p>
            </div>
          </div>
        </div>
      </Card>

      {/* How It Works */}
      <div>
        <h2 className="text-3xl font-bold text-center mb-12">How It Works</h2>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {[
            {
              step: '1',
              title: 'Connect Wallet',
              description: 'Connect your MetaMask or Web3 wallet to get started',
            },
            {
              step: '2',
              title: 'Deposit Assets',
              description: 'Deposit your assets into the vault to start earning yield',
            },
            {
              step: '3',
              title: 'Earn & Govern',
              description: 'Earn passive income and participate in protocol governance',
            },
          ].map((item) => (
            <Card key={item.step}>
              <div className="p-6">
                <div className="w-12 h-12 rounded-full bg-gradient-primary text-white flex items-center justify-center font-bold text-lg mb-4">
                  {item.step}
                </div>
                <h3 className="text-xl font-bold mb-2">{item.title}</h3>
                <p className="text-gray-600 dark:text-gray-400">{item.description}</p>
              </div>
            </Card>
          ))}
        </div>
      </div>

      {/* CTA Section */}
      <div className="text-center py-12 bg-gradient-primary/10 rounded-lg">
        <h2 className="text-3xl font-bold mb-4">Ready to Get Started?</h2>
        <p className="text-gray-600 dark:text-gray-400 mb-8">
          Join thousands of users earning yield through SVP Protocol
        </p>
        <Link href="/dashboard">
          <button className="px-8 py-3 bg-gradient-primary text-white rounded-lg hover:opacity-90 transition-opacity font-semibold">
            Launch dApp
          </button>
        </Link>
      </div>
    </div>
  );
}
