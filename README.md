# OGCR-Smart-Contracts 
Smart Contracts for OGCR DCR
##  System Architecture

```
Individual Carbon Projects (ERC721)
        ↓ 
Batch NFTs with Token-Bound Accounts (ERC6551)
```

### Core Contracts

- **`CarbonProjectNFT`** - Individual carbon projects (reforestation, renewable energy, etc.)
- **`CarbonBatchNFT`** - Batch NFTs that own multiple projects via ERC6551
- **`CarbonERC6551Account`** - Token-bound account implementation
- **`CarbonERC6551Registry`** - Registry for creating accounts
- **`CarbonBatchController`** - Orchestration and batch operations

##  Quick Start

### Prerequisites

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Clone and setup
git clone <repo-url>
cd carbon-credits
forge install
```

### Environment Setup

```bash
# Copy environment template
cp .env.example .env

# Edit with your values
nano .env
```

Required in `.env`:
```bash
PRIVATE_KEY=your_wallet_private_key
RPC_URL=your_blockchain_rpc_endpoint
```

###  Interactive Demo

Experience the complete ERC6551 workflow:

```bash
# Run interactive demonstration
./erc6551_demo.sh
```

This demo shows:
1.  Minting individual carbon project NFTs
2.  Creating batch NFTs with token-bound accounts  
3.  Transferring projects into batch accounts
4.  Portfolio management operations
5.  ERC6551 account functionality

##  Manual Operations

### Deploy Contracts

```bash
forge script script/DeployCarbonERC6551System.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast
```

### Create Carbon Projects

```bash
cast send $CARBON_PROJECT_NFT \
  "mintCarbonProject(address,address,uint256,address,uint256,address,string,string,string,string)" \
  $RECIPIENT \
  $PARCEL_CONTRACT \
  $PARCEL_ID \
  $ERC20_TOKEN \
  $CARBON_AMOUNT \
  $TOKEN_RECIPIENT \
  "Reforestation" \
  "VCS" \
  "2024" \
  "https://metadata.example.com/project1" \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy
```

### Create Carbon Batch

```bash
cast send $CARBON_BATCH_NFT \
  "createBatch(string,string)" \
  "Renewable Energy Portfolio Q1 2025" \
  "https://metadata.example.com/batch1" \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy
```

### Transfer Projects to Batch

```bash
# Approve batch to transfer project
cast send $CARBON_PROJECT_NFT \
  "approve(address,uint256)" \
  $CARBON_BATCH_NFT \
  $PROJECT_ID \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy

# Transfer to batch's token-bound account
cast send $CARBON_BATCH_NFT \
  "transferProjectToAccount(uint256,uint256)" \
  $PROJECT_ID \
  $BATCH_ID \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --legacy
```

##  Testing

Run the comprehensive test suite:

```bash
forge test
```

**Test Coverage:**
-  Contract deployment
-  Carbon project creation
-  ERC6551 account functionality  
-  Batch operations
-  Access control
-  Portfolio management
-  Token transfers

##  Development

### Build

```bash
forge build
```


### Local Development

```bash

# Deploy to local network
forge script script/DeployCarbonERC6551System.s.sol \
  --rpc-url http://localhost:8545 \
  --private-key 0xyourprivatekey \
  --broadcast
```

##  Documentation

- **[ERC6551_README.md](ERC6551_README.md)** - Technical documentation
- **[INTERACTIVE_DEMO_GUIDE.md](INTERACTIVE_DEMO_GUIDE.md)** - Demo usage guide
- **[SETUP_GUIDE.md](SETUP_GUIDE.md)** - Quick setup instructions


## 🔧 Contract Addresses

After deployment, update your `.env` with the contract addresses:

```bash
CARBON_PROJECT_NFT=0x...
CARBON_BATCH_NFT=0x...
ERC6551_REGISTRY=0x...
BATCH_CONTROLLER=0x...
ERC6551_ACCOUNT_IMPL=0x...
```

##  Links

- **[ERC6551 Standard](https://eips.ethereum.org/EIPS/eip-6551)** - Token Bound Accounts
- **[OpenZeppelin](https://openzeppelin.com/)** - Smart contract framework

---
