# SVP Protocol - Testnet Deployment Guide

## ✅ Local Deployment Complete (Hardhat)

Successfully deployed 11 core contracts to local Hardhat network:

### Deployed Contracts

| Contract | Address |
|----------|---------|
| SVPAccessControl | 0x5FbDB2315678afecb367f032d93F642f64180aa3 |
| SVPValuationEngine | 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 |
| SVPAssetRegistry | 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 |
| SVPToken | 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 |
| SVPToken1400 | 0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9 |
| SVPGovernanceEnhanced | 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707 |
| SVPDividendDistributor | 0x0165878A594ca255338adfa4d48449f69242Eb8F |
| SVPReporter | 0xa513E6E4b8f2a923D98304ec87F64353C4D5C853 |
| SVPSPVVault | 0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6 |
| SVPFactory | 0x8A791620dd6260079BF849Dc5567aDC3F2FdC318 |
| Timelock | 0x610178dA211FEF7D417bC0e6FeD39F05609AD788 |

## 🚀 Testnet Deployment

### Arbitrum Sepolia (421614)
**Status**: ⏳ Network Issues - Currently experiencing connection timeouts

**RPC**: https://sepolia-rollup.arbitrum.io/rpc
**Block Explorer**: https://sepolia.arbiscan.io/

**To Deploy (when network is stable):**
```bash
cd svp-protocol
npx hardhat run scripts/deployTestnet.ts --network arbitrumSepolia
```

### Robinhood Testnet (46630)
**Status**: ⏳ Network Issues - Currently experiencing TLS/connection reset errors

**RPC**: https://testnet.rpc.robinhoodchain.com
**Block Explorer**: https://testnet.explorer.robinhoodchain.com/

**To Deploy (when network is stable):**
```bash
cd svp-protocol
npx hardhat run scripts/deployTestnet.ts --network robinhoodChain
```

## 📋 Deployment Process

### Prerequisites
1. Private key with sufficient testnet funds
2. Network RPC configured in `.env`
3. All contracts compiled: `npm run compile`

### Automatic Deployment
The deployment script (`deployTestnet.ts`) will:
1. ✅ Deploy all 11 core contracts in sequence
2. ✅ Verify each deployment with console output
3. ✅ Save deployment records to `deployments/` folder with timestamps
4. ✅ Create `hardhat-latest.json` for quick reference

### Deployment Records
Located in `./deployments/` folder:
- `arbitrumSepolia-YYYY-MM-DD-HH-MM-SS.json` - Timestamped records
- `arbitrumSepolia-latest.json` - Current deployment
- `robinhoodChain-YYYY-MM-DD-HH-MM-SS.json` - Timestamped records
- `robinhoodChain-latest.json` - Current deployment
- `hardhat-latest.json` - Local deployment reference

## 🔧 Manual Contract Interaction

After deployment, interact with contracts:

```typescript
// Example: SVPToken
const token = await ethers.getContractAt(
  "SVPToken",
  "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9"
);

// Check total supply
const supply = await token.totalSupply();
console.log("Total Supply:", ethers.utils.formatEther(supply));

// Check balance
const balance = await token.balanceOf(deployer.address);
console.log("Deployer Balance:", ethers.utils.formatEther(balance));
```

## ⚠️ Network Status Notes

### Current Issues
- **Arbitrum Sepolia**: Connection timeouts (RPC overload or temporary outage)
- **Robinhood Testnet**: TLS/ECONNRESET errors (network instability)

### Recommended Action
1. Wait 30-60 minutes for network recovery
2. Check network status:
   - Arbitrum: https://status.arbitrum.io/
   - Robinhood: https://testnet.explorer.robinhoodchain.com/
3. Verify RPC endpoints are correct in `.env`
4. Try deployment again with: `npm run deploy:<network>`

## 🧪 Testing Deployment

After successful testnet deployment, run tests:

```bash
cd svp-protocol

# Run all tests
npm test

# Run specific test file
npm test -- test/SVPProtocol.test.ts

# Run with gas reporting
REPORT_GAS=true npm test
```

## 📊 Deployment Statistics

### Local Hardhat (✅ Complete)
- Total Contracts: 11
- Deployment Time: ~10 seconds
- All tests passing: ✅
- Gas optimization: IR-enabled (Solidity 0.8.20)

### Expected Testnet Stats
- Estimated deployment time: 2-5 minutes per network
- Gas costs: ~500-1000 USD equivalent (estimated)
- Confirmation time: 30 seconds - 2 minutes per network

## 🔐 Security Considerations

1. **Private Keys**: Stored in `.env` (not committed to git)
2. **Testnet Usage**: Only for testing, never use production keys
3. **Contract Verification**: Run `npm run verify:<network>` after deployment
4. **Timelock**: Protects governance with 2-day delay

## 📞 Support

For deployment issues:
1. Check network status pages (links above)
2. Verify `.env` configuration
3. Ensure sufficient testnet balance
4. Review deployment logs in console output
5. Check contract compilation: `npm run compile`

---

**Last Updated**: 2026-02-23
**Deployment Script**: `scripts/deployTestnet.ts`
**Status**: Ready for testnet deployment when networks stabilize
