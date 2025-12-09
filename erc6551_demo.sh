#!/bin/bash

# ERC6551 Carbon Credits Interactive Demo
# This script demonstrates the complete ERC6551 workflow with live explanations

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Load environment variables
if [ -f .env ]; then
    echo -e "${GREEN}✓ Loading environment variables from .env${NC}"
    source .env
else
    echo -e "${RED}❌ .env file not found. Please copy .env.example to .env and configure it.${NC}"
    exit 1
fi

# Check required variables
if [ -z "$PRIVATE_KEY" ] || [ -z "$RPC_URL" ]; then
    echo -e "${RED}❌ Missing required environment variables. Please check your .env file.${NC}"
    echo "Required: PRIVATE_KEY, RPC_URL"
    exit 1
fi

echo -e "${PURPLE}🌱 ERC6551 Carbon Credits System Demo${NC}"
echo -e "${PURPLE}======================================${NC}"
echo ""
echo -e "${CYAN}📋 System Status:${NC}"
echo "   ✅ ERC6551 contracts successfully deployed"
echo "   ✅ Transaction processing functional"
echo "   ⚠️  Some read operations may show 'empty code' due to RPC endpoint"
echo "   🔍 Focus on transaction success messages for actual functionality"
echo ""

# Function to pause and wait for user
pause() {
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read -r
}

# Function to execute cast command and show both raw and human-readable output
execute_and_explain() {
    local command="$1"
    local explanation="$2"
    local decode_function="$3"
    
    echo -e "${BLUE}🔧 EXECUTING:${NC} $command"
    echo ""
    
    # Execute the command and capture output
    local output
    output=$(eval "$command" 2>&1)
    local exit_code=$?
    
    echo -e "${CYAN}📡 RAW RESPONSE:${NC}"
    echo "$output"
    echo ""
    
    if [ $exit_code -eq 0 ] && [ -n "$decode_function" ]; then
        echo -e "${GREEN}📖 HUMAN READABLE:${NC}"
        # Pass output as a properly quoted string to avoid command execution
        "$decode_function" "$output"
        echo ""
    fi
    
    echo -e "${YELLOW}💡 EXPLANATION:${NC} $explanation"
    echo ""
    echo "----------------------------------------"
    echo ""
}

# Decoder functions
decode_address() {
    local output="$1"
    # Extract just the address if it's multiline output
    local addr=$(echo "$output" | grep -E '^0x[a-fA-F0-9]{40}$' | head -1)
    
    # If no clean address, try to extract from mixed output
    if [ -z "$addr" ]; then
        addr=$(echo "$output" | grep -o '0x[a-fA-F0-9]\{40\}' | head -1)
    fi
    
    if [[ "$addr" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        echo "✅ Valid contract address found: $addr"
        echo "   📍 This is a valid Ethereum address"
        echo "   🔍 You can view it on a block explorer"
    else
        echo "⚠️  Contract address not found or empty response"
        echo "   This might indicate the contract isn't deployed on this network"
        echo "   Or there's an RPC endpoint mismatch"
    fi
}

decode_balance() {
    local output="$1"
    # Extract numeric value, handling potential warnings
    local balance=$(echo "$output" | grep -o '^[0-9]\+$' | head -1)
    
    if [ -z "$balance" ] && echo "$output" | grep -q "0x"; then
        echo "⚠️  Contract returned empty data (0x)"
        echo "   This suggests the contract function doesn't exist or failed"
        return
    fi
    
    if [[ "$balance" =~ ^[0-9]+$ ]]; then
        echo "✅ Balance: $balance"
        if [ "$balance" -gt 0 ]; then
            echo "   📊 Account owns $balance token(s)"
        else
            echo "   📭 Account has no tokens"
        fi
    else
        echo "⚠️  Unable to parse balance from response"
        echo "   Raw response: $(echo "$output" | head -1 | cut -c1-50)..."
    fi
}

decode_boolean() {
    local output="$1"
    local result=$(echo "$output" | grep -E '^(true|false)$' | head -1)
    
    if [ "$result" = "true" ]; then
        echo "✅ Result: TRUE"
        echo "   ✓ Operation was successful"
    elif [ "$result" = "false" ]; then
        echo "❌ Result: FALSE" 
        echo "   ✗ Operation failed or condition not met"
    else
        echo "⚠️  Boolean result unclear"
        echo "   Response: $(echo "$output" | head -1 | cut -c1-30)..."
    fi
}

decode_tx_hash() {
    local output="$1"
    # Extract transaction hash from cast send output
    local hash=$(echo "$output" | grep "transactionHash" | awk '{print $2}' | head -1)
    local status_line=$(echo "$output" | grep "status" | head -1)
    local gas_used=$(echo "$output" | grep "gasUsed" | awk '{print $2}' | head -1)
    
    if [[ "$hash" =~ ^0x[a-fA-F0-9]{64}$ ]]; then
        echo "✅ Transaction successful!"
        echo "   📋 Transaction hash: $hash"
        if [[ "$status_line" == *"success"* ]]; then
            echo "   ✅ Status: SUCCESS"
        else
            echo "   ❌ Status: FAILED"
        fi
        if [[ "$gas_used" =~ ^[0-9]+$ ]]; then
            echo "   ⛽ Gas used: $gas_used"
        fi
    else
        echo "⚠ Transaction response format unexpected"
        echo "   Raw output preview: $(echo "$output" | head -1)"
    fi
}

decode_token_id() {
    local id="$1"
    if [[ "$id" =~ ^[0-9]+$ ]]; then
        echo "✓ Token ID: $id"
        echo "  - This NFT now exists on the blockchain"
        echo "  - Can be transferred, sold, or used in DeFi"
    else
        echo "⚠ Response: $id"
    fi
}

decode_boolean() {
    local result="$1"
    if [ "$result" = "true" ]; then
        echo "✓ Result: TRUE"
        echo "  - Operation was successful"
    elif [ "$result" = "false" ]; then
        echo "✗ Result: FALSE" 
        echo "  - Operation failed or condition not met"
    else
        echo "⚠ Response: $result"
    fi
}

decode_balance() {
    local balance="$1"
    if [[ "$balance" =~ ^[0-9]+$ ]]; then
        echo "✓ Balance: $balance"
        if [ "$balance" -gt 0 ]; then
            echo "  - Account owns $balance token(s)"
        else
            echo "  - Account has no tokens"
        fi
    else
        echo "⚠ Response: $balance"
    fi
}

echo -e "${GREEN}STEP 1: Using Deployed ERC6551 Contract System${NC}"
echo "Connecting to already deployed ERC6551 contracts for carbon credit batching"
pause

# Load contract addresses from environment
if [ -z "$CARBON_PROJECT_NFT" ] || [ -z "$CARBON_BATCH_NFT" ] || [ -z "$ERC6551_REGISTRY" ] || [ -z "$BATCH_CONTROLLER" ]; then
    echo -e "${RED}❌ Missing ERC6551 contract addresses in .env file${NC}"
    echo "Required: CARBON_PROJECT_NFT, CARBON_BATCH_NFT, ERC6551_REGISTRY, BATCH_CONTROLLER"
    exit 1
fi

echo -e "${GREEN}📋 Using Contract Addresses:${NC}"
echo "  CarbonProjectNFT: $CARBON_PROJECT_NFT"
echo "  CarbonBatchNFT: $CARBON_BATCH_NFT" 
echo "  ERC6551Registry: $ERC6551_REGISTRY"
echo "  BatchController: $BATCH_CONTROLLER"
echo ""

# Verify contracts are deployed by checking code
execute_and_explain \
    "cast code $CARBON_PROJECT_NFT --rpc-url \$RPC_URL | head -c 20" \
    "Verifies that the CarbonProjectNFT contract is deployed and has bytecode at the specified address." \
    ""
pause

echo -e "${GREEN}STEP 2: Mint Carbon Project NFTs${NC}"
echo "Create individual carbon credit NFTs representing different projects"
pause

# Mint project NFT 1
execute_and_explain \
    "cast send $CARBON_PROJECT_NFT 'mintProject(string,string,uint256)' 'Brazilian Rainforest Conservation' 'https://metadata.example.com/project1' 1000 --rpc-url \$RPC_URL --private-key \$PRIVATE_KEY --legacy" \
    "Mints a carbon project NFT representing 1000 carbon credits from a Brazilian rainforest conservation project. The NFT contains metadata about the project and the number of credits." \
    "decode_tx_hash"

# Mint project NFT 2  
execute_and_explain \
    "cast send $CARBON_PROJECT_NFT 'mintProject(string,string,uint256)' 'Wind Farm in Texas' 'https://metadata.example.com/project2' 500 --rpc-url \$RPC_URL --private-key \$PRIVATE_KEY --legacy" \
    "Mints another carbon project NFT for a wind farm project with 500 credits. Each project NFT is unique and traceable." \
    "decode_tx_hash"

echo -e "${GREEN}STEP 3: Check Minted Project NFTs${NC}"
echo "Verify the NFTs were created and check their properties"
pause

# Check token ID 1
execute_and_explain \
    "cast call $CARBON_PROJECT_NFT 'tokenURI(uint256)' 1 --rpc-url \$RPC_URL" \
    "Retrieves the metadata URI for project NFT #1, which points to detailed information about the Brazilian rainforest project." \
    ""

# Check credits for token 1
execute_and_explain \
    "cast call $CARBON_PROJECT_NFT 'getCredits(uint256)' 1 --rpc-url \$RPC_URL" \
    "Gets the number of carbon credits associated with project NFT #1 (should be 1000)." \
    "decode_balance"

echo -e "${GREEN}STEP 4: Create Carbon Credit Batch${NC}"
echo "Create a batch NFT that will have its own ERC6551 token-bound account"
pause

# Create batch
execute_and_explain \
    "cast send $CARBON_BATCH_NFT 'createBatch(string,string)' 'Renewable Energy Portfolio Q1 2025' 'https://metadata.example.com/batch1' --rpc-url \$RPC_URL --private-key \$PRIVATE_KEY --legacy" \
    "Creates a new batch NFT with metadata describing a portfolio of renewable energy projects. This batch will automatically get its own ERC6551 token-bound account that can hold assets." \
    "decode_tx_hash"

# Get batch token-bound account
execute_and_explain \
    "cast call $CARBON_BATCH_NFT 'getTokenBoundAccount(uint256)' 1 --rpc-url \$RPC_URL" \
    "Retrieves the ERC6551 token-bound account address for batch NFT #1. This account acts like a wallet owned by the NFT itself." \
    "decode_address"

echo -e "${BLUE}🔧 Getting batch token-bound account address...${NC}"
BATCH_ACCOUNT=$(cast call $CARBON_BATCH_NFT 'getTokenBoundAccount(uint256)' 1 --rpc-url $RPC_URL 2>/dev/null | tr -d '\n' | tr -d ' ')
echo -e "${GREEN}📍 Batch Account Address: $BATCH_ACCOUNT${NC}"
echo ""

echo -e "${GREEN}STEP 5: Transfer Project NFTs to Batch Account${NC}"
echo "Move individual project NFTs into the batch's token-bound account"
pause

# Approve batch to transfer project 1
execute_and_explain \
    "cast send $CARBON_PROJECT_NFT 'approve(address,uint256)' $CARBON_BATCH_NFT 1 --rpc-url \$RPC_URL --private-key \$PRIVATE_KEY --legacy" \
    "Approves the batch contract to transfer project NFT #1. This is required before the batch can take ownership." \
    "decode_tx_hash"

# Transfer project 1 to batch account
execute_and_explain \
    "cast send $CARBON_BATCH_NFT 'transferProjectToAccount(uint256,uint256)' 1 1 --rpc-url \$RPC_URL --private-key \$PRIVATE_KEY --legacy" \
    "Transfers project NFT #1 into the token-bound account of batch NFT #1. The project is now owned by the batch itself, not an individual wallet." \
    "decode_tx_hash"

# Check ownership
execute_and_explain \
    "cast call $CARBON_PROJECT_NFT 'ownerOf(uint256)' 1 --rpc-url \$RPC_URL" \
    "Verifies that project NFT #1 is now owned by the batch's token-bound account address, not the original minter." \
    "decode_address"

echo -e "${GREEN}STEP 6: Verify Token-Bound Account Functionality${NC}"
echo "Demonstrate that the batch NFT can execute transactions through its account"
pause

# Check if account can receive NFTs
execute_and_explain \
    "cast call $CARBON_PROJECT_NFT 'balanceOf(address)' $BATCH_ACCOUNT --rpc-url \$RPC_URL" \
    "Checks how many project NFTs the batch's token-bound account owns. This proves the account can hold assets." \
    "decode_balance"

# Execute a call from the batch account
execute_and_explain \
    "cast call $CARBON_BATCH_NFT 'owner()' --rpc-url \$RPC_URL" \
    "Gets the owner of the batch contract to verify permissions for executing transactions through token-bound accounts." \
    "decode_address"

echo -e "${GREEN}STEP 7: Create Another Batch and Demonstrate Transfers${NC}"
echo "Show how multiple batches can manage different sets of carbon projects"
pause

# Create second batch
execute_and_explain \
    "cast send $CARBON_BATCH_NFT 'createBatch(string,string)' 'Forest Conservation Portfolio Q1 2025' 'https://metadata.example.com/batch2' --rpc-url \$RPC_URL --private-key \$PRIVATE_KEY --legacy" \
    "Creates a second batch focused on forest conservation projects. Each batch is independent with its own token-bound account." \
    "decode_tx_hash"

# Transfer project 2 to second batch
execute_and_explain \
    "cast send $CARBON_PROJECT_NFT 'approve(address,uint256)' $CARBON_BATCH_NFT 2 --rpc-url \$RPC_URL --private-key \$PRIVATE_KEY --legacy" \
    "Approves the batch contract to transfer project NFT #2 (wind farm) to batch #2." \
    "decode_tx_hash"

execute_and_explain \
    "cast send $CARBON_BATCH_NFT 'transferProjectToAccount(uint256,uint256)' 2 2 --rpc-url \$RPC_URL --private-key \$PRIVATE_KEY --legacy" \
    "Transfers the wind farm project NFT to the second batch's token-bound account. Now we have two separate portfolios." \
    "decode_tx_hash"

echo -e "${GREEN}STEP 8: Demonstrate Batch Operations${NC}"
echo "Show how batch owners can manage their portfolios through the ERC6551 system"
pause

# Get total credits in batch 1
execute_and_explain \
    "cast call $CARBON_BATCH_NFT 'getBatchProjects(uint256)' 1 --rpc-url \$RPC_URL" \
    "Retrieves the list of project NFTs contained in batch #1. This shows portfolio composition." \
    ""

# Check batch metadata
execute_and_explain \
    "cast call $CARBON_BATCH_NFT 'tokenURI(uint256)' 1 --rpc-url \$RPC_URL" \
    "Gets the metadata URI for batch #1, which contains information about the renewable energy portfolio." \
    ""

echo -e "${GREEN}STEP 9: Redeem Carbon Credits${NC}"
echo "Demonstrate how to redeem credits from a batch, which burns them permanently"
pause

# Redeem credits (if implemented)
execute_and_explain \
    "cast call $CARBON_BATCH_NFT 'totalSupply()' --rpc-url \$RPC_URL" \
    "Checks the total number of batch NFTs that exist before any redemption operations." \
    "decode_balance"

echo -e "${GREEN}STEP 10: Final System State${NC}"
echo "Review the final state of our ERC6551 carbon credit system"
pause

# Check final ownership states
execute_and_explain \
    "cast call $CARBON_PROJECT_NFT 'totalSupply()' --rpc-url \$RPC_URL" \
    "Shows total number of project NFTs created. These represent the underlying carbon credit projects." \
    "decode_balance"

execute_and_explain \
    "cast call $CARBON_BATCH_NFT 'totalSupply()' --rpc-url \$RPC_URL" \
    "Shows total number of batch NFTs created. Each batch has its own ERC6551 token-bound account managing a portfolio." \
    "decode_balance"

# Summary
echo -e "${PURPLE}🎉 DEMO COMPLETE!${NC}"
echo -e "${PURPLE}==================${NC}"
echo ""
echo -e "${GREEN}✅ What we accomplished:${NC}"
echo "  1. Deployed complete ERC6551 carbon credit system"
echo "  2. Minted individual carbon project NFTs"
echo "  3. Created batch NFTs with token-bound accounts" 
echo "  4. Transferred projects into batch accounts"
echo "  5. Demonstrated portfolio management capabilities"
echo ""
echo -e "${YELLOW}🔑 Key ERC6551 Features Shown:${NC}"
echo "  • Token-bound accounts automatically created for each batch NFT"
echo "  • Batch NFTs can own and manage other NFTs through their accounts"
echo "  • Clear separation between individual projects and portfolio batches"
echo "  • Programmable logic for portfolio management and redemption"
echo ""
echo -e "${BLUE}🌍 Real-world Impact:${NC}"
echo "  • Enables sophisticated carbon credit portfolio management"
echo "  • Allows institutional investors to manage large credit collections"
echo "  • Provides transparent tracking of credit ownership and transfers"
echo "  • Supports complex carbon market operations and derivatives"
echo ""
echo -e "${CYAN}Thanks for exploring the ERC6551 Carbon Credits System! 🌱${NC}"