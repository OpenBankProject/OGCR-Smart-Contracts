# Carbon Credits ERC6551 System

This system implements an ERC6551 token-bound account solution for carbon credits, allowing carbon project NFTs to be grouped into batches with dedicated token-bound accounts that can hold and manage the underlying projects.

## Architecture Overview

### Core Components

1. **CarbonProjectNFT** - Existing NFT contract representing individual carbon projects
2. **CarbonBatchNFT** - New ERC721 contract representing batches of carbon projects with ERC6551 functionality
3. **CarbonERC6551Registry** - Registry for creating token-bound accounts
4. **CarbonERC6551Account** - Token-bound account implementation for batch management
5. **CarbonBatchController** - Controller for managing batch operations and workflows

### Key Features

- **Token-Bound Accounts**: Each batch NFT has an associated ERC6551 account that can hold assets
- **Project Batching**: Multiple carbon projects can be grouped into thematic batches
- **Batch Management**: Execute operations on behalf of all projects in a batch
- **Ownership Control**: Only batch owners can control their token-bound accounts
- **Project Redemption**: Redeem carbon projects through the batch system
- **Metadata Integration**: Full metadata support for both projects and batches

## Contract Relationships

```
CarbonProjectNFT (Individual Projects)
         ↓
CarbonBatchController (Orchestration)
         ↓
CarbonBatchNFT (Batch Management)
         ↓
ERC6551Registry (Account Creation)
         ↓
CarbonERC6551Account (Token-Bound Account)
```

## Deployment

### 1. Deploy the System

```bash
# Set your private key
export PRIVATE_KEY=your_private_key_here

# Deploy all contracts
forge script script/DeployCarbonERC6551System.s.sol:DeployCarbonERC6551System --rpc-url $RPC_URL --broadcast --verify
```

### 2. Set Contract Addresses for Demo

```bash
# Set deployed contract addresses for demo
export CARBON_PROJECT_NFT=0x...
export CARBON_BATCH_NFT=0x...
export ERC6551_REGISTRY=0x...
export BATCH_CONTROLLER=0x...
```

### 3. Run the Demo

```bash
forge script script/CarbonERC6551Demo.s.sol:CarbonERC6551Demo --rpc-url $RPC_URL --broadcast
```

## Usage Examples

### Creating a Carbon Batch

```solidity
// Create a batch with multiple projects
uint256[] memory projectIds = [1, 2, 3, 4, 5];
uint256 batchId = batchController.createBatchWithProjects(
    "Reforestation",           // Batch type
    "2024",                    // Vintage
    "ipfs://metadata-uri",     // Metadata URI
    projectIds,                // Project IDs to include
    true                       // Transfer to token-bound account
);
```

### Executing Batch Operations

```solidity
// Execute operations through the token-bound account
address[] memory targets = [projectContract1, projectContract2];
uint256[] memory values = [0, 0];
bytes[] memory calldatas = [data1, data2];

bytes[] memory results = batchController.executeBatchOperation(
    batchId,
    targets,
    values,
    calldatas
);
```

### Redeeming Projects from a Batch

```solidity
// Redeem specific projects from the batch
uint256[] memory projectsToRedeem = [1, 2];
batchController.redeemProjectsFromBatch(batchId, projectsToRedeem);
```

## Key Interfaces

### CarbonBatchNFT

```solidity
interface ICarbonBatchNFT {
    function createBatch(address to, string calldata batchType, string calldata vintage, string calldata uri) external returns (uint256);
    function addProjectToBatch(uint256 batchId, address projectContract, uint256 projectId) external;
    function getTokenBoundAccount(uint256 batchId) external view returns (address);
    function executeFromAccount(uint256 batchId, address to, uint256 value, bytes calldata data) external returns (bytes memory);
}
```

### CarbonERC6551Account

```solidity
interface ICarbonERC6551Account {
    function owner() external view returns (address);
    function token() external view returns (uint256 chainId, address tokenContract, uint256 tokenId);
    function executeCall(address to, uint256 value, bytes calldata data) external payable returns (bytes memory);
}
```

## Security Considerations

1. **Owner Verification**: All operations verify that the caller owns the batch NFT
2. **Project Validation**: Projects must be verified and redeemable before batching
3. **Reentrancy Protection**: All state-changing functions use reentrancy guards
4. **Access Control**: Proper role-based access control throughout the system

## Gas Optimization

- Batch operations reduce individual transaction costs
- Token-bound accounts enable efficient multi-project management
- Optimized storage patterns for frequently accessed data

## Integration with Existing System

This ERC6551 system is designed to work alongside your existing carbon credit contracts:

- **CarbonProjectNFT**: No changes required to existing contract
- **Additional Functionality**: New batching capabilities without breaking existing workflows
- **Backward Compatibility**: All existing project operations continue to work

## Testing

```bash
# Run all tests
forge test

# Run specific test categories
forge test --match-contract CarbonBatchTest
forge test --match-contract ERC6551Test
```

## Events

The system emits comprehensive events for tracking:

- `BatchCreated` - When a new batch is created
- `ProjectAddedToBatch` - When projects are added to batches
- `ProjectsBatchedAndTransferred` - When projects are moved to token-bound accounts
- `BatchFinalized` - When batches are finalized
- `CallExecuted` - When operations are executed through token-bound accounts

## Future Enhancements

- Multi-signature batch management
- Batch splitting and merging capabilities
- Advanced metadata standards for batch provenance
- Integration with carbon credit marketplaces
- Automated compliance checking for batch operations