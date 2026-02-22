import React, { useState } from 'react';
import { useSelector } from 'react-redux';
import { RootState } from '@/store';
import { useGovernance } from '@/hooks/useGovernance';
import { useWallet } from '@/hooks/useWallet';
import { Container, Card, Badge } from '@/components/common';
import { formatTokenAmount, shortenAddress } from '@/lib/web3';

export default function Governance() {
  const { isConnected } = useWallet();
  const { proposals, userVotingPower, castVote } = useGovernance();
  const [selectedProposal, setSelectedProposal] = useState<string | null>(null);
  const [support, setSupport] = useState<0 | 1 | 2>(1);

  if (!isConnected) {
    return (
      <div className="text-center py-12">
        <p className="text-gray-600 dark:text-gray-400">
          Connect your wallet to participate in governance
        </p>
      </div>
    );
  }

  const handleVote = async () => {
    if (!selectedProposal) return;

    try {
      await castVote(parseInt(selectedProposal), support);
      setSelectedProposal(null);
    } catch (err) {
      console.error('Vote failed:', err);
    }
  };

  return (
    <div className="space-y-6">
      {/* Voting Power Card */}
      <Card>
        <div className="p-6">
          <h2 className="text-xl font-bold mb-2">Your Voting Power</h2>
          <div className="text-3xl font-bold text-primary-600 dark:text-primary-400">
            {formatTokenAmount(userVotingPower, 18, 2)}
          </div>
          <p className="text-sm text-gray-600 dark:text-gray-400 mt-2">
            Based on your token balance and voting history
          </p>
        </div>
      </Card>

      {/* Proposals List */}
      <div>
        <h2 className="text-2xl font-bold mb-4">Active Proposals</h2>
        <div className="space-y-4">
          {proposals.length === 0 ? (
            <Card>
              <div className="p-6 text-center text-gray-600 dark:text-gray-400">
                <p>No proposals yet</p>
              </div>
            </Card>
          ) : (
            proposals.map((proposal) => (
              <Card key={proposal.id} hover>
                <div className="p-6">
                  <div className="flex items-start justify-between mb-4">
                    <div>
                      <h3 className="text-lg font-semibold mb-2">{proposal.title}</h3>
                      <p className="text-sm text-gray-600 dark:text-gray-400">
                        {proposal.description}
                      </p>
                    </div>
                    <Badge
                      variant={proposal.executed ? 'success' : 'info'}
                      size="md"
                    >
                      {proposal.executed ? 'Executed' : 'Active'}
                    </Badge>
                  </div>

                  {/* Voting stats */}
                  <div className="grid grid-cols-3 gap-4 mb-4 py-4 border-y border-gray-200 dark:border-gray-700">
                    <div>
                      <p className="text-sm text-gray-600 dark:text-gray-400">For</p>
                      <p className="text-lg font-semibold text-green-600">
                        {formatTokenAmount(proposal.forVotes, 18, 0)}
                      </p>
                    </div>
                    <div>
                      <p className="text-sm text-gray-600 dark:text-gray-400">Against</p>
                      <p className="text-lg font-semibold text-red-600">
                        {formatTokenAmount(proposal.againstVotes, 18, 0)}
                      </p>
                    </div>
                    <div>
                      <p className="text-sm text-gray-600 dark:text-gray-400">Abstain</p>
                      <p className="text-lg font-semibold text-gray-600">
                        {formatTokenAmount(proposal.abstainVotes, 18, 0)}
                      </p>
                    </div>
                  </div>

                  {/* Vote button */}
                  {!proposal.executed && (
                    <button
                      onClick={() => setSelectedProposal(proposal.id)}
                      className="w-full px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors font-medium"
                    >
                      Vote on Proposal
                    </button>
                  )}
                </div>
              </Card>
            ))
          )}
        </div>
      </div>

      {/* Vote Modal */}
      {selectedProposal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <Card className="max-w-md">
            <div className="p-6">
              <h3 className="text-xl font-bold mb-4">Cast Your Vote</h3>
              <div className="space-y-3 mb-6">
                {[
                  { value: 1, label: 'For', color: 'text-green-600' },
                  { value: 0, label: 'Against', color: 'text-red-600' },
                  { value: 2, label: 'Abstain', color: 'text-gray-600' },
                ].map((option) => (
                  <label key={option.value} className="flex items-center">
                    <input
                      type="radio"
                      name="support"
                      value={option.value}
                      checked={support === option.value}
                      onChange={(e) => setSupport(parseInt(e.target.value) as 0 | 1 | 2)}
                      className="mr-3"
                    />
                    <span className={`font-medium ${option.color}`}>{option.label}</span>
                  </label>
                ))}
              </div>
              <div className="flex gap-3">
                <button
                  onClick={() => setSelectedProposal(null)}
                  className="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors font-medium"
                >
                  Cancel
                </button>
                <button
                  onClick={handleVote}
                  className="flex-1 px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors font-medium"
                >
                  Confirm Vote
                </button>
              </div>
            </div>
          </Card>
        </div>
      )}
    </div>
  );
}
