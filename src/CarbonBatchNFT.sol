// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IERC6551Registry.sol";
import "./interfaces/IERC6551Account.sol";
import "./CarbonProjectNFT.sol";

/**
 * @title CarbonBatchNFT
 * @dev ERC6551-compatible NFT that represents batches of carbon projects
 * Each batch NFT has an associated token-bound account that can hold and manage carbon project NFTs
 */
contract CarbonBatchNFT is ERC721URIStorage, Ownable, ReentrancyGuard {
    
    struct BatchData {
        string batchType;           // e.g., "Reforestation Batch", "Renewable Energy Batch"
        string vintage;             // Year/period of the batch
        uint256 totalCarbonAmount;  // Total carbon credits in this batch
        uint256 projectCount;       // Number of projects in this batch
        address tokenBoundAccount;  // ERC6551 account address for this batch
        uint256 creationDate;       // When this batch was created
        bool finalized;             // Whether the batch is finalized (no more projects can be added)
        address[] projectContracts; // Contracts of projects in this batch
        uint256[] projectIds;       // Project IDs in this batch
    }

    uint256 public nextBatchId = 1;
    mapping(uint256 => BatchData) public batchData;
    
    // ERC6551 Registry and Account implementation addresses
    address public immutable ERC6551_REGISTRY;
    address public immutable ACCOUNT_IMPLEMENTATION;
    
    // Mapping from project contract + project ID to batch ID
    mapping(address => mapping(uint256 => uint256)) public projectToBatch;
    
    // Events
    event BatchCreated(
        uint256 indexed batchId,
        address indexed owner,
        string batchType,
        string vintage,
        address tokenBoundAccount
    );
    
    event ProjectAddedToBatch(
        uint256 indexed batchId,
        address indexed projectContract,
        uint256 indexed projectId,
        uint256 carbonAmount
    );
    
    event BatchFinalized(uint256 indexed batchId, uint256 totalCarbonAmount, uint256 projectCount);

    constructor(
        address _registry,
        address _accountImplementation
    ) ERC721("Carbon Batch", "CARBON-BATCH") {
        require(_registry != address(0), "Invalid registry address");
        require(_accountImplementation != address(0), "Invalid account implementation");
        
        ERC6551_REGISTRY = _registry;
        ACCOUNT_IMPLEMENTATION = _accountImplementation;
    }

    /**
     * @dev Create a new carbon batch NFT with associated token-bound account
     * @param to Address to receive the batch NFT
     * @param batchType Type of carbon batch
     * @param vintage Year/period of the batch
     * @param uri Metadata URI for the batch
     * @return batchId The ID of the created batch
     */
    function createBatch(
        address to,
        string calldata batchType,
        string calldata vintage,
        string calldata uri
    ) external onlyOwner nonReentrant returns (uint256 batchId) {
        require(to != address(0), "Cannot mint to zero address");
        require(bytes(batchType).length > 0, "Batch type required");
        require(bytes(vintage).length > 0, "Vintage required");
        
        batchId = nextBatchId++;
        
        // Mint the NFT
        _mint(to, batchId);
        _setTokenURI(batchId, uri);
        
        // Create token-bound account for this batch
        address tokenBoundAccount = IERC6551Registry(ERC6551_REGISTRY).createAccount(
            ACCOUNT_IMPLEMENTATION,
            block.chainid,
            address(this),
            batchId,
            0, // salt
            ""  // initData
        );
        
        // Initialize batch data
        batchData[batchId] = BatchData({
            batchType: batchType,
            vintage: vintage,
            totalCarbonAmount: 0,
            projectCount: 0,
            tokenBoundAccount: tokenBoundAccount,
            creationDate: block.timestamp,
            finalized: false,
            projectContracts: new address[](0),
            projectIds: new uint256[](0)
        });
        
        emit BatchCreated(batchId, to, batchType, vintage, tokenBoundAccount);
    }

    /**
     * @dev Add a carbon project to a batch
     * @param batchId The batch to add the project to
     * @param projectContract The contract address of the carbon project NFT
     * @param projectId The ID of the project to add
     */
    function addProjectToBatch(
        uint256 batchId,
        address projectContract,
        uint256 projectId
    ) external nonReentrant {
        require(_exists(batchId), "Batch does not exist");
        require(!batchData[batchId].finalized, "Batch is finalized");
        require(projectToBatch[projectContract][projectId] == 0, "Project already in a batch");
        
        // Only batch owner or contract owner can add projects
        require(
            msg.sender == ownerOf(batchId) || msg.sender == owner(),
            "Not authorized to add projects"
        );
        
        // Verify the project exists and get its data
        CarbonProjectNFT carbonProject = CarbonProjectNFT(projectContract);
        require(carbonProject.ownerOf(projectId) != address(0), "Project does not exist");
        
        // Get project data to extract carbon amount
        (, uint256 carbonAmount, , , , ) = carbonProject.getProjectData(projectId);
        
        // Update batch data
        BatchData storage batch = batchData[batchId];
        batch.totalCarbonAmount += carbonAmount;
        batch.projectCount++;
        batch.projectContracts.push(projectContract);
        batch.projectIds.push(projectId);
        
        // Map project to batch
        projectToBatch[projectContract][projectId] = batchId;
        
        emit ProjectAddedToBatch(batchId, projectContract, projectId, carbonAmount);
    }

    /**
     * @dev Transfer a project NFT to the batch's token-bound account
     * @param batchId The batch ID
     * @param projectContract The project contract address
     * @param projectId The project ID
     */
    function transferProjectToAccount(
        uint256 batchId,
        address projectContract,
        uint256 projectId
    ) external {
        require(_exists(batchId), "Batch does not exist");
        require(projectToBatch[projectContract][projectId] == batchId, "Project not in this batch");
        
        // Only batch owner can transfer projects to the account
        require(msg.sender == ownerOf(batchId), "Not batch owner");
        
        CarbonProjectNFT carbonProject = CarbonProjectNFT(projectContract);
        address projectOwner = carbonProject.ownerOf(projectId);
        require(projectOwner == msg.sender, "Not project owner");
        
        // Transfer project to the token-bound account
        address tokenBoundAccount = batchData[batchId].tokenBoundAccount;
        carbonProject.transferFrom(msg.sender, tokenBoundAccount, projectId);
    }

    /**
     * @dev Finalize a batch (no more projects can be added)
     * @param batchId The batch to finalize
     */
    function finalizeBatch(uint256 batchId) external {
        require(_exists(batchId), "Batch does not exist");
        require(!batchData[batchId].finalized, "Batch already finalized");
        
        // Only batch owner or contract owner can finalize
        require(
            msg.sender == ownerOf(batchId) || msg.sender == owner(),
            "Not authorized to finalize"
        );
        
        batchData[batchId].finalized = true;
        
        emit BatchFinalized(
            batchId,
            batchData[batchId].totalCarbonAmount,
            batchData[batchId].projectCount
        );
    }

    /**
     * @dev Get the token-bound account address for a batch
     * @param batchId The batch ID
     * @return The token-bound account address
     */
    function getTokenBoundAccount(uint256 batchId) external view returns (address) {
        require(_exists(batchId), "Batch does not exist");
        return batchData[batchId].tokenBoundAccount;
    }

    /**
     * @dev Get complete batch data
     * @param batchId The batch to query
     */
    function getBatchData(uint256 batchId) external view returns (
        string memory batchType,
        string memory vintage,
        uint256 totalCarbonAmount,
        uint256 projectCount,
        address tokenBoundAccount,
        uint256 creationDate,
        bool finalized,
        address[] memory projectContracts,
        uint256[] memory projectIds
    ) {
        require(_exists(batchId), "Batch does not exist");
        BatchData memory batch = batchData[batchId];
        
        return (
            batch.batchType,
            batch.vintage,
            batch.totalCarbonAmount,
            batch.projectCount,
            batch.tokenBoundAccount,
            batch.creationDate,
            batch.finalized,
            batch.projectContracts,
            batch.projectIds
        );
    }

    /**
     * @dev Get which batch a project belongs to
     * @param projectContract The project contract address
     * @param projectId The project ID
     * @return The batch ID (0 if not in any batch)
     */
    function getProjectBatch(address projectContract, uint256 projectId) external view returns (uint256) {
        return projectToBatch[projectContract][projectId];
    }

    /**
     * @dev Execute a call through the token-bound account
     * @param batchId The batch ID
     * @param to The target contract
     * @param value The ETH value to send
     * @param data The call data
     */
    function executeFromAccount(
        uint256 batchId,
        address to,
        uint256 value,
        bytes calldata data
    ) external returns (bytes memory) {
        address tokenBoundAccount = batchData[batchId].tokenBoundAccount;
        return IERC6551Account(tokenBoundAccount).executeCall(to, value, data);
    }
}