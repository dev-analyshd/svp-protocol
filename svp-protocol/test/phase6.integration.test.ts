import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {
  PerformanceYieldCalculator,
  MultiAssetRevenueRouter,
  EnhancedDividendTracker,
  MockERC20,
} from "../typechain-types";

describe("Phase 6: Dividend & Revenue Distribution System", () => {
  let owner: SignerWithAddress;
  let holder1: SignerWithAddress;
  let holder2: SignerWithAddress;
  let holder3: SignerWithAddress;
  let vaultAddress: SignerWithAddress;
  let paymentToken: MockERC20;
  let performanceYield: PerformanceYieldCalculator;
  let revenueRouter: MultiAssetRevenueRouter;
  let dividendTracker: EnhancedDividendTracker;

  const DISTRIBUTOR_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("DISTRIBUTOR_ROLE"));
  const ORACLE_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("ORACLE_ROLE"));
  const SOURCE_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("SOURCE_ROLE"));
  const PAYMENT_TOKEN_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("PAYMENT_TOKEN_ROLE"));
  const ROUTER_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("ROUTER_ROLE"));
  const CLAIM_PROCESSOR_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("CLAIM_PROCESSOR_ROLE"));

  beforeEach(async () => {
    [owner, holder1, holder2, holder3, vaultAddress] = await ethers.getSigners();

    // Deploy mock ERC20 token
    const MockERC20Factory = await ethers.getContractFactory("MockERC20");
    paymentToken = (await MockERC20Factory.deploy(
      "Test Token",
      "TEST",
      ethers.utils.parseEther("10000")
    )) as MockERC20;
    await paymentToken.deployed();

    // Deploy PerformanceYieldCalculator
    const PerformanceYieldFactory = await ethers.getContractFactory("PerformanceYieldCalculator");
    performanceYield = (await PerformanceYieldFactory.deploy(vaultAddress.address)) as PerformanceYieldCalculator;
    await performanceYield.deployed();

    // Deploy EnhancedDividendTracker
    const DividendTrackerFactory = await ethers.getContractFactory("EnhancedDividendTracker");
    dividendTracker = (await DividendTrackerFactory.deploy()) as EnhancedDividendTracker;
    await dividendTracker.deployed();

    // Deploy MultiAssetRevenueRouter
    const RevenueRouterFactory = await ethers.getContractFactory("MultiAssetRevenueRouter");
    revenueRouter = (await RevenueRouterFactory.deploy(dividendTracker.address)) as MultiAssetRevenueRouter;
    await revenueRouter.deployed();

    // Grant roles
    await dividendTracker.grantRole(DISTRIBUTOR_ROLE, owner.address);
    await dividendTracker.grantRole(CLAIM_PROCESSOR_ROLE, owner.address);
    await revenueRouter.grantRole(SOURCE_ROLE, owner.address);
    await revenueRouter.grantRole(ROUTER_ROLE, owner.address);
    await revenueRouter.grantRole(PAYMENT_TOKEN_ROLE, owner.address);
    await performanceYield.grantRole(ORACLE_ROLE, owner.address);

    // Register payment token with router
    await revenueRouter.registerPaymentToken(paymentToken.address, 18, ethers.utils.parseEther("1"));

    // Register dividend pool (tracker as pool)
    await revenueRouter.approvePool(dividendTracker.address);

    // Register revenue source (owner as test source)
    await revenueRouter.registerRevenueSource(
      owner.address,
      0, // VAULT_YIELD
      "Test Revenue Source"
    );

    // Add routing rule
    await revenueRouter.addRoutingRule(
      owner.address,
      dividendTracker.address,
      10000 // 100% to dividend tracker
    );
  });

  describe("PerformanceYieldCalculator", () => {
    it("should calculate performance metrics correctly", async () => {
      const startValue = ethers.utils.parseEther("1000");
      const currentValue = ethers.utils.parseEther("1100");

      await performanceYield.calculatePerformanceMetrics(holder1.address, startValue, currentValue);

      const metrics = await performanceYield.getMetrics(holder1.address);
      expect(metrics.startValue).to.equal(startValue);
      expect(metrics.currentValue).to.equal(currentValue);
      expect(metrics.isOutperformer).to.be.true;
    });

    it("should calculate yield bonus for outperforming holders", async () => {
      const startValue = ethers.utils.parseEther("1000");
      const currentValue = ethers.utils.parseEther("1100");

      await performanceYield.calculatePerformanceMetrics(holder1.address, startValue, currentValue);
      await performanceYield.calculateYieldBonus(holder1.address);
      const bonus = await performanceYield.getTotalUnclaimedBonus(holder1.address);

      expect(bonus).to.be.gt(0);
    });

    it("should track performance scores", async () => {
      const startValue = ethers.utils.parseEther("1000");
      const currentValue = ethers.utils.parseEther("1200"); // 20% yield

      await performanceYield.calculatePerformanceMetrics(holder1.address, startValue, currentValue);
      const score = await performanceYield.calculatePerformanceScore(holder1.address);

      expect(score).to.be.gt(80); // High performer
    });

    it("should update benchmark data", async () => {
      const benchmarkReturn = 800; // 8%
      const vaultReturn = 1000; // 10%

      await performanceYield.updateBenchmark(benchmarkReturn, vaultReturn);

      const benchmarkData = await performanceYield.getBenchmarkData(1);
      expect(benchmarkData.benchmarkReturn).to.equal(benchmarkReturn);
      expect(benchmarkData.vaultReturn).to.equal(vaultReturn);
      expect(benchmarkData.outperformanceGap).to.equal(200); // 2% outperformance
    });
  });

  describe("MultiAssetRevenueRouter", () => {
    it("should register revenue source", async () => {
      const source = await revenueRouter.getRevenueSource(owner.address);
      expect(source.isActive).to.be.true;
      expect(source.sourceType).to.equal(0); // VAULT_YIELD
    });

    it("should register payment token", async () => {
      const token = await revenueRouter.getPaymentToken(paymentToken.address);
      expect(token.isActive).to.be.true;
      expect(token.decimals).to.equal(18);
    });

    it("should route revenue to approved pools", async () => {
      const revenueAmount = ethers.utils.parseEther("100");

      // Approve token transfer from owner to router
      await paymentToken.approve(revenueRouter.address, revenueAmount);

      const trackerBalanceBefore = await paymentToken.balanceOf(dividendTracker.address);

      // Send revenue
      await revenueRouter.receiveRevenue(paymentToken.address, revenueAmount, "0x");

      const trackerBalanceAfter = await paymentToken.balanceOf(dividendTracker.address);

      // Should receive tokens (minus protocol fee)
      expect(trackerBalanceAfter).to.be.gt(trackerBalanceBefore);
    });

    it("should track revenue history", async () => {
      const revenueAmount = ethers.utils.parseEther("50");
      await paymentToken.approve(revenueRouter.address, revenueAmount);

      await revenueRouter.receiveRevenue(paymentToken.address, revenueAmount, "0x");

      const historyLength = await revenueRouter.getRevenueHistoryLength();
      expect(historyLength).to.equal(1);

      const record = await revenueRouter.getRevenueRecord(0);
      expect(record.token).to.equal(paymentToken.address);
      expect(record.source).to.equal(owner.address);
    });

    it("should calculate and collect fees", async () => {
      const revenueAmount = ethers.utils.parseEther("100");
      await paymentToken.approve(revenueRouter.address, revenueAmount);

      const feeCollectorBefore = await paymentToken.balanceOf(owner.address);

      await revenueRouter.receiveRevenue(paymentToken.address, revenueAmount, "0x");

      const feeCollectorAfter = await paymentToken.balanceOf(owner.address);

      // Fee should be collected (5% by default)
      const expectedFee = revenueAmount.mul(500).div(10000);
      
      // Owner balance should decrease by revenue amount sent, but fee should be paid from revenue
      // So net effect: balance decreases by (revenue - fee)
      expect(feeCollectorBefore.sub(feeCollectorAfter)).to.equal(revenueAmount.sub(expectedFee));
    });
  });

  describe("EnhancedDividendTracker", () => {
    it("should create dividend allocation", async () => {
      const allocation = ethers.utils.parseEther("300");
      const holders = [holder1.address, holder2.address, holder3.address];
      const amounts = [
        ethers.utils.parseEther("100"),
        ethers.utils.parseEther("100"),
        ethers.utils.parseEther("100"),
      ];

      // Mint tokens to tracker for distribution
      await paymentToken.mint(dividendTracker.address, allocation);

      await dividendTracker.createAllocation(
        paymentToken.address,
        allocation,
        holders,
        amounts,
        0 // STANDARD
      );

      const allocationData = await dividendTracker.getAllocation(0);
      expect(allocationData.totalAmount).to.equal(allocation);
      expect(allocationData.holderCount).to.equal(3);
    });

    it("should track pending dividends", async () => {
      const allocation = ethers.utils.parseEther("300");
      const holders = [holder1.address, holder2.address, holder3.address];
      const amounts = [
        ethers.utils.parseEther("100"),
        ethers.utils.parseEther("100"),
        ethers.utils.parseEther("100"),
      ];

      await paymentToken.mint(dividendTracker.address, allocation);

      await dividendTracker.createAllocation(paymentToken.address, allocation, holders, amounts, 0);

      const pending = await dividendTracker.getPendingDividend(holder1.address, 0);
      expect(pending).to.equal(ethers.utils.parseEther("100"));
    });

    it("should allow claiming dividends", async () => {
      const allocation = ethers.utils.parseEther("300");
      const holders = [holder1.address, holder2.address];
      const amounts = [ethers.utils.parseEther("150"), ethers.utils.parseEther("150")];

      await paymentToken.mint(dividendTracker.address, allocation);

      await dividendTracker.createAllocation(paymentToken.address, allocation, holders, amounts, 0);

      const holder1BalanceBefore = await paymentToken.balanceOf(holder1.address);

      await dividendTracker.connect(holder1).claimDividend(0);

      const holder1BalanceAfter = await paymentToken.balanceOf(holder1.address);

      expect(holder1BalanceAfter).to.be.gt(holder1BalanceBefore);
    });

    it("should track claim history", async () => {
      const allocation = ethers.utils.parseEther("200");
      const holders = [holder1.address, holder2.address];
      const amounts = [ethers.utils.parseEther("100"), ethers.utils.parseEther("100")];

      await paymentToken.mint(dividendTracker.address, allocation);

      await dividendTracker.createAllocation(paymentToken.address, allocation, holders, amounts, 0);

      await dividendTracker.connect(holder1).claimDividend(0);

      const claimHistory = await dividendTracker.getClaimHistory(holder1.address);
      expect(claimHistory.length).to.equal(1);
      expect(claimHistory[0].holder).to.equal(holder1.address);
    });

    it("should support batch claims", async () => {
      // Create two allocations
      const holders = [holder1.address, holder2.address];

      // First allocation
      const amount1 = ethers.utils.parseEther("200");
      const amounts1 = [ethers.utils.parseEther("100"), ethers.utils.parseEther("100")];
      await paymentToken.mint(dividendTracker.address, amount1);
      await dividendTracker.createAllocation(paymentToken.address, amount1, holders, amounts1, 0);

      // Second allocation
      const amount2 = ethers.utils.parseEther("200");
      const amounts2 = [ethers.utils.parseEther("100"), ethers.utils.parseEther("100")];
      await paymentToken.mint(dividendTracker.address, amount2);
      await dividendTracker.createAllocation(paymentToken.address, amount2, holders, amounts2, 0);

      const balanceBefore = await paymentToken.balanceOf(holder1.address);

      // Claim from both
      await dividendTracker.connect(holder1).claimMultipleDividends([0, 1]);

      const balanceAfter = await paymentToken.balanceOf(holder1.address);

      expect(balanceAfter).to.be.gt(balanceBefore);
    });

    it("should track holder snapshots", async () => {
      const allocation = ethers.utils.parseEther("100");
      const holders = [holder1.address];
      const amounts = [ethers.utils.parseEther("100")];

      await paymentToken.mint(dividendTracker.address, allocation);

      await dividendTracker.createAllocation(paymentToken.address, allocation, holders, amounts, 0);

      await dividendTracker.connect(holder1).claimDividend(0);

      const snapshot = await dividendTracker.getHolderSnapshot(holder1.address);
      expect(snapshot.holder).to.equal(holder1.address);
      expect(snapshot.claimStreak).to.be.gt(0);
    });

    it("should calculate allocation statistics", async () => {
      const allocation = ethers.utils.parseEther("300");
      const holders = [holder1.address, holder2.address];
      const amounts = [ethers.utils.parseEther("150"), ethers.utils.parseEther("150")];

      await paymentToken.mint(dividendTracker.address, allocation);

      await dividendTracker.createAllocation(paymentToken.address, allocation, holders, amounts, 0);

      await dividendTracker.connect(holder1).claimDividend(0);

      const stats = await dividendTracker.getAllocationStats(0);
      expect(stats.totalAmount).to.equal(allocation);
      expect(stats.claimPercentage).to.be.gt(0);
      expect(stats.holderCount).to.equal(2);
    });
  });

  describe("Phase 6 Integration", () => {
    it("should integrate revenue router with dividend tracker", async () => {
      // Setup
      const revenueAmount = ethers.utils.parseEther("100");
      const holders = [holder1.address, holder2.address];
      const amounts = [ethers.utils.parseEther("95"), ethers.utils.parseEther("95")];

      // Send revenue through router
      await paymentToken.approve(revenueRouter.address, revenueAmount);
      await revenueRouter.receiveRevenue(paymentToken.address, revenueAmount, "0x");

      // Create allocation from received revenue
      const trackerBalance = await paymentToken.balanceOf(dividendTracker.address);
      const halfBalance = trackerBalance.div(2);

      await dividendTracker.createAllocation(
        paymentToken.address,
        halfBalance,
        holders,
        [halfBalance.div(2), halfBalance.div(2)],
        0
      );

      // Claim dividends
      const holder1BalanceBefore = await paymentToken.balanceOf(holder1.address);
      await dividendTracker.connect(holder1).claimDividend(0);
      const holder1BalanceAfter = await paymentToken.balanceOf(holder1.address);

      expect(holder1BalanceAfter).to.be.gt(holder1BalanceBefore);
    });

    it("should support performance-based dividend allocation", async () => {
      // Calculate performance
      const startValue = ethers.utils.parseEther("1000");
      const currentValue = ethers.utils.parseEther("1200");

      await performanceYield.calculatePerformanceMetrics(holder1.address, startValue, currentValue);
      await performanceYield.calculateYieldBonus(holder1.address);
      const bonus = await performanceYield.getTotalUnclaimedBonus(holder1.address);

      expect(bonus).to.be.gt(0);

      // Create performance dividend allocation
      const holders = [holder1.address, holder2.address];
      const perfBonus = bonus.div(2);
      const amounts = [perfBonus, ethers.utils.parseEther("10")];
      const totalAmount = amounts[0].add(amounts[1]);

      await paymentToken.mint(dividendTracker.address, totalAmount);

      await dividendTracker.createAllocation(
        paymentToken.address,
        totalAmount,
        holders,
        amounts,
        1 // PERFORMANCE type
      );

      const allocation = await dividendTracker.getAllocation(0);
      expect(allocation.divType).to.equal(1);
    });

    it("should track total distributed value", async () => {
      const allocation = ethers.utils.parseEther("100");
      const holders = [holder1.address, holder2.address];
      const amounts = [ethers.utils.parseEther("50"), ethers.utils.parseEther("50")];

      await paymentToken.mint(dividendTracker.address, allocation);

      await dividendTracker.createAllocation(paymentToken.address, allocation, holders, amounts, 0);

      await dividendTracker.connect(holder1).claimDividend(0);
      await dividendTracker.connect(holder2).claimDividend(0);

      const totalDistributed = await dividendTracker.totalDistributedValue();
      expect(totalDistributed).to.be.gt(0);
    });
  });
});
