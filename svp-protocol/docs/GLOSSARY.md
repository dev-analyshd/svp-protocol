# SVP Protocol - Glossary of Terms

---

## A

**Accredited Investor**
An investor who meets income or net worth thresholds defined by regulators, typically required for private securities investments.

**Admin Role**
Role with administrative privileges including parameter changes, role grants, and emergency controls.

**Asset Registry**
Smart contract that maintains registry of all tokenizable assets with their metadata and approval status.

**Asset Value**
Total value of an asset's resources, inventory, and holdings used in intrinsic valuation calculation.

---

## C

**Circuit Breaker**
Automatic halt mechanism triggered when valuation changes exceed threshold (default 50% change).

**Claim Record**
Historical record of dividends claimed by a user from a specific distribution.

**Compliance Hook**
Transfer hook that enforces compliance rules (whitelisting, restrictions) on token transfers.

**DCF (Discounted Cash Flow)**
Alternative valuation model using projected future cash flows discounted to present value.

---

## D

**Dividend**
Pro-rata share of protocol revenue distributed to token holders based on their holdings.

**Distributor Role**
Role authorized to deposit dividends and manage distribution parameters.

---

## E

**ERC-20**
Ethereum Request for Comment standard for fungible tokens with basic transfer functionality.

**ERC-1400**
Security token standard with partitioning, transfer restrictions, and compliance features.

**ERC-4626**
Vault standard defining deposit/withdraw interface for asset pooling contracts.

**ERC-1967**
Proxy pattern using storage slot for implementation address (used in UUPS).

---

## F

**Financial Data**
Asset metrics including revenue, growth rate, assets, liabilities, and risk factor.

**Flash Loan**
Uncollateralized loan that must be repaid within same transaction; protected against via snapshots.

**Frozen Account**
Account that cannot transfer or receive tokens due to compliance freeze.

---

## G

**Governance**
Decision-making process for protocol evolution, typically through voting by token holders.

**Growth Multiplier**
Calculation factor (1 + GrowthRate) used to apply growth rate to revenue in valuation.

**Growth Rate**
Annual growth rate as percentage (e.g., 0.2 = 20% annual growth).

---

## H

**Hardhat**
Ethereum development framework used for compiling, testing, and deploying contracts.

---

## I

**Intrinsic Value**
Fair value of asset calculated on-chain using formula: NetAssets + (Revenue × GrowthMultiplier) / RiskFactor

**Implementation**
Actual contract code that a proxy delegates to; can be upgraded in UUPS pattern.

---

## J

**Jurisdiction**
Geographic location/country where asset is registered, used for compliance tracking.

---

## K

**KYC (Know Your Customer)**
Process of verifying customer identity and assessing investment appropriateness.

---

## L

**Liabilities**
Total debts and obligations of asset, subtracted from assets to get net asset value.

**Liquidity**
Availability of capital for transactions; SPV manages via deposit/withdrawal redemption queue.

---

## M

**Manager Role**
Role authorized to manage SPV vault portfolio, open/close positions, and rebalance.

**Minter Role**
Role authorized to mint new tokens (usually assigned to Factory or protocol admin).

**Multisig**
Multi-signature wallet requiring multiple signatories to approve transactions (e.g., 3-of-5).

---

## N

**NAV (Net Asset Value)**
Per-share valuation of SPV vault calculated as: (Total Assets + Pending Dividends) / Total Shares

**Net Assets**
Calculated as: Max(0, Assets - Liabilities); represents net worth in valuation formula.

---

## O

**Oracle**
External data provider; SVP Protocol is oracle-free (no external dependencies).

---

## P

**Partition**
ERC-1400 concept of dividing tokens into classes with different rules (e.g., retail vs institutional).

**Performance Fee**
Fee charged on investment gains/profits, typically 20% of profits in SVP.

**Proposal**
Governance action submitted for community voting, containing targets, values, signatures, and calldata.

**Proposal State**
Stage of proposal (PENDING, ACTIVE, DEFEATED, SUCCEEDED, QUEUED, EXECUTED, CANCELED).

**Proxy**
Smart contract that delegates calls to implementation contract, enabling upgrades.

---

## Q

**Quorum**
Minimum participation percentage required for governance vote to be valid (default 20%).

---

## R

**Rate Limiting**
Mechanism to prevent spam by restricting frequency of actions (e.g., 1 proposal per day per account).

**Receipt**
Record of vote cast, including support choice, voting power, and timestamp.

**Redemption**
Process of converting SPV shares back to underlying stablecoin.

**Redemption Cooldown**
Minimum delay between requesting and executing redemption (default 1 day).

**Reporter**
Role responsible for submitting financial data for assets to valuation engine.

**Reporter Role**
Role authorized to submit financial data; must be registered and verified.

**Risk Factor**
Divisor in valuation formula accounting for asset riskiness; >1 reduces valuation (e.g., 1.5x = higher risk).

---

## S

**Snapshot**
Historical record of token balances at specific block height for voting purposes.

**Snapshot Role**
Role authorized to create voting snapshots.

**SPV (Special Purpose Vehicle)**
Legal/financial structure for pooling capital; in SVP, ERC-4626 vault acts as SPV.

**Stablecoin**
Cryptocurrency designed to maintain stable value (e.g., USDC, DAI, USDT).

**Supply Cap**
Maximum total token supply allowed; 0 = unlimited.

---

## T

**Tier Level**
Investor classification for compliance (0=retail, 1=accredited, 2=institutional).

**Timelock**
Delay period between proposal approval and execution; default 2 days for governance.

**Total Dividends**
Sum of all dividends deposited into distributor contract over time.

**Transfer Restriction**
Compliance mechanism preventing transfers for specific period or permanently.

---

## U

**UUPS (Universal Upgradeable Proxy Standard)**
Proxy pattern where upgrade function is in implementation; more secure than transparent proxy.

---

## V

**Validator**
Role authorized to approve or reject data submissions from reporters.

**Valuation Module**
Pluggable algorithm for calculating intrinsic value; allows switching formulas without core upgrade.

**Voting Power**
Token holder's influence in governance calculated as: Balance × IntrinsicValue / BASE_UNIT

---

## W

**Whitelist**
List of approved addresses allowed to hold tokens (when enforcement enabled).

**Whitelisting**
Process of adding address to whitelist with tier level and holding limits.

---

## X-Z

**Zero-Address**
Special address (0x0...0) used to represent null/empty state; transfers to it burn tokens.

---

## Acronyms & Abbreviations

| Acronym | Meaning |
|---------|---------|
| RBAC | Role-Based Access Control |
| RPC | Remote Procedure Call |
| ERC | Ethereum Request for Comment |
| UUPS | Universal Upgradeable Proxy Standard |
| SPV | Special Purpose Vehicle |
| NAV | Net Asset Value |
| KYC | Know Your Customer |
| AML | Anti-Money Laundering |
| DCF | Discounted Cash Flow |
| ETH | Ethereum |
| USDC | USD Coin (stablecoin) |
| DAI | DAI stablecoin |
| BPS | Basis Points (100 = 1%) |
| IPFS | InterPlanetary File System |
| DAO | Decentralized Autonomous Organization |
| MPC | Multi-Party Computation |
| ZK | Zero-Knowledge Proof |
| L2 | Layer 2 Scaling Solution |

---

## Contract Functions Quick Reference

### SVPValuationEngine
- `calculateIntrinsicValue()` - Compute asset valuation
- `submitFinancialData()` - Reporter submits data
- `approveFinancialData()` - Admin approves data

### SVPToken
- `mint()` - Create tokens
- `burn()` - Destroy tokens
- `freezeAccount()` - Prevent transfers
- `snapshot()` - Create voting snapshot

### SVPGovernance
- `getVotingPower()` - Calculate voting strength
- `createProposal()` - Submit proposal
- `castVote()` - Vote on proposal
- `executeProposal()` - Execute after timelock

### SVPSPVVault (ERC-4626)
- `deposit()` - Invest stablecoin
- `withdraw()` - Exit position
- `openPosition()` - Add asset to portfolio
- `closePosition()` - Remove asset
- `calculateNAV()` - Calculate share value

### SVPDividendDistributor
- `depositDividends()` - Add dividend pool
- `claimDividend()` - Claim specific distribution
- `getPendingDividends()` - Calculate pending amount

---

## Security Terms

**Reentrancy** - Attack where function calls back to itself before state updates; prevented with ReentrancyGuard.

**Overflow/Underflow** - Integer math wrap-around; prevented in Solidity 0.8+ with checked arithmetic.

**Access Control** - Permission system ensuring only authorized parties can call sensitive functions.

**Flash Loan** - Uncollateralized loan; protected via historical balance snapshots instead of current balance.

**Slippage** - Difference between expected and actual price; managed via price limits in trades.

---

## Economic Terms

**Intrinsic Value** - Fair market value based on fundamentals (assets, revenue, growth).

**Market Cap** - Total value of all tokens: price × supply.

**Yield** - Return on investment as percentage; in SVP, dividends provide yield to holders.

**Liquidity** - Ease of buying/selling; higher liquidity = easier to trade.

**Volatility** - Price fluctuation magnitude; higher volatility = riskier.

---

## References

- [SVP Technical Specification](./TECHNICAL_SPECIFICATION.md)
- [SVP README](./README.md)
- [Completion Summary](./COMPLETION_SUMMARY.md)
- [Solidity Documentation](https://docs.soliditylang.org/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [ERC Standards](https://eips.ethereum.org/)

---

**Last Updated:** February 19, 2026  
**Version:** 1.0.0
