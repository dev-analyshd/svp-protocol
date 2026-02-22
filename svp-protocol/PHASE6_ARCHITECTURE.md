# Phase 6: Architecture & Migration Guide

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         SVP Protocol Phase 6                        │
│                   Dividend & Revenue Distribution                   │
└─────────────────────────────────────────────────────────────────────┘

                    Revenue Sources
                          │
              ┌───────────┼───────────┐
              │           │           │
         Vault Yield  Protocol Fees  Liquidations
              │           │           │
              └───────────┼───────────┘
                          │
              ┌───────────▼──────────┐
              │ MultiAssetRouter     │
              │ - Fee Collection     │
              │ - Route Management   │
              │ - History Tracking   │
              └───────────┬──────────┘
                          │
                 ┌────────▼────────┐
                 │  Payment Tokens  │
                 │ (Multi-asset)    │
                 └────────┬────────┘
                          │
              ┌───────────▼──────────────┐
              │ Enhanced Dividend        │
              │ Tracker                  │
              │ - Allocations            │
              │ - Holder Tracking        │
              │ - Claims Management      │
              └───────────┬──────────────┘
                          │
              ┌───────────┴──────────────┐
              │                          │
         Standard Dividends   Performance Dividends
              │                          │
      ┌───────▼──────┐          ┌───────▼──────┐
      │ Regular      │          │ Yield        │
      │ Claims       │          │ Bonuses      │
      └──────────────┘          └──────────────┘
              │                          │
      ┌───────▼──────────────────────────▼──────┐
      │  Performance Yield Calculator            │
      │  - Metrics Tracking                      │
      │  - Bonus Calculation                     │
      │  - Benchmark Comparison                  │
      └───────────────────────────────────────────┘
```

## Contract Interaction Flow

### 1. Revenue Reception
```
1. Revenue source sends tokens via MultiAssetRevenueRouter.receiveRevenue()
   - Router validates source and token
   - Calculates protocol fee (5%)
   - Routes net amount to approved pools
   
2. Router emits RevenueReceived event
   - Tracks in revenueHistory
   - Updates source metrics
   
3. Pool (EnhancedDividendTracker) receives tokens
   - Holds tokens for dividend distribution
   - Ready for allocation creation
```

### 2. Dividend Allocation
```
1. Admin calls EnhancedDividendTracker.createAllocation()
   - Specifies token, total amount, holders, amounts
   - Dividend type (STANDARD, PERFORMANCE, BONUS, EMERGENCY)
   
2. Tracker creates allocation
   - Records for each holder: amount, unclaimed, claim count
   - Adds to pendingClaims for each holder
   - Emits AllocationCreated event
   
3. Allocation tracking begins
   - Holders can query pending dividends
   - Allocation statistics available
```

### 3. Performance-Based Distribution
```
1. PerformanceYieldCalculator tracks metrics
   - calculatePerformanceMetrics() sets start/current values
   - Records yield percentage and outperformer status
   - Calculates performance score (0-100)
   
2. Bonus calculation
   - calculateYieldBonus() computes bonus for outperformers
   - Stores in yieldBonuses array
   - Updates HolderPerformance.totalBonus
   
3. Integration with dividends
   - Bonus amount used in EnhancedDividendTracker.createAllocation()
   - Type set to PERFORMANCE for tracking
   - Claimed like standard dividends
```

### 4. Dividend Claims
```
Single Claim:
1. Holder calls claimDividend(allocationId)
2. Tracker validates allocation and amount
3. Calculates claim fee (0.5%)
4. Transfers: fee→feeRecipient, net→holder
5. Updates holder snapshot and claim history
6. Emits DividendClaimed event

Batch Claim:
1. Holder calls claimMultipleDividends([ids])
2. Processes each allocation in single transaction
3. Avoids reentrancy by inlining claim logic
4. Accumulates and returns total net amount
5. Updates claim streak once per batch
```

## Deployment Sequence

### Prerequisites
- Phase 1-5 completed and deployed
- SVPToken1400 deployed
- SVPGovernanceEnhanced deployed
- Dividend pool (or EOA) ready

### Phase 6 Deployment Steps

**Step 1: Deploy PerformanceYieldCalculator**
```solidity
address vaultAddress = <vault_address>;
PerformanceYieldCalculator calc = new PerformanceYieldCalculator(vaultAddress);
```

**Step 2: Deploy EnhancedDividendTracker**
```solidity
EnhancedDividendTracker tracker = new EnhancedDividendTracker();
```

**Step 3: Deploy MultiAssetRevenueRouter**
```solidity
MultiAssetRevenueRouter router = new MultiAssetRevenueRouter(tracker.address);
```

**Step 4: Configure Roles**
```solidity
// Grant DISTRIBUTOR_ROLE to distribution contracts/accounts
tracker.grantRole(DISTRIBUTOR_ROLE, adminAddress);

// Grant ORACLE_ROLE to performance updaters
calc.grantRole(ORACLE_ROLE, oracleAddress);

// Grant SOURCE_ROLE to revenue sources
router.grantRole(SOURCE_ROLE, vaultAddress);
router.grantRole(PAYMENT_TOKEN_ROLE, adminAddress);
```

**Step 5: Register Assets**
```solidity
// Register payment token (e.g., USDC)
router.registerPaymentToken(USDC_ADDRESS, 6, MIN_AMOUNT);

// Register revenue sources
router.registerRevenueSource(vaultAddress, 0, "Vault Yield");
router.registerRevenueSource(protocolAddress, 1, "Protocol Fees");

// Approve dividend pool
router.approvePool(tracker.address);

// Add routing rule (100% to tracker)
router.addRoutingRule(vaultAddress, tracker.address, 10000);
```

## Admin Functions Reference

### PerformanceYieldCalculator
```solidity
setTargetYield(uint256 newTargetBPS)           // Update target yield %
setPerformanceBonusRate(uint256 newRateBPS)    // Update bonus multiplier
setMinOutperformanceGap(uint256 gapBPS)        // Update trigger threshold
```

### MultiAssetRevenueRouter
```solidity
setFeePercentage(uint256 newFeeBPS)            // Update fee rate
setFeeCollector(address newCollector)          // Change fee recipient
pause() / unpause()                            // Pause/resume routing
registerRevenueSource(...)                     // Add source
registerPaymentToken(...)                      // Add token
addRoutingRule(...)                            // Add allocation rule
approvePool(address)                           // Approve pool
```

### EnhancedDividendTracker
```solidity
createAllocation(...)                          // Create dividend batch
finalizeAllocation(uint256 id)                 // Lock allocation
setMinClaimAmount(uint256 amount)              // Update minimum
setClaimFeePercentage(uint256 bps)             // Update fee rate
setFeeRecipient(address)                       // Change recipient
pause() / unpause()                            // Pause/resume claims
```

## Key Metrics to Monitor

### Revenue Metrics
```
- totalRevenueReceived: Total revenue routed through system
- totalRevenueRouted: Actual amount distributed (after fees)
- Per-source totalReceived: Revenue from each source
- Per-token totalVolume: Volume by asset type
```

### Distribution Metrics
```
- totalAllocatedValue: Total dividend allocation amount
- totalDistributedValue: Total claimed amount
- Per-allocation claimedAmount: Individual allocation claim rate
- Per-allocation unclaimedAmount: Pending payouts
```

### Performance Metrics
```
- Per-holder performanceScore: 0-100 performance rating
- Per-holder totalYield: Historical yield generation
- Per-holder totalBonus: Total performance bonus earned
- Per-holder claimStreak: Consecutive periods claimed
```

## Integration with Phase 5 (Governance)

Phase 6 can be governed through Phase 5 mechanisms:

1. **Proposal System**: Governance can propose parameter changes
   - Target yield adjustment
   - Bonus rate modification
   - Fee percentage changes

2. **Timelock**: Changes can be queued with delay
   - Emergency unpause/pause of distributions
   - Fee recipient address changes

3. **Voting Power**: Dividend claims can be weighted by voting power
   - Larger stakeholders receive larger dividends proportionally
   - Can integrate with SVPGovernanceEnhanced voting mechanics

## Monitoring & Operations

### Regular Tasks
1. Monitor revenue source health
2. Track dividend claim rates (should be > 80%)
3. Validate performance calculations
4. Review benchmark vs vault performance
5. Collect and reconcile fees

### Emergency Procedures
1. **Pause Revenue**: `router.pause()` stops inflows
2. **Pause Claims**: `tracker.pause()` stops outflows
3. **Emergency Recovery**: `recoverToken()` for stuck assets

### Metrics Dashboard
Track these in monitoring system:
```
Real-time:
- Pending unclaimed dividends
- Revenue received this period
- Average claim size
- Active allocations

Historical:
- Cumulative revenue by source
- Cumulative distribution amount
- Average performance score
- Claim rate by holder
```

## Phase 6 Ready for Production ✅

All contracts tested and deployed.
Ready for Phase 7: Frontend & SDK Integration
