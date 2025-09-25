# DLLM Smart Contract - Solidity Version

This is the Solidity/EVM version of the Decentralized LLM Inference Smart Contract, converted from the original Move implementation.

## Overview

The DLLM (Decentralized LLM) smart contract enables decentralized inference sessions where:
- Session owners can create inference sessions with specified parameters
- Authorized addresses can claim tokens based on their computational contributions
- Rewards are distributed based on the number of layers processed and tokens generated
- All interactions are secured through cryptographic signatures

## Features

- **Session Management**: Create and manage inference sessions with multiple participants
- **Token-based Rewards**: Distribute ERC20 tokens as rewards for inference work
- **Signature Verification**: Secure token claiming through cryptographic signatures
- **Multi-layer Support**: Different reward rates based on computational layers
- **Reentrancy Protection**: Built-in security against reentrancy attacks

## Contract Architecture

### Main Contracts

1. **DLLM.sol**: Main contract handling sessions and token distribution
2. **MockToken.sol**: ERC20 token for testing purposes

### Key Functions

#### Session Management
- `createSession()`: Create a new inference session
- `getSession()`: View session details
- `hasSession()`: Check if session exists

#### Token Operations  
- `deposit()`: Deposit tokens to reward pool
- `claimTokens()`: Claim rewards with signature verification
- `getBalance()`: Check reward pool balance

## Setup Instructions

### Prerequisites

- Node.js (v16 or later)
- npm or yarn
- Git

### Installation

1. **Navigate to the Solidity directory:**
   ```bash
   cd solidity
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Set up environment variables:**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

### Development Commands

```bash
# Compile contracts
npm run compile

# Run tests
npm run test

# Start local Hardhat node
npm run node

# Deploy contracts (to local network)
npm run deploy

# Deploy to specific network
npx hardhat run scripts/deploy.js --network sepolia
```

## Testing

The test suite covers:
- Contract deployment
- Token deposits and withdrawals
- Session creation and management
- Token claiming with signature verification
- Error handling and edge cases

Run tests with:
```bash
npm test
```

## Deployment

### Local Development

1. Start local Hardhat node:
   ```bash
   npx hardhat node
   ```

2. Deploy contracts:
   ```bash
   npx hardhat run scripts/deploy.js --network localhost
   ```

### Testnet Deployment

1. Configure network in `hardhat.config.js`
2. Set environment variables in `.env`
3. Deploy:
   ```bash
   npx hardhat run scripts/deploy.js --network sepolia
   ```

### Mainnet Deployment

⚠️ **Warning**: Thoroughly test on testnets before mainnet deployment.

1. Configure mainnet settings
2. Ensure sufficient ETH for gas fees
3. Deploy with production settings

## Usage Examples

### Creating a Session

```javascript
const sessionId = 1;
const maxTokens = 100;
const addresses = ["0x123...", "0x456..."];
const layers = [10, 15];
const clientPublicKey = "0x789...";

await dllm.createSession(
  sessionId,
  maxTokens, 
  addresses,
  layers,
  clientPublicKey
);
```

### Claiming Tokens

```javascript
const tokenCount = 5;
const messageHash = ethers.solidityPackedKeccak256(["uint256"], [tokenCount]);
const signature = await wallet.signMessage(ethers.getBytes(messageHash));

await dllm.claimTokens(
  ownerAddress,
  sessionId,
  tokenCount,
  signature
);
```

## Key Differences from Move Version

### Signature Handling
- Move uses Ed25519 signatures
- Solidity version uses ECDSA (secp256k1) signatures compatible with Ethereum

### Storage Model
- Move uses object-based storage
- Solidity uses mapping-based storage with deterministic session IDs

### Token System
- Move integrates with Aptos Coin
- Solidity version uses configurable ERC20 tokens

### Error Handling
- Move uses custom error codes
- Solidity uses custom errors and require statements

## Security Considerations

- **Reentrancy Protection**: All external calls protected with `nonReentrant` modifier
- **Access Control**: Session ownership and claiming permissions enforced
- **Signature Verification**: All claims must be cryptographically signed
- **Integer Overflow**: Using Solidity 0.8+ for automatic overflow protection

## Gas Optimization

- Efficient storage patterns
- Minimal external calls
- Optimized loops and operations
- Gas-efficient signature verification

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## License

MIT License - see LICENSE file for details

## Support

For questions and support:
- Open an issue on GitHub
- Check the documentation
- Review test files for usage examples