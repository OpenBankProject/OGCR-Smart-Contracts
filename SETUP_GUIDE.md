# Quick Setup Guide

## Prerequisites
- [Foundry](https://getfoundry.sh/) installed
- A wallet with some ETH for testing

## Setup Steps

### 1. Environment Configuration
```bash
# Copy the example environment file
cp .env.example .env

# Edit .env with your values
nano .env
```

Required values in `.env`:
- `PRIVATE_KEY`: Your wallet's private key (without 0x prefix)
- `RPC_URL`: Your blockchain RPC endpoint

### 2. Start Local Blockchain (Optional)
If testing locally:
```bash
# Start Anvil local testnet
anvil
```
This will give you test accounts with ETH.

### 3. Deploy the System
```bash
# Compile contracts
forge build

# Deploy to your chosen network
forge script script/DeployCarbonERC6551System.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

### 4. Run Interactive Demo
```bash
# Make the demo script executable
chmod +x interactive_carbon_erc6551_demo.sh

# Run the interactive demo
./interactive_carbon_erc6551_demo.sh
```

## What You'll See
The demo will:
1. Deploy all contracts
2. Mint sample carbon project NFTs
3. Create batches with token-bound accounts
4. Demonstrate transferring projects to batch accounts
5. Show batch operations and redemption

Each step shows both the raw `cast` command and a human-readable explanation of what's happening.

## Troubleshooting
- If you get "command not found" errors, make sure Foundry is installed and in your PATH
- If transactions fail, check that your wallet has sufficient ETH
- If contracts aren't found, make sure deployment completed successfully

Enjoy exploring the ERC6551 carbon credit system! 🌱