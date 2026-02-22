# SVP Protocol - Technical Specification Document

**Protocol Name:** SVP Protocol – Structured Valuation Protocol  
**Inventor:** Hudu Yusuf (Analys)  
**Version:** 1.0.0 (Production Ready)  
**Chain:** Arbitrum / Robinhood Chain Testnet  
**Language:** Solidity 0.8.20  

---

## 📋 Table of Contents

1. [Executive Summary](#executive-summary)
2. [Protocol Architecture](#protocol-architecture)
3. [Contract Modular Breakdown](#contract-modular-breakdown)
4. [Data Flow Architecture](#data-flow-architecture)
5. [Security Model](#security-model)
6. [Upgradeability Model](#upgradeability-model)
7. [Token Standards](#token-standards)
8. [Governance Mechanism Design](#governance-mechanism-design)
9. [Oracle-Free Valuation Logic](#oracle-free-valuation-logic)
10. [Admin vs Public Roles](#admin-vs-public-roles)
11. [Smart Contract Interaction Flow](#smart-contract-interaction-flow)

---

## 1. Executive Summary

SVP Protocol is a **fully on-chain intrinsic valuation engine** that enables:

- **Tokenized Equity Infrastructure**: Convert real-world assets into tradeable ERC-20/ERC-1400 tokens
- **Value-Weighted Governance**: Voting power = Token Balance × Intrinsic Value
- **SPV Pooling**: Vault-based investment vehicles (ERC-4626) for capital pooling
- **Automated Revenue Distribution**: Dividend distribution tied to valuation updates
- **Developer-Ready SDK**: TypeScript/JavaScript bindings for application integration
- **Upgrade-Safe Architecture**: UUPS proxy pattern for ongoing protocol evolution
- **Production-Grade Security**: Multisig, timelocks, emergency pause, access control

**Core Thesis:**

> Value is computed on-chain. Governance weight is derived from computed value. All capital flows are deterministic and auditable.

---

## 2. Protocol Architecture

### 2.1 High-Level System Diagram

```
                    ┌────────────────────────────┐
                    │    Frontend (dApp)         │
                    │  (Next.js + TypeScript)    │
                    └────────────┬───────────────┘
                                 │
                    ┌────────────▼───────────────┐
                    │    SVP SDK Layer           │
                    │  (TypeScript/JavaScript)   │
                    └────────────┬───────────────┘
                                 │
    ┌────────────────────────────────────────────────────────┐
    │           Backend Layer (Node.js + TypeScript)         │
    │  ┌────────────────────────────────────────────────────┐│
    │  │ - KYC/AML Processing                              ││
    │  │ - Financial Data Ingestion API                    ││
    │  │ - Valuation Calculation Service                   ││
    │  │ - Governance Relayer                              ││
    │  │ - Off-Chain Caching & Analytics                   ││
    │  └────────────────────────────────────────────────────┘│
    └────────────────────┬───────────────────────────────────┘
                         │
    ┌────────────────────────────────────────────────────────┐
    │        Smart Contract Layer (Solidity 0.8.20)          │
    │                                                        │
    │  ┌─ Proxy System ─────────────────────────────────┐  │
    │  │ SVPProxy (UUPS Upgradeable)                   │  │
    │  │ Delegated to: SVPValuationEngine              │  │
    │  └─────────────────────────────────────────────────┘  │
    │                                                        │
    │  ┌─ Core Contracts ──────────────────────────────┐  │
    │  │ SVPValuationEngine           (Modular)        │  │
    │  │ SVPAssetRegistry             (Storage)        │  │
    │  │ SVPToken                     (ERC-20/1400)    │  │
    │  │ SVPGovernance                (Value-weighted) │  │
    │  │ SVPSPVVault                  (ERC-4626)       │  │
    │  │ SVPDividendDistributor       (Rewards)        │  │
    │  │ SVPAccessControl             (RBAC)           │  │
    │  │ SVPFactory                   (Deployment)     │  │
    │  └─────────────────────────────────────────────────┘  │
    │                                                        │
    │  ┌─ Security Layer ──────────────────────────────┐  │
    │  │ ReentrancyGuard                              │  │
    │  │ Pausable Controller                          │  │
    │  │ TimelockController (multisig)                │  │
    │  │ Emergency Circuit Breaker                    │  │
    │  └─────────────────────────────────────────────────┘  │
    └────────────────────┬───────────────────────────────────┘
                         │
    ┌────────────────────────────────────────────────────────┐
    │            Indexer Layer (The Graph / Rust)            │
    │  ┌────────────────────────────────────────────────────┐│
    │  │ - Historical Valuation Tracking                   ││
    │  │ - Event Indexing & Transformation                 ││
    │  │ - Analytics API                                   ││
    │  │ - Real-time GraphQL Queries                       ││
    │  └────────────────────────────────────────────────────┘│
    └────────────────────────────────────────────────────────┘
                         │
    ┌────────────────────────────────────────────────────────┐
    │              Blockchain Layer                          │
    │  Arbitrum One / Robinhood Chain Testnet               │
    │  EVM Compatible, Ethereum-grade Security             │
    └────────────────────────────────────────────────────────┘
```

### 2.2 Protocol Participants

| Role | Responsibilities | Examples |
|------|------------------|----------|
| **Asset Owner (SME)** | Submits financial data, receives valuation, mints equity tokens | Small business, private equity firm |
| **Reporter** | Validates and submits financial metrics on-chain | Data provider, compliance officer |
| **Investor** | Purchases asset tokens or invests in SPV vaults | Individual, institution |
| **Governance Participant** | Votes on protocol decisions, weighted by intrinsic value | Token holders |
| **Protocol Admin** | Manages access, upgrades, emergency controls | DAO multisig, foundation |
| **SPV Manager** | Deploys and manages investment pools | Fund manager |

---

## 3. Contract Modular Breakdown

### 3.1 Contract Interdependencies

```
SVPAccessControl (base)
    ├── SVPValuationEngine (UUPS Proxy)
    ├── SVPAssetRegistry
    ├── SVPToken (ERC20 Base)
    ├── SVPGovernance (depends on Valuation + Token)
    ├── SVPSPVVault (ERC4626 - depends on Token)
    ├── SVPDividendDistributor (depends on Valuation + Token)
    ├── SVPFactory (factory for SPV instances)
    └── SVPReporter (depends on Asset Registry + Valuation)
```

### 3.2 Core Contract Specifications

#### **SVPAccessControl.sol**
- **Purpose**: Centralized RBAC (Role-Based Access Control)
- **Roles**: 
  - `DEFAULT_ADMIN_ROLE` - Protocol superadmin
  - `REPORTER_ROLE` - Financial data submitters
  - `MINTER_ROLE` - Token minting authority
  - `GOVERNANCE_ROLE` - Proposal execution
  - `EMERGENCY_ROLE` - Pause mechanism
- **Inheritance**: OpenZeppelin AccessControl + AccessControlUpgradeable

#### **SVPValuationEngine.sol** (UUPS Proxy)
- **Purpose**: Core on-chain intrinsic valuation logic
- **Key Functions**:
  - `updateFinancialData()` - Accept financial metrics from reporters
  - `calculateIntrinsicValue()` - Compute asset valuation
  - `getIntrinsicValue()` - Read current valuation
  - `setValuationModule()` - Swap valuation algorithm
- **Modular Plugin System**: External valuation modules can be plugged in
- **Events**: `FinancialDataUpdated`, `IntrinsicValueCalculated`, `ValuationModuleChanged`

#### **SVPAssetRegistry.sol**
- **Purpose**: Register and track tokenizable assets
- **Key Functions**:
  - `registerAsset()` - Register new asset
  - `approveAsset()` - Admin approval
  - `getAssetMetadata()` - Retrieve asset info
- **Data**: Asset name, metadata URI, approval status, registration timestamp
- **Events**: `AssetRegistered`, `AssetApproved`, `AssetMetadataUpdated`

#### **SVPToken.sol** (ERC-20 compatible)
- **Purpose**: Security token representing fractional ownership
- **Features**:
  - Minting by authorized roles
  - Transfer hooks for compliance
  - Burnable tokens
  - Snapshot history for voting
- **ERC-1400 Path**: Can extend to partitioned ownership
- **Events**: Standard ERC-20 + custom `TokenMinted`, `TokenBurned`

#### **SVPGovernance.sol**
- **Purpose**: Value-weighted governance voting
- **Voting Power Formula**: `VotingPower = TokenBalance × IntrinsicValue / BASE`
- **Key Functions**:
  - `createProposal()` - Initiate governance action
  - `castVote()` - Submit vote
  - `executeProposal()` - Execute if quorum met
  - `getVotingPower()` - Calculate weighted votes
- **Parameters**:
  - Quorum: 20% of total weighted votes
  - Proposal Duration: 7 days
  - Execution Delay (Timelock): 2 days
- **Events**: `ProposalCreated`, `VoteCast`, `ProposalExecuted`, `ProposalCanceled`

#### **SVPSPVVault.sol** (ERC-4626)
- **Purpose**: Special Purpose Vehicle for capital pooling
- **Features**:
  - Stablecoin deposits → SPV shares minted
  - Vault manages multi-asset portfolio
  - Real-time NAV calculation
  - Redemption/exit logic
- **Key Functions**:
  - `deposit()` - Invest stablecoin (inherited ERC4626)
  - `withdraw()` - Exit position (inherited ERC4626)
  - `investInAsset()` - Allocate capital to SVP tokens
  - `rebalance()` - Adjust portfolio allocation
- **Parameters**:
  - Min investment: 100 USDC
  - Redemption cooldown: 1 day
  - Max allocation per asset: 30%
- **Events**: `InvestmentMade`, `RedemptionRequested`, `RebalanceExecuted`

#### **SVPDividendDistributor.sol**
- **Purpose**: Automated revenue distribution to token holders
- **Key Functions**:
  - `depositDividends()` - Protocol revenue collected
  - `claimDividends()` - Holders claim share
  - `calculateShare()` - Proportional distribution
- **Logic**: Each token holder receives: `(TotalDividends × TokenBalance) / TotalSupply`
- **Events**: `DividendDeposited`, `DividendClaimed`, `DistributionCalculated`

#### **SVPReporter.sol**
- **Purpose**: Manages financial data submission and validation
- **Key Functions**:
  - `submitFinancialData()` - Report revenue, assets, etc.
  - `validateData()` - Internal checks
  - `markDataAsApproved()` - Admin confirmation
- **Validation Rules**:
  - Assets must be registered
  - Reporter must have REPORTER_ROLE
  - Data must pass sanity checks (no negative values)
- **Events**: `DataSubmitted`, `DataValidated`, `DataRejected`

#### **SVPFactory.sol**
- **Purpose**: Factory for deploying new SVP instances or SPV vaults
- **Key Functions**:
  - `deployNewAsset()` - Create token for new asset
  - `deployNewSPV()` - Create new vault
  - `trackDeployment()` - Registry of all deployments
- **Events**: `AssetDeployed`, `SPVDeployed`

---

## 4. Data Flow Architecture

### 4.1 Valuation Flow

```
1. Asset Owner
   │
   └─→ Submit Financial Data
       ├─ Revenue
       ├─ Assets
       ├─ Liabilities
       ├─ Growth Rate
       └─ Risk Factor
       
2. Reporter (Backend/Oracle)
   │
   └─→ SVPReporter.submitFinancialData()
       │
       └─→ Validate Data
           │
           └─→ Store in SVPValuationEngine.financials[assetAddress]
           
3. Admin/Timelock
   │
   └─→ SVPValuationEngine.calculateIntrinsicValue(assetAddress)
       │
       ├─ Fetch stored financial metrics
       ├─ Apply valuation formula:
       │  IntrinsicValue = NetAssets + (Revenue × GrowthMultiplier / RiskFactor)
       ├─ Update valuations[assetAddress].intrinsicValue
       └─ Emit IntrinsicValueCalculated event
       
4. Downstream Systems
   │
   ├─→ SVPGovernance reads getIntrinsicValue() for voting power
   ├─→ SVPDividendDistributor uses valuation for share calculation
   ├─→ SPV Manager uses for portfolio weighting
   └─→ Frontend displays updated valuation
```

### 4.2 Investment Flow

```
1. Investor
   │
   └─→ Approve USDC to SVPSPVVault
   
2. Investor
   │
   └─→ SVPSPVVault.deposit(amount)
       │
       ├─ Transfer USDC from investor
       ├─ Calculate share price: (totalAssets + amount) / totalShares
       ├─ Mint SPV shares to investor
       └─ Emit Deposit event
       
3. SPV Manager
   │
   └─→ SVPSPVVault.investInAsset(assetToken, amount)
       │
       ├─ Approve USDC spend to asset token if needed
       ├─ Purchase SVP tokens from market or mint
       ├─ Update portfolio allocation
       └─ Emit InvestmentMade event
       
4. Revenue Generation
   │
   └─→ Asset generates revenue
       │
       └─→ SVPDividendDistributor.depositDividends()
           │
           ├─ Distribute pro-rata to SPV
           ├─ SPV withdraws dividends
           ├─ Distribute to SPV share holders (ERC4626 yield)
           └─ Emit DividendClaimed events
```

### 4.3 Governance Flow

```
1. Governance Participant
   │
   └─→ SVPGovernance.createProposal(description, targets, actions)
       │
       └─ Proposal stored with:
          ├─ Creation timestamp
          ├─ Voting start block
          ├─ Voting end block (7 days)
          └─ Status: PENDING
       
2. Participant
   │
   └─→ SVPGovernance.castVote(proposalId, support)
       │
       ├─ Calculate voting power:
       │  votingPower = tokenBalance × intrinsicValue / 1e18
       │
       ├─ Record vote:
       │  support = 0 (Against)
       │  support = 1 (For)
       │  support = 2 (Abstain)
       │
       └─ Accumulate votes to proposal
       
3. After Voting Period
   │
   └─→ Check Quorum (20% of total weight participated)
   
4. If Approved
   │
   └─→ Timelock: 2-day delay
   
5. After Timelock
   │
   └─→ SVPGovernance.executeProposal(proposalId)
       │
       ├─ Call target contracts with provided actions
       ├─ Update protocol parameters
       └─ Emit ProposalExecuted event
```

---

## 5. Security Model

### 5.1 Threat Vectors & Mitigations

| Threat | Mitigation |
|--------|-----------|
| **Reentrancy** | ReentrancyGuard on all state-changing functions |
| **Unauthorized Access** | Role-based access control (AccessControl) |
| **Overflow/Underflow** | Solidity 0.8.20 (checked arithmetic) |
| **Flash Loan Attack** | Snapshot voting (historical block values) |
| **Price Manipulation** | Oracle-free model, multisig value approval |
| **Proxy Attack** | UUPS with authorized upgrade path |
| **Emergency** | Pausable + Emergency admin can halt |
| **Timelock Bypass** | 2-day minimum delay for critical actions |

### 5.2 Access Control Matrix

```
Function                           DEFAULT_ADMIN  REPORTER  MINTER  GOVERNANCE  EMERGENCY
──────────────────────────────────────────────────────────────────────────────────────────
updateFinancialData()              ❌             ✅         ❌      ❌           ❌
approveAsset()                     ✅             ❌         ❌      ❌           ❌
registerAsset()                    ❌             ✅         ❌      ❌           ❌
mint()                             ❌             ❌         ✅      ❌           ❌
calculateIntrinsicValue()          ✅             ✅         ❌      ❌           ❌
createProposal()                   ❌             ❌         ❌      ✅           ❌
executeProposal()                  ✅             ❌         ❌      ✅           ❌
pause()                            ✅             ❌         ❌      ❌           ✅
_authorizeUpgrade()                ✅             ❌         ❌      ❌           ❌
setValuationModule()               ✅             ❌         ❌      ❌           ❌
```

### 5.3 Rate Limiting & Spam Prevention

- **Financial Data Updates**: Max 1 per asset per day (configurable)
- **Proposal Creation**: Minimum 10,000 voting power required
- **Vote Casting**: 1 vote per account per proposal
- **Dividend Distribution**: Max 1 distribution per day per asset

### 5.4 Emergency Protocols

- **Pause Mechanism**: Emergency admin can pause all transfers and deposits
- **Circuit Breaker**: If valuation changes > 50% in one update, auto-freeze pending review
- **Recovery Mode**: Admin can blacklist compromised accounts (with governance override)

---

## 6. Upgradeability Model

### 6.1 UUPS (Universal Upgradeable Proxy Standard)

**Architecture:**
```
SVPProxy (UUPS)
    └─ Implementation: SVPValuationEngine (current)
       └ Can upgrade to: SVPValuationEngineV2
```

**Upgrade Process:**
1. Deploy new implementation contract (e.g., SVPValuationEngineV2)
2. Admin calls `SVPProxy.upgradeTo(newImplementation)`
3. Proxy delegates all calls to new implementation
4. Storage layout preserved (required for security)

### 6.2 Storage Layout Contract

```solidity
contract SVPValuationEngineStorageV1 {
    mapping(address => FinancialData) public financials;
    mapping(address => Valuation) public valuations;
    address public valuationModule;
    uint256[50] __gap;  // Reserved for future storage
}
```

### 6.3 Upgrade Governance

- **Minor Upgrades** (bug fixes, gas optimization): 2/3 multisig approval
- **Major Upgrades** (algorithm changes): Full governance vote + 2-day timelock
- **Breaking Changes**: Require new proxy deployment (no in-place storage breaking changes)

### 6.4 Modular Valuation Plug-in System

**Interface:**
```solidity
interface IValuationModule {
    function compute(address asset, FinancialData calldata data) 
        external view returns (uint256 intrinsicValue);
}
```

**Allows:**
- Switching valuation algorithms without core contract upgrade
- A/B testing different formulas
- Future AI-based valuation integration
- Industry-specific valuation models

---

## 7. Token Standards

### 7.1 ERC-20 Base Layer

**SVPToken.sol**
- Standard ERC-20 with snapshots for voting
- Minting/burning with role control
- Transfer hooks for compliance
- Metadata: name, symbol, decimals

### 7.2 ERC-1400 Security Token (Future Extension)

**Path to ERC-1400:**
```
SVPToken (ERC-20)
    ↓ (Upgrade)
SVPTokenPartitioned (ERC-1400 compatible)
    ├─ Partition by holder class (institutional, retail)
    ├─ Transfer restrictions per partition
    ├─ Compliance hooks
    └─ Whitelist enforcement
```

**Features (pluggable):**
- Partitioned ownership tiers
- Accredited investor restrictions
- Geography-based restrictions
- Lock-up periods
- Transfer pause per partition

### 7.3 ERC-4626 Vault Token (SPV Shares)

**SVPSPVVault.sol**
- Standard ERC-4626 compatible
- Shares represent pro-rata ownership of vault
- Redeem shares for stablecoin (subject to liquidity)
- Yield accumulation via dividend distribution

**Share Price Calculation:**
```
Share Price = (Total Assets + Pending Dividends) / Total Shares
```

---

## 8. Governance Mechanism Design

### 8.1 Voting Power Calculation

**Formula:**
```
VotingPower(account) = 
    SVPToken.balanceOf(account) × IntrinsicValue(asset) / 1e18
```

**Example:**
- Account holds: 1,000 SVP tokens
- Asset intrinsic value: $50,000
- Total shares: 10,000 (1% ownership)
- Voting power: (1,000 × 50,000) / 1e18 ≈ 0.00005 (scaled)

### 8.2 Proposal Lifecycle

**PENDING** (0-7 days)
- Proposal created
- Voting parameters recorded
- Voting starts at creation

**ACTIVE** (7 days)
- Voting occurs
- Votes accumulated

**DEFEATED**
- If: For votes < Against votes
- Action: Proposal rejected

**SUCCEEDED**
- If: For votes > Against votes
- If: Quorum met (20% participation)
- Action: Enter timelock

**QUEUED** (2 days)
- Timelock delay active
- Cannot be executed during this period

**EXECUTED**
- After timelock expires
- Actions called on target contracts
- Proposal complete

**CANCELED**
- If governance votes to cancel
- Or proposer cancels before voting ends

### 8.3 Quorum & Voting Thresholds

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Quorum | 20% of total voting power | Prevents empty votes |
| Support | >50% of votes cast | Simple majority |
| Timelock | 2 days | Escape hatch period |
| Voting Period | 7 days | Sufficient time to organize |

### 8.4 Emergency Veto

- Protocol admin can veto queued proposals
- Override by governance with 2/3 supermajority
- Used for critical security issues only

---

## 9. Oracle-Free Valuation Logic

### 9.1 Core Formula

**Intrinsic Value Calculation:**

```
IntrinsicValue = NetAssets + RevenueValue

Where:
  NetAssets = Max(0, Assets - Liabilities)
  
  RevenueValue = (Revenue × GrowthMultiplier) / RiskFactor
  
  GrowthMultiplier = 1 + GrowthRate (where GrowthRate is % annual growth)
  
  RiskFactor = 1e18 (neutral) to 5e18 (very risky)
```

**Example Calculation:**
```
Asset: TechCorp Inc
Revenue: $100M
Growth Rate: 20% (annual)
Assets: $500M
Liabilities: $200M
Risk Factor: 1.5 (higher risk tech)

NetAssets = 500M - 200M = 300M
GrowthMultiplier = 1 + 0.20 = 1.20
RevenueValue = (100M × 1.20) / 1.5 = 80M
IntrinsicValue = 300M + 80M = $380M
```

### 9.2 Why No Oracle Needed

1. **Data Source**: Financial statements from asset owner
2. **Verification**: Reporters validate off-chain, multisig approves on-chain
3. **Immutability**: Once approved, stored permanently on-chain
4. **Auditability**: Full transaction history available
5. **Transparency**: Any observer can see valuation derivation

### 9.3 Modular Calculation Engine

**Alternative Formula Support:**

```solidity
interface IValuationModule {
    function compute(address asset, FinancialData data) 
        external view returns (uint256);
}

// Examples:
- DCF (Discounted Cash Flow) model
- EBITDA multiples
- Comparable company analysis
- Machine learning models (future)
```

**Governance can:**
1. Deploy new valuation module
2. Vote to switch: `SVPValuationEngine.setValuationModule(newModule)`
3. Historical data used to recalculate valuations (if desired)

### 9.4 Dynamic Recalculation

**Trigger Events:**
- Manual update by admin/reporter
- Scheduled recalculation (weekly)
- Governance proposal changes

**Result:**
- New intrinsic value computed
- Event emitted: `IntrinsicValueUpdated(asset, newValue, oldValue)`
- Governance power recalculated downstream

---

## 10. Admin vs Public Roles

### 10.1 Role Definitions

**DEFAULT_ADMIN_ROLE**
- Can grant/revoke other roles
- Can authorize upgrades
- Can pause protocol
- Can set governance parameters
- Typically multisig (e.g., 3-of-5)

**REPORTER_ROLE**
- Can submit financial data
- Can update asset financials
- Can trigger valuations
- Rate-limited to prevent spam
- Examples: Finance teams, data providers

**MINTER_ROLE**
- Can mint new tokens
- Usually assigned to Factory contract
- Prevents unauthorized token creation

**GOVERNANCE_ROLE**
- Can create proposals
- Can execute proposals
- Derived from voting power (implicit)

**EMERGENCY_ROLE**
- Can invoke pause mechanisms
- Can trigger circuit breakers
- Separate from DEFAULT_ADMIN

### 10.2 Public Functions

**Anyone Can Call:**
- `getIntrinsicValue(asset)` - Read valuation
- `getVotingPower(account)` - Calculate voting power
- `balanceOf()` - Check token balance (ERC-20)
- `deposit(amount)` - Invest in SPV vault (ERC-4626)
- `castVote(proposalId, support)` - Vote on proposals
- `claimDividends()` - Claim rewards

**Restricted Functions:**
- `updateFinancialData()` - REPORTER_ROLE only
- `mint()` - MINTER_ROLE only
- `calculateIntrinsicValue()` - REPORTER_ROLE or admin
- `executeProposal()` - GOVERNANCE_ROLE only (after timelock)
- `pause()` - DEFAULT_ADMIN or EMERGENCY

---

## 11. Smart Contract Interaction Flow

### 11.1 Complete System Interaction Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        User Interactions                         │
└────────────┬────────────────────────────────────────────────────┘
             │
    ┌────────┴────────────────────────────────────────────────────┐
    │                                                              │
    ▼                                                              ▼
┌──────────────────────┐                          ┌──────────────────┐
│  Asset Owner / SME   │                          │  Token Investor  │
│                      │                          │                  │
│ 1. Register asset    │                          │ 1. Buy tokens    │
│ 2. Submit financials │                          │ 2. Stake voting  │
│ 3. Mint equity token │                          │ 3. Join governance│
└──────────────────────┘                          └──────────────────┘
    │                                                   │
    ├─→ SVPAssetRegistry.registerAsset()              │
    │   (stores asset metadata)                        │
    │                                                  │
    ├─→ SVPReporter.submitFinancialData()             │
    │   (validates & stores metrics)                   │
    │                                                  ├─→ SVPToken.balanceOf()
    ├─→ SVPToken.mint(owner, shares)                  │   (check holdings)
    │   (create equity tokens)                        │
    │                                                  ├─→ SVPGovernance.castVote()
    └─→ SVPValuationEngine.calculateIntrinsicValue()  │   (participate in voting)
        (compute asset value)                         │
        │                                             └─→ SVPDividendDistributor
        ├─ Emit: IntrinsicValueCalculated                  .claimDividends()
        │   (downstream systems notified)                  (collect rewards)
        │
        ├─→ SVPGovernance (reads updated value)
        │   └─ All voting power recalculated
        │
        ├─→ SVPDividendDistributor
        │   └─ Share calculations updated
        │
        ├─→ Frontend Dashboard
        │   └─ Display new valuation
        │
        └─→ Indexer (The Graph)
            └─ Store historical value

┌──────────────────────────────────────────────────────────────────┐
│                     SPV Vault Flow                               │
└──────────────┬───────────────────────────────────────────────────┘
               │
               ▼
        ┌─────────────┐
        │   Investor  │
        │  (Deposits) │
        └──────┬──────┘
               │
               ├─→ USDC.approve(SVPSPVVault, amount)
               │   (authorize spending)
               │
               ├─→ SVPSPVVault.deposit(amount)
               │   (invest stablecoin)
               │   └─ Receive SPV shares (ERC4626)
               │
               ├─→ SVPSPVVault.investInAsset(assetToken, portion)
               │   (vault manager reallocates to SVP tokens)
               │
               ├─→ SVPAsset receives dividends
               │
               ├─→ SVPDividendDistributor distributes to SPV
               │
               ├─→ SPV accrues value (ERC4626 yield)
               │
               └─→ SVPSPVVault.withdraw(shares)
                   (investor exits, receives USDC)

┌──────────────────────────────────────────────────────────────────┐
│                  Governance Flow                                 │
└──────────────┬───────────────────────────────────────────────────┘
               │
               ▼
        ┌─────────────────┐
        │ Token Holder    │
        │  (Governance)   │
        └────────┬────────┘
                 │
          ┌──────┴──────────────────┐
          │                         │
          ▼                         ▼
    ┌──────────────┐        ┌────────────────┐
    │ Create       │        │ Vote on        │
    │ Proposal     │        │ Existing       │
    │              │        │ Proposal       │
    └──────┬───────┘        └────────┬───────┘
           │                        │
           ├─→ SVPGovernance        ├─→ Calculate voting power:
           │   .createProposal      │   power = balance × value / 1e18
           │   (description,        │
           │    actions)            ├─→ SVPGovernance
           │   ├─ Check proposer    │   .castVote(proposalId, support)
           │   │ voting power       │
           │   ├─ Create new state  ├─→ Accumulate votes
           │   ├─ Start 7-day vote  │
           │   └─ Emit: ProposalCreated
           │
           └─→ After 7 days
               │
               ├─→ Check quorum (20% participation)
               │
               ├─ IF quorum met AND for > against:
               │   ├─→ Move to QUEUED state
               │   ├─→ Start 2-day timelock
               │   └─→ Emit: ProposalQueued
               │
               └─ AFTER timelock expires:
                   ├─→ SVPGovernance.executeProposal()
                   ├─→ Call target contract with actions
                   ├─→ Update protocol parameters
                   └─→ Emit: ProposalExecuted
```

### 11.2 Cross-Contract Call Sequence

**Scenario: Valuation Update triggers Voting Power Change**

```
Timeline:
---------

T=0 (Asset Initial State)
  Asset: 1,000 shares issued
  Intrinsic Value: $100/share = $100,000 total
  Token Holder A: 100 shares
  Voting Power A: 100 × 100,000 / 1e18 ≈ 0.0001

T+1 hour (Financial Data Updated)
  Reporter calls SVPReporter.submitFinancialData()
  → Stored in SVPValuationEngine.financials[asset]
  
T+2 hours (Admin Calculates New Value)
  Admin calls SVPValuationEngine.calculateIntrinsicValue(asset)
  → New intrinsic value: $150/share = $150,000 total
  → Event emitted: IntrinsicValueCalculated(asset, 150000)
  
T+3 hours (Frontend Refreshes)
  Frontend reads SVPGovernance.getVotingPower(holderA)
  → tokenBalance = 100
  → intrinsicValue = 150,000 (from contract)
  → votingPower = 100 × 150,000 / 1e18 = 0.00015
  → Display updated voting power (+50%)

T+4 hours (Governance Vote Affected)
  Proposal requires 50,000 voting power to pass
  Old requirement: ~334 holders with 100 shares each
  New requirement: ~223 holders with 100 shares each
  → Voting power more concentrated due to value appreciation
```

---

## 12. Modular Valuation Engine Design (Core Innovation)

### 12.1 Valuation Module System

The SVP Protocol allows **pluggable valuation algorithms** without upgrading the core contract.

**Base Module (included):**
```solidity
contract SVPValuationModuleBasic is IValuationModule {
    function compute(address asset, FinancialData calldata data) 
        external pure returns (uint256) 
    {
        // Basic formula:
        // Value = NetAssets + RevenueValue
    }
}
```

**Advanced Module Example (future):**
```solidity
contract SVPValuationModuleDCF is IValuationModule {
    // Discounted Cash Flow model
    function compute(address asset, FinancialData calldata data) 
        external pure returns (uint256) 
    {
        // DCF formula:
        // Value = SUM(FCF_t / (1 + discount_rate)^t) + TerminalValue
    }
}
```

**Process to Upgrade:**
1. Deploy new module contract
2. Governance votes: `updateValuationModule(newModuleAddress)`
3. Core engine switches reference
4. All future valuations use new formula
5. Historical values can be recalculated if needed

---

## Summary Table: Contract Responsibilities

| Contract | Primary Function | Dependencies | Upgrade Path |
|----------|------------------|--------------|--------------|
| **SVPValuationEngine** | Compute intrinsic value | Financial data | UUPS Proxy |
| **SVPAssetRegistry** | Register assets | None | Admin upgrade |
| **SVPToken** | ERC-20 token | Valuation engine | ERC-1400 path |
| **SVPGovernance** | Value-weighted voting | Valuation + Token | Governance votes |
| **SVPSPVVault** | Capital pooling | Token | New vault deploy |
| **SVPDividendDistributor** | Revenue distribution | Token + Valuation | Admin upgrade |
| **SVPReporter** | Data validation | Asset registry + Valuation | Admin upgrade |
| **SVPAccessControl** | RBAC management | None | Immutable |

---

## Deployment Architecture (Robinhood Chain Testnet)

```
Contract Address Registry:
──────────────────────────
SVPProxy (UUPS)         → 0x1111...
SVPValuationEngine      → 0x2222... (implementation)
SVPAssetRegistry        → 0x3333...
SVPToken               → 0x4444...
SVPGovernance          → 0x5555...
SVPSPVVault            → 0x6666...
SVPDividendDistributor → 0x7777...
SVPReporter            → 0x8888...
SVPFactory             → 0x9999...
SVPAccessControl       → 0xAAAA...

Multisig Admin          → 3-of-5
Emergency Controller   → 1-of-3
Governance Timelock    → 2-day delay
```

---

## Conclusion

This specification provides the **complete architecture** for SVP Protocol:

✅ **On-Chain Valuation**: Oracle-free, formula-based  
✅ **Value-Weighted Governance**: Power scales with asset value  
✅ **Modular Upgradeable Design**: Future-proof  
✅ **Security-First**: RBAC, timelocks, multisigs  
✅ **Capital Pooling**: ERC-4626 vaults for SPVs  
✅ **Automated Distribution**: Dividend routing  
✅ **Developer-Ready**: SDK, indexer, backend  

The following phases will implement each component with production-grade Solidity, comprehensive testing, and deployment tooling.
