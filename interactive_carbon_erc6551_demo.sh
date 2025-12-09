#!/bin/bash

# Interactive Carbon Credits ERC6551 Demo Script
# This script demonstrates the complete workflow using cast commands

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_step() {
    echo -e "${BLUE}===========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===========================================${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_command() {
    echo -e "${PURPLE}🔧 Command:${NC} $1"
}

print_response() {
    echo -e "${GREEN}📝 Response:${NC} $1"
}

print_translation() {
    echo -e "${YELLOW}🔍 Translation:${NC} $1"
}

# Function to pause and wait for user input
pause() {
    echo -e "${CYAN}Press Enter to continue...${NC}"
    read -r
}

# Function to execute cast command with explanation
execute_cast() {
    local description="$1"
    local command="$2"
    local translation="$3"
    
    echo
    print_info "$description"
    print_command "$command"
    
    if [[ $INTERACTIVE == "true" ]]; then
        pause
    fi
    
    # Execute the command and capture output
    local output
    if output=$(eval "$command" 2>&1); then
        print_response "$output"
        if [[ -n "$translation" ]]; then
            print_translation "$translation"
        fi
        print_success "Command executed successfully"
    else
        print_error "Command failed: $output"
        return 1
    fi
    
    echo
}

# Source .env file if it exists
source_env() {
    if [[ -f ".env" ]]; then
        print_info "Sourcing .env file..."
        set -a  # automatically export all variables
        source .env
        set +a  # stop auto-exporting
        print_success "Environment variables loaded from .env"
    else
        print_warning "No .env file found. Please set environment variables manually."
    fi
}

# Check if required environment variables are set
check_environment() {
    print_step "CHECKING ENVIRONMENT"
    
    # First try to source .env file
    source_env
    
    local required_vars=("PRIVATE_KEY" "RPC_URL")
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        print_error "Missing required environment variables: ${missing_vars[*]}"
        echo "Please set them using:"
        for var in "${missing_vars[@]}"; do
            echo "  export $var=your_value_here"
        done
        exit 1
    fi
    
    print_success "All required environment variables are set"
    
    # Check if contract addresses are set
    if [[ -z "$CARBON_PROJECT_NFT" || -z "$CARBON_BATCH_NFT" || -z "$BATCH_CONTROLLER" ]]; then
        print_warning "Contract addresses not set. Please deploy contracts first or set:"
        echo "  export CARBON_PROJECT_NFT=0x..."
        echo "  export CARBON_BATCH_NFT=0x..."
        echo "  export BATCH_CONTROLLER=0x..."
        echo "  export ERC6551_REGISTRY=0x..."
        exit 1
    fi
    
    print_success "Contract addresses are configured"
}

# Function to get wallet address from private key
get_wallet_address() {
    local addr
    addr=$(cast wallet address --private-key "$PRIVATE_KEY")
    echo "$addr"
}

# Function to decode transaction receipt
decode_receipt() {
    local tx_hash="$1"
    cast receipt "$tx_hash" --rpc-url "$RPC_URL"
}

# Main demo workflow
main() {
    echo -e "${GREEN}"
    echo "🌱 CARBON CREDITS ERC6551 INTERACTIVE DEMO"
    echo "=========================================="
    echo -e "${NC}"
    
    # Set interactive mode
    if [[ "$1" == "--interactive" || "$1" == "-i" ]]; then
        INTERACTIVE="true"
        print_info "Running in interactive mode. Press Enter after each step."
    else
        INTERACTIVE="false"
        print_info "Running in automatic mode. Use --interactive for step-by-step execution."
    fi
    
    # Check environment
    check_environment
    
    # Get wallet address
    WALLET_ADDRESS=$(get_wallet_address)
    print_info "Using wallet address: $WALLET_ADDRESS"
    
    # Demo variables - Use existing contract addresses for demo
    MOCK_ERC20="$CARBON_PROJECT_NFT"
    MOCK_PARCEL_NFT="$CARBON_PROJECT_NFT"
    
    print_step "STEP 1: CREATE CARBON PROJECTS"
    
    # Create multiple carbon projects
    for i in {1..5}; do
        local carbon_amount=$((i * 1000))
        local parcel_id=$i
        
        execute_cast \
            "Creating carbon project $i with $carbon_amount carbon credits" \
            "cast send $CARBON_PROJECT_NFT \"mintCarbonProject(address,address,uint256,address,uint256,address,string,string,string,string)\" \
            $WALLET_ADDRESS \
            $MOCK_PARCEL_NFT \
            $parcel_id \
            $MOCK_ERC20 \
            $carbon_amount \
            $WALLET_ADDRESS \
            \"Reforestation\" \
            \"VCS\" \
            \"2024\" \
            \"https://metadata.carbon.com/project/$i\" \
            --private-key $PRIVATE_KEY \
            --rpc-url $RPC_URL \
            --legacy" \
            "This mints a new carbon project NFT representing a reforestation project with $carbon_amount carbon credits"
    done
    
    print_step "STEP 2: CHECK PROJECT OWNERSHIP"
    
    # Check ownership of created projects
    for i in {1..5}; do
        execute_cast \
            "Checking owner of project $i" \
            "cast call $CARBON_PROJECT_NFT \"ownerOf(uint256)\" $i --rpc-url $RPC_URL" \
            "This returns the Ethereum address that owns project NFT #$i (should be your wallet)"
        
        execute_cast \
            "Checking if project $i is redeemable" \
            "cast call $CARBON_PROJECT_NFT \"isProjectRedeemable(uint256)\" $i --rpc-url $RPC_URL" \
            "This returns true (0x01) if the project is verified and not yet redeemed"
    done
    
    print_step "STEP 3: APPROVE BATCH CONTROLLER"
    
    # Approve batch controller to manage projects
    for i in {1..5}; do
        execute_cast \
            "Approving batch controller to manage project $i" \
            "cast send $CARBON_PROJECT_NFT \"approve(address,uint256)\" $BATCH_CONTROLLER $i \
            --private-key $PRIVATE_KEY \
            --rpc-url $RPC_URL \
            --legacy" \
            "This gives permission to the batch controller to transfer project $i on your behalf"
    done
    
    print_step "STEP 4: CREATE CARBON BATCH WITH PROJECTS"
    
    # Create batch with all projects
    execute_cast \
        "Creating a carbon batch with all 5 projects" \
        "cast send $BATCH_CONTROLLER \"createBatchWithProjects(string,string,string,uint256[],bool)\" \
        \"Reforestation\" \
        \"2024\" \
        \"https://metadata.carbon.com/batch/1\" \
        \"[1,2,3,4,5]\" \
        true \
        --private-key $PRIVATE_KEY \
        --rpc-url $RPC_URL \
        --legacy" \
        "This creates a new batch NFT and automatically transfers all 5 projects to its token-bound account"
    
    print_step "STEP 5: VERIFY BATCH CREATION"
    
    # Check batch ownership
    execute_cast \
        "Checking owner of batch #1" \
        "cast call $CARBON_BATCH_NFT \"ownerOf(uint256)\" 1 --rpc-url $RPC_URL" \
        "This shows who owns the batch NFT (should be your wallet address)"
    
    # Get batch data
    execute_cast \
        "Getting batch data for batch #1" \
        "cast call $CARBON_BATCH_NFT \"getBatchData(uint256)\" 1 --rpc-url $RPC_URL" \
        "This returns: batch type, vintage, total carbon amount, project count, token-bound account, creation date, finalized status, and project lists"
    
    # Get token-bound account address
    execute_cast \
        "Getting token-bound account address for batch #1" \
        "cast call $CARBON_BATCH_NFT \"getTokenBoundAccount(uint256)\" 1 --rpc-url $RPC_URL" \
        "This returns the address of the ERC6551 token-bound account that holds the projects"
    
    print_step "STEP 6: VERIFY PROJECT TRANSFER TO TOKEN-BOUND ACCOUNT"
    
    # Get the token-bound account address first
    TBA_ADDRESS=$(cast call $CARBON_BATCH_NFT "getTokenBoundAccount(uint256)" 1 --rpc-url $RPC_URL)
    TBA_ADDRESS=${TBA_ADDRESS:2}  # Remove 0x prefix
    TBA_ADDRESS="0x${TBA_ADDRESS: -40}"  # Get last 40 characters (20 bytes)
    
    print_info "Token-bound account address: $TBA_ADDRESS"
    
    # Check that projects are now owned by the token-bound account
    for i in {1..5}; do
        execute_cast \
            "Verifying project $i is owned by token-bound account" \
            "cast call $CARBON_PROJECT_NFT \"ownerOf(uint256)\" $i --rpc-url $RPC_URL" \
            "This should return the token-bound account address, proving the project was transferred"
    done
    
    print_step "STEP 7: EXECUTE OPERATIONS THROUGH TOKEN-BOUND ACCOUNT"
    
    # Check if a project is redeemable through the token-bound account
    PROJECT_CHECK_DATA=$(cast calldata "isProjectRedeemable(uint256)" 1)
    execute_cast \
        "Checking if project 1 is redeemable through token-bound account" \
        "cast send $CARBON_BATCH_NFT \"executeFromAccount(uint256,address,uint256,bytes)\" \
        1 \
        $CARBON_PROJECT_NFT \
        0 \
        $PROJECT_CHECK_DATA \
        --private-key $PRIVATE_KEY \
        --rpc-url $RPC_URL \
        --legacy" \
        "This executes a call through the token-bound account to check if project 1 is still redeemable"
    
    print_step "STEP 8: REDEEM PROJECTS THROUGH BATCH"
    
    # Redeem some projects
    execute_cast \
        "Redeeming projects 1 and 2 through the batch system" \
        "cast send $BATCH_CONTROLLER \"redeemProjectsFromBatch(uint256,uint256[])\" \
        1 \
        \"[1,2]\" \
        --private-key $PRIVATE_KEY \
        --rpc-url $RPC_URL \
        --legacy\" \
        "This marks projects 1 and 2 as redeemed, converting them to carbon credits"
    
    # Verify redemption
    for i in {1..2}; do
        execute_cast \
            "Checking redemption status of project $i" \
            "cast call $CARBON_PROJECT_NFT \"getProjectData(uint256)\" $i --rpc-url $RPC_URL" \
            "The 10th field (redeemed status) should now be true (0x01) for redeemed projects"
    done
    
    print_step "STEP 9: FINALIZE BATCH"
    
    # Finalize the batch
    execute_cast \
        "Finalizing batch #1 (no more projects can be added)" \
        "cast send $CARBON_BATCH_NFT \"finalizeBatch(uint256)\" 1 \
        --private-key $PRIVATE_KEY \
        --rpc-url $RPC_URL" \
        "This locks the batch and prevents any more projects from being added to it"
    
    print_step "STEP 10: VERIFY FINAL STATE"
    
    # Check final batch state
    execute_cast \
        "Getting final batch data" \
        "cast call $CARBON_BATCH_NFT \"getBatchData(uint256)\" 1 --rpc-url $RPC_URL" \
        "The finalized status (7th field) should now be true, and total carbon amount should show 15000 (1000+2000+3000+4000+5000)"
    
    # Check token-bound account balance
    execute_cast \
        "Checking ETH balance of token-bound account" \
        "cast balance $TBA_ADDRESS --rpc-url $RPC_URL" \
        "This shows how much ETH the token-bound account holds (should be 0 unless ETH was sent to it)"
    
    print_step "DEMO COMPLETED SUCCESSFULLY! 🎉"
    
    echo -e "${GREEN}"
    echo "Summary of what we demonstrated:"
    echo "================================"
    echo "✅ Created 5 carbon project NFTs (1000-5000 credits each)"
    echo "✅ Approved batch controller to manage projects"
    echo "✅ Created a carbon batch NFT with ERC6551 token-bound account"
    echo "✅ Automatically transferred all projects to the token-bound account"
    echo "✅ Executed operations through the token-bound account"
    echo "✅ Redeemed 2 projects through the batch system"
    echo "✅ Finalized the batch"
    echo "✅ Verified all state changes"
    echo
    echo "Key ERC6551 Benefits Demonstrated:"
    echo "- Token-bound accounts can hold and manage multiple NFTs"
    echo "- Batch operations reduce gas costs and complexity"
    echo "- Unified management of related carbon projects"
    echo "- Secure execution through owned token-bound accounts"
    echo -e "${NC}"
}

# Function to show help
show_help() {
    echo "Carbon Credits ERC6551 Demo Script"
    echo "=================================="
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -i, --interactive    Run in interactive mode (pause between steps)"
    echo "  -h, --help          Show this help message"
    echo
    echo "Required Environment Variables:"
    echo "  PRIVATE_KEY         Your wallet private key"
    echo "  RPC_URL            RPC endpoint URL"
    echo "  CARBON_PROJECT_NFT Contract address of CarbonProjectNFT"
    echo "  CARBON_BATCH_NFT   Contract address of CarbonBatchNFT"
    echo "  BATCH_CONTROLLER   Contract address of CarbonBatchController"
    echo "  ERC6551_REGISTRY   Contract address of CarbonERC6551Registry"
    echo
    echo "Example:"
    echo "  export PRIVATE_KEY=0x..."
    echo "  export RPC_URL=http://localhost:8545"
    echo "  # ... set contract addresses ..."
    echo "  $0 --interactive"
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -i|--interactive)
        main --interactive
        ;;
    "")
        main
        ;;
    *)
        echo "Unknown option: $1"
        show_help
        exit 1
        ;;
esac