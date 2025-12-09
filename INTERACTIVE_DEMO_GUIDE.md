# Carbon Credits ERC6551 Interactive Demo Guide

This guide explains how to use the interactive demo scripts to explore the Carbon Credits ERC6551 system using `cast` commands.

## 📋 Prerequisites

### 1. Environment Setup
```bash
# Required environment variables
export PRIVATE_KEY=0x1234...  # Your wallet private key
export RPC_URL=http://localhost:8545  # Your RPC endpoint

# Contract addresses (set after deployment)
export CARBON_PROJECT_NFT=0x...
export CARBON_BATCH_NFT=0x...
export BATCH_CONTROLLER=0x...
export ERC6551_REGISTRY=0x...
```

### 2. Required Tools
- `foundry` (forge, cast, anvil)
- `bc` (for decimal calculations)
- `xxd` (for hex decoding)

##  Running the Demo

### Option 1: Interactive Mode (Recommended for Learning)
```bash
./interactive_carbon_erc6551_demo.sh --interactive
```
- Pauses between each step
- Explains each command before execution
- Shows human-readable translations of responses
- Perfect for understanding the workflow

### Option 2: Automatic Mode
```bash
./interactive_carbon_erc6551_demo.sh
```
- Runs all commands automatically
- Good for testing or automation
- Still shows explanations and translations

### Option 3: Help
```bash
./interactive_carbon_erc6551_demo.sh --help
```

##  Understanding Responses

### Using the Response Decoder
```bash
# Explain common response patterns
./decode_responses.sh explain-patterns

# Explain a specific command
./decode_responses.sh explain-command "cast call Contract \"ownerOf(uint256)\" 1"

# Decode specific response types
./decode_responses.sh decode-address 0x000000000000000000000000742d35cc6634c0532925a3b8d
./decode_responses.sh decode-bool 0x0000000000000000000000000000000000000000000000000000000000000001
./decode_responses.sh decode-balance 0x0000000000000000000000000000000000000de0b6b3a7640000
```

##  Demo Workflow Explained

### Step 1: Create Carbon Projects
**Command Pattern:**
```bash
cast send $CARBON_PROJECT_NFT "mintCarbonProject(...)" \
  $WALLET_ADDRESS \          # Recipient of the NFT
  $MOCK_PARCEL_NFT \        # Geographic parcel NFT address
  $parcel_id \              # Parcel ID number
  $MOCK_ERC20 \             # ERC20 token for redemption
  $carbon_amount \          # Number of carbon credits
  $WALLET_ADDRESS \         # Who gets tokens when redeemed
  "Reforestation" \         # Project type
  "VCS" \                   # Methodology (VCS, Gold Standard, etc.)
  "2024" \                  # Vintage year
  "https://metadata.com/1"  # Metadata URI
```

**Human Translation:** Creates a new carbon project NFT representing X carbon credits from a reforestation project, verified under VCS methodology for the 2024 vintage.

**Response:** Transaction hash that can be used with `cast receipt` to see details.

### Step 2: Check Project Ownership
**Command Pattern:**
```bash
cast call $CARBON_PROJECT_NFT "ownerOf(uint256)" $project_id
```

**Human Translation:** Returns the Ethereum address that currently owns the specified project NFT.

**Response Example:** `0x000000000000000000000000742d35cc6634c0532925a3b8d4c647578481b`
**Decoded:** `0x742d35cc6634c0532925a3b8d4c647578481b` (your wallet address)

### Step 3: Approve Batch Controller
**Command Pattern:**
```bash
cast send $CARBON_PROJECT_NFT "approve(address,uint256)" $BATCH_CONTROLLER $project_id
```

**Human Translation:** Gives permission to the batch controller contract to transfer the specified project NFT on your behalf.

**Response:** Transaction hash confirming the approval.

### Step 4: Create Batch with Projects
**Command Pattern:**
```bash
cast send $BATCH_CONTROLLER "createBatchWithProjects(string,string,string,uint256[],bool)" \
  "Reforestation" \                           # Batch type
  "2024" \                                   # Vintage
  "https://metadata.carbon.com/batch/1" \    # Batch metadata URI
  "[1,2,3,4,5]" \                           # Array of project IDs
  true                                       # Transfer to token-bound account
```

**Human Translation:** Creates a new batch NFT called "Reforestation 2024" containing projects 1-5, automatically transferring all projects to the batch's token-bound account.

**Response:** Transaction hash. The transaction creates:
1. A new batch NFT (ID: 1) owned by you
2. An ERC6551 token-bound account for the batch
3. Transfers all specified projects to the token-bound account

### Step 5: Verify Batch Creation
**Command Pattern:**
```bash
cast call $CARBON_BATCH_NFT "getBatchData(uint256)" 1
```

**Human Translation:** Returns all information about batch #1.

**Response:** Complex tuple containing:
- Batch type: "Reforestation"
- Vintage: "2024" 
- Total carbon amount: 15000 (sum of all projects)
- Project count: 5
- Token-bound account address
- Creation timestamp
- Finalized status: false
- Arrays of project contracts and IDs

### Step 6: Get Token-Bound Account
**Command Pattern:**
```bash
cast call $CARBON_BATCH_NFT "getTokenBoundAccount(uint256)" 1
```

**Human Translation:** Returns the address of the ERC6551 account that holds assets for batch #1.

**Response Example:** `0x000000000000000000000000a774b0955a157ec29afc000a90191200d3580d24`
**Decoded:** `0xa774b0955a157ec29afc000a90191200d3580d24` (token-bound account address)

### Step 7: Verify Project Transfer
**Command Pattern:**
```bash
cast call $CARBON_PROJECT_NFT "ownerOf(uint256)" 1
```

**Human Translation:** Check who now owns project #1 (should be the token-bound account).

**Response:** Should return the token-bound account address, proving the transfer worked.

### Step 8: Execute Through Token-Bound Account
**Command Pattern:**
```bash
cast send $CARBON_BATCH_NFT "executeFromAccount(uint256,address,uint256,bytes)" \
  1 \                                    # Batch ID
  $CARBON_PROJECT_NFT \                  # Target contract
  0 \                                    # ETH value to send
  $PROJECT_CHECK_DATA                    # Encoded function call
```

**Human Translation:** Execute a function call through the token-bound account of batch #1, calling the project NFT contract to check if a project is redeemable.

**Response:** Transaction hash + return data from the executed call.

### Step 9: Redeem Projects
**Command Pattern:**
```bash
cast send $BATCH_CONTROLLER "redeemProjectsFromBatch(uint256,uint256[])" \
  1 \        # Batch ID
  "[1,2]"    # Array of project IDs to redeem
```

**Human Translation:** Mark projects 1 and 2 as redeemed (converted to carbon credits) through the batch system.

**Response:** Transaction hash confirming the redemption.

### Step 10: Finalize Batch
**Command Pattern:**
```bash
cast send $CARBON_BATCH_NFT "finalizeBatch(uint256)" 1
```

**Human Translation:** Lock batch #1 so no more projects can be added to it.

**Response:** Transaction hash confirming finalization.

##  Key ERC6551 Concepts Demonstrated

### Token-Bound Accounts
- Each batch NFT automatically gets its own Ethereum account
- This account can hold other NFTs (the carbon projects)
- The account is controlled by whoever owns the batch NFT
- Enables unified management of multiple related assets

### Batch Operations
- Instead of managing 5 separate project NFTs, you manage 1 batch NFT
- Operations can be performed on all projects at once
- Reduces gas costs and complexity
- Enables new business models and workflows

### Asset Ownership Hierarchy
```
You (EOA)
├─ Batch NFT #1
│  └─ Token-Bound Account
│     ├─ Project NFT #1 (1000 credits)
│     ├─ Project NFT #2 (2000 credits)
│     ├─ Project NFT #3 (3000 credits)
│     ├─ Project NFT #4 (4000 credits)
│     └─ Project NFT #5 (5000 credits)
```

## 🔧 Troubleshooting

### Common Issues

1. **"Insufficient batch creation fee"**
   - Solution: The batch controller has a creation fee set. Add `--value 100000000000000000` (0.1 ETH) to the createBatchWithProjects call.

2. **"Not owner of project"**
   - Solution: Make sure you own the projects you're trying to batch.

3. **"ERC721: caller is not token owner or approved"**
   - Solution: Approve the batch controller first using the `approve` function.

4. **"Project already in a batch"**
   - Solution: Each project can only be in one batch. Use different project IDs.

### Useful Debugging Commands

```bash
# Check your wallet balance
cast balance $WALLET_ADDRESS --rpc-url $RPC_URL

# Check if controller is approved for a project
cast call $CARBON_PROJECT_NFT "getApproved(uint256)" 1 --rpc-url $RPC_URL

# Check project redeemability
cast call $CARBON_PROJECT_NFT "isProjectRedeemable(uint256)" 1 --rpc-url $RPC_URL

# Get transaction receipt
cast receipt 0x[transaction-hash] --rpc-url $RPC_URL

# Check token-bound account balance
cast balance $TBA_ADDRESS --rpc-url $RPC_URL
```

##  Advanced Usage

### Custom Commands
You can extend the demo by running your own cast commands:

```bash
# Send ETH to a token-bound account
cast send $TBA_ADDRESS --value 1000000000000000000 --private-key $PRIVATE_KEY --rpc-url $RPC_URL

# Check batch controller settings
cast call $BATCH_CONTROLLER "batchCreationFee()" --rpc-url $RPC_URL
cast call $BATCH_CONTROLLER "minProjectsPerBatch(string)" "Reforestation" --rpc-url $RPC_URL

# Create a different type of batch
cast send $BATCH_CONTROLLER "createBatchWithProjects(string,string,string,uint256[],bool)" \
  "Renewable Energy" "2024" "https://metadata.com/batch/2" "[6,7,8]" true \
  --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

### Integration with Other Tools
- Use `cast logs` to watch for specific events
- Use `cast 4byte` to decode function selectors
- Use `cast abi-encode` to prepare complex call data
- Use `cast to-wei` and `cast from-wei` for ETH conversions

This comprehensive demo showcases the power of ERC6551 token-bound accounts for managing carbon credit portfolios!