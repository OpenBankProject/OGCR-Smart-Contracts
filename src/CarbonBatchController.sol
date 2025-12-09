// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./CarbonProjectNFT.sol";
import "./CarbonBatchNFT.sol";
import "./CarbonERC6551Registry.sol";
import "./CarbonERC6551Account.sol";

/**
 * @title CarbonBatchController
 * @dev Controller contract for managing carbon project batching with ERC6551 functionality
 */
contract CarbonBatchController is Ownable, ReentrancyGuard {
    
    CarbonProjectNFT public immutable carbonProjectNFT;
    CarbonBatchNFT public immutable carbonBatchNFT;
    CarbonERC6551Registry public immutable erc6551Registry;
    address public immutable accountImplementation;
    
    // Batch creation fee (in wei)
    uint256 public batchCreationFee = 0;
    
    // Mapping from batch type to minimum project count
    mapping(string => uint256) public minProjectsPerBatch;
    
    // Events
    event BatchWorkflowStarted(
        uint256 indexed batchId,
        address indexed creator,
        string batchType,
        string vintage
    );
    
    event ProjectsBatchedAndTransferred(
        uint256 indexed batchId,
        address[] projectContracts,
        uint256[] projectIds,
        address tokenBoundAccount
    );
    
    event BatchCreationFeeUpdated(uint256 oldFee, uint256 newFee);
    event MinProjectsUpdated(string batchType, uint256 minProjects);

    constructor(
        address _carbonProjectNFT,
        address _carbonBatchNFT,
        address _erc6551Registry,
        address _accountImplementation
    ) {
        require(_carbonProjectNFT != address(0), "Invalid project NFT address");
        require(_carbonBatchNFT != address(0), "Invalid batch NFT address");
        require(_erc6551Registry != address(0), "Invalid registry address");
        require(_accountImplementation != address(0), "Invalid account implementation");
        
        carbonProjectNFT = CarbonProjectNFT(_carbonProjectNFT);
        carbonBatchNFT = CarbonBatchNFT(_carbonBatchNFT);
        erc6551Registry = CarbonERC6551Registry(_erc6551Registry);
        accountImplementation = _accountImplementation;
        
        // Set default minimum projects per batch
        minProjectsPerBatch["Reforestation"] = 5;
        minProjectsPerBatch["Renewable Energy"] = 3;
        minProjectsPerBatch["Soil Carbon"] = 10;
        minProjectsPerBatch["General"] = 1;
    }

    /**
     * @dev Create a batch and add multiple projects in one transaction
     * @param batchType Type of carbon batch
     * @param vintage Year/period of the batch
     * @param batchUri Metadata URI for the batch
     * @param projectIds Array of project IDs to add to the batch
     * @param transferToAccount Whether to transfer projects to the token-bound account immediately
     */
    function createBatchWithProjects(
        string calldata batchType,
        string calldata vintage,
        string calldata batchUri,
        uint256[] calldata projectIds,
        bool transferToAccount
    ) external payable nonReentrant returns (uint256 batchId) {
        require(msg.value >= batchCreationFee, "Insufficient batch creation fee");
        require(projectIds.length >= minProjectsPerBatch[batchType], "Not enough projects for batch type");
        require(projectIds.length > 0, "Must specify at least one project");
        
        // Verify caller owns all projects and they're verified
        for (uint256 i = 0; i < projectIds.length; i++) {
            require(carbonProjectNFT.ownerOf(projectIds[i]) == msg.sender, "Not owner of project");
            require(carbonProjectNFT.isProjectRedeemable(projectIds[i]), "Project not redeemable");
        }
        
        // Create the batch
        batchId = carbonBatchNFT.createBatch(msg.sender, batchType, vintage, batchUri);
        
        // Add all projects to the batch (we can do this because we own the CarbonBatchNFT contract)
        address[] memory projectContracts = new address[](projectIds.length);
        for (uint256 i = 0; i < projectIds.length; i++) {
            projectContracts[i] = address(carbonProjectNFT);
            // We call addProjectToBatch as the contract owner
            carbonBatchNFT.addProjectToBatch(batchId, address(carbonProjectNFT), projectIds[i]);
        }
        
        // Transfer projects to token-bound account if requested
        if (transferToAccount) {
            address tokenBoundAccount = carbonBatchNFT.getTokenBoundAccount(batchId);
            
            for (uint256 i = 0; i < projectIds.length; i++) {
                // The controller must be approved to transfer the user's projects
                // User should call carbonProjectNFT.approve(controller, projectId) before this
                carbonProjectNFT.transferFrom(msg.sender, tokenBoundAccount, projectIds[i]);
            }
            
            emit ProjectsBatchedAndTransferred(batchId, projectContracts, projectIds, tokenBoundAccount);
        }
        
        emit BatchWorkflowStarted(batchId, msg.sender, batchType, vintage);
    }

    /**
     * @dev Execute a batch operation through the token-bound account
     * @param batchId The batch ID
     * @param targets Array of target contracts
     * @param values Array of ETH values for each call
     * @param calldatas Array of call data for each target
     */
    function executeBatchOperation(
        uint256 batchId,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas
    ) external returns (bytes[] memory results) {
        require(carbonBatchNFT.ownerOf(batchId) == msg.sender, "Not batch owner");
        require(targets.length == values.length, "Mismatched arrays");
        require(targets.length == calldatas.length, "Mismatched arrays");
        
        results = new bytes[](targets.length);
        
        for (uint256 i = 0; i < targets.length; i++) {
            results[i] = carbonBatchNFT.executeFromAccount(
                batchId,
                targets[i],
                values[i],
                calldatas[i]
            );
        }
    }

    /**
     * @dev Redeem carbon projects from a batch through the token-bound account
     * @param batchId The batch ID
     * @param projectIds Array of project IDs to redeem
     */
    function redeemProjectsFromBatch(
        uint256 batchId,
        uint256[] calldata projectIds
    ) external nonReentrant {
        require(carbonBatchNFT.ownerOf(batchId) == msg.sender, "Not batch owner");
        
        address tokenBoundAccount = carbonBatchNFT.getTokenBoundAccount(batchId);
        
        for (uint256 i = 0; i < projectIds.length; i++) {
            uint256 projectId = projectIds[i];
            
            // Verify the project is in this batch and owned by the token-bound account
            require(
                carbonBatchNFT.getProjectBatch(address(carbonProjectNFT), projectId) == batchId,
                "Project not in this batch"
            );
            require(
                carbonProjectNFT.ownerOf(projectId) == tokenBoundAccount,
                "Project not owned by batch account"
            );
            
            // Mark project as redeemed using our authorization
            // We can do this directly because we're an authorized redeemer
            carbonProjectNFT.markRedeemed(projectId);
        }
    }

    /**
     * @dev Get comprehensive batch information including token-bound account state
     * @param batchId The batch ID
     */
    function getBatchInfo(uint256 batchId) external view returns (
        string memory batchType,
        string memory vintage,
        uint256 totalCarbonAmount,
        uint256 projectCount,
        address tokenBoundAccount,
        address batchOwner,
        uint256 accountBalance,
        bool finalized
    ) {
        require(carbonBatchNFT.ownerOf(batchId) != address(0), "Batch does not exist");
        
        (
            batchType,
            vintage,
            totalCarbonAmount,
            projectCount,
            tokenBoundAccount,
            ,
            finalized,
            ,
        ) = carbonBatchNFT.getBatchData(batchId);
        
        batchOwner = carbonBatchNFT.ownerOf(batchId);
        accountBalance = tokenBoundAccount.balance;
    }

    /**
     * @dev Set batch creation fee (only owner)
     * @param newFee The new fee in wei
     */
    function setBatchCreationFee(uint256 newFee) external onlyOwner {
        uint256 oldFee = batchCreationFee;
        batchCreationFee = newFee;
        emit BatchCreationFeeUpdated(oldFee, newFee);
    }

    /**
     * @dev Set minimum projects required for a batch type
     * @param batchType The batch type
     * @param minProjects Minimum number of projects required
     */
    function setMinProjectsPerBatch(string calldata batchType, uint256 minProjects) external onlyOwner {
        require(minProjects > 0, "Minimum projects must be greater than 0");
        minProjectsPerBatch[batchType] = minProjects;
        emit MinProjectsUpdated(batchType, minProjects);
    }

    /**
     * @dev Withdraw collected fees (only owner)
     * @param to Address to send fees to
     */
    function withdrawFees(address payable to) external onlyOwner {
        require(to != address(0), "Invalid recipient");
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        
        (bool success, ) = to.call{value: balance}("");
        require(success, "Fee withdrawal failed");
    }

    /**
     * @dev Get the minimum projects required for a batch type
     * @param batchType The batch type to query
     */
    function getMinProjectsForBatchType(string calldata batchType) external view returns (uint256) {
        uint256 minProjects = minProjectsPerBatch[batchType];
        return minProjects > 0 ? minProjects : minProjectsPerBatch["General"];
    }

    receive() external payable {
        // Allow contract to receive ETH
    }
}