# SVP Protocol SDK

A TypeScript/JavaScript SDK for interacting with the SVP Protocol smart contracts. Provides contract methods, event listeners, and utility functions for dApps and integration partners.

## Features
- Type-safe contract wrappers (Governance, Vault, Token, Dividend)
- Event listeners and query helpers
- Utility functions for formatting, validation, and parsing
- Ethers.js v5 compatible
- Full TypeScript support

## Usage
```ts
import { SVPProtocol } from 'svp-sdk';
const svp = new SVPProtocol(providerOrSigner, config);
const proposals = await svp.governance.getProposals();
```

## Installation
```
npm install svp-sdk
```

## Documentation
- [API Reference](./docs/API.md)
- [Examples](./examples/)

## License
MIT
