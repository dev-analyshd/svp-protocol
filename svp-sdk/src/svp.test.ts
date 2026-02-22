/**
 * SVP Protocol SDK - Unit and Integration Tests
 */

import { SVPProtocol, GovernanceModule, VaultModule, TokenModule, DividendModule, UtilityFunctions } from '../svp';
import { ethers, BigNumber } from 'ethers';

describe('SVPProtocol SDK', () => {
  let svp: SVPProtocol;

  // Mock config
  const mockConfig = {
    governanceAddress: '0x0000000000000000000000000000000000000001',
    vaultAddress: '0x0000000000000000000000000000000000000002',
    tokenAddress: '0x0000000000000000000000000000000000000003',
    dividendTrackerAddress: '0x0000000000000000000000000000000000000004',
  };

  beforeEach(() => {
    // Create mock provider
    const mockProvider = {
      // mock methods
    } as any;

    svp = new SVPProtocol(mockProvider, mockConfig);
  });

  describe('Governance Module', () => {
    test('Should initialize governance module', () => {
      expect(svp.governance).toBeInstanceOf(GovernanceModule);
    });

    test('Should have voting methods', () => {
      expect(typeof svp.governance.getVotingPower).toBe('function');
      expect(typeof svp.governance.castVote).toBe('function');
      expect(typeof svp.governance.delegate).toBe('function');
    });

    test('Should have proposal methods', () => {
      expect(typeof svp.governance.getProposals).toBe('function');
      expect(typeof svp.governance.getProposal).toBe('function');
      expect(typeof svp.governance.createProposal).toBe('function');
    });

    test('Should have event listeners', () => {
      expect(typeof svp.governance.onProposalCreated).toBe('function');
      expect(typeof svp.governance.onVoteCast).toBe('function');
    });
  });

  describe('Vault Module', () => {
    test('Should initialize vault module', () => {
      expect(svp.vault).toBeInstanceOf(VaultModule);
    });

    test('Should have deposit/withdraw methods', () => {
      expect(typeof svp.vault.deposit).toBe('function');
      expect(typeof svp.vault.withdraw).toBe('function');
      expect(typeof svp.vault.mint).toBe('function');
      expect(typeof svp.vault.burn).toBe('function');
    });

    test('Should have position methods', () => {
      expect(typeof svp.vault.getPosition).toBe('function');
      expect(typeof svp.vault.getTotalAssets).toBe('function');
      expect(typeof svp.vault.getTotalShares).toBe('function');
    });

    test('Should have preview methods', () => {
      expect(typeof svp.vault.previewDeposit).toBe('function');
      expect(typeof svp.vault.previewWithdraw).toBe('function');
    });
  });

  describe('Token Module', () => {
    test('Should initialize token module', () => {
      expect(svp.token).toBeInstanceOf(TokenModule);
    });

    test('Should have balance methods', () => {
      expect(typeof svp.token.balanceOf).toBe('function');
      expect(typeof svp.token.totalSupply).toBe('function');
    });

    test('Should have approval methods', () => {
      expect(typeof svp.token.approve).toBe('function');
      expect(typeof svp.token.allowance).toBe('function');
    });

    test('Should have transfer methods', () => {
      expect(typeof svp.token.transfer).toBe('function');
      expect(typeof svp.token.transferFrom).toBe('function');
    });

    test('Should have info methods', () => {
      expect(typeof svp.token.name).toBe('function');
      expect(typeof svp.token.symbol).toBe('function');
      expect(typeof svp.token.decimals).toBe('function');
    });
  });

  describe('Dividend Module', () => {
    test('Should initialize dividend module', () => {
      expect(svp.dividend).toBeInstanceOf(DividendModule);
    });

    test('Should have dividend methods', () => {
      expect(typeof svp.dividend.getPendingDividends).toBe('function');
      expect(typeof svp.dividend.getAllocations).toBe('function');
      expect(typeof svp.dividend.claimDividend).toBe('function');
      expect(typeof svp.dividend.claimMultipleDividends).toBe('function');
    });

    test('Should have history methods', () => {
      expect(typeof svp.dividend.getClaimHistory).toBe('function');
      expect(typeof svp.dividend.getClaimedAmount).toBe('function');
    });

    test('Should have event listeners', () => {
      expect(typeof svp.dividend.onDividendClaimed).toBe('function');
      expect(typeof svp.dividend.onAllocationCreated).toBe('function');
    });
  });

  describe('Utility Functions', () => {
    let utils: UtilityFunctions;

    beforeEach(() => {
      utils = new UtilityFunctions();
    });

    test('Should format token amount', () => {
      const amount = BigNumber.from('1000000000000000000'); // 1 token with 18 decimals
      const formatted = utils.formatTokenAmount(amount, 18, 2);
      expect(formatted).toBe('1.00');
    });

    test('Should parse token amount', () => {
      const parsed = utils.parseTokenAmount('100.5', 18);
      expect(parsed).toEqual(BigNumber.from('100500000000000000000'));
    });

    test('Should validate Ethereum address', () => {
      expect(utils.isValidAddress('0x0000000000000000000000000000000000000001')).toBe(true);
      expect(utils.isValidAddress('invalid')).toBe(false);
    });

    test('Should shorten address', () => {
      const shortened = utils.shortenAddress('0x1234567890abcdef1234567890abcdef12345678');
      expect(shortened).toBe('0x1234...5678');
    });

    test('Should convert bps to decimal', () => {
      expect(utils.bpsToDecimal(1000)).toBe(0.1);
      expect(utils.bpsToDecimal(5000)).toBe(0.5);
    });

    test('Should convert decimal to bps', () => {
      expect(utils.decimalToBps(0.1)).toBe(1000);
      expect(utils.decimalToBps(0.5)).toBe(5000);
    });

    test('Should format percentage', () => {
      expect(utils.formatPercentage(0.1234, 2)).toBe('12.34%');
      expect(utils.formatPercentage(0.5, 0)).toBe('50%');
    });

    test('Should get current timestamp', () => {
      const timestamp = utils.getCurrentTimestamp();
      expect(timestamp).toBeGreaterThan(0);
      expect(typeof timestamp).toBe('number');
    });

    test('Should convert block timestamp to date', () => {
      const timestamp = 1645000000;
      const date = utils.blockToDate(timestamp);
      expect(date).toBeInstanceOf(Date);
      expect(date.getTime()).toBe(timestamp * 1000);
    });
  });
});
