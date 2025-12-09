// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/CarbonProjectNFT.sol";
import "../src/CarbonBatchNFT.sol";
import "../src/CarbonERC6551Registry.sol";
import "../src/CarbonERC6551Account.sol";
import "../src/CarbonBatchController.sol";

/**
 * @title CarbonERC6551Demo
 * @dev Demonstration script showing the complete ERC6551 carbon credit workflow
 */
contract CarbonERC6551Demo is Script {
    
    // Contract instances (you'll need to set these to your deployed addresses)
    CarbonProjectNFT carbonProjectNFT;
    CarbonBatchNFT carbonBatchNFT;
    CarbonERC6551Registry erc6551Registry;
    CarbonERC6551Account accountImplementation;
    CarbonBatchController batchController;
    
    address constant MOCK_ERC20 = 0x1234567890123456789012345678901234567890; // Mock ERC20 address
    address constant MOCK_PARCEL_NFT = 0x9876543210987654321098765432109876543210; // Mock parcel NFT

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Starting Carbon ERC6551 Demo...");
        console.log("Demo user address:", deployer);

        // Set deployed contract addresses (replace with actual addresses after deployment)
        // These would be set from deployment or environment variables
        // For now, using placeholder addresses - replace with actual deployed addresses
        address carbonProjectNFTAddr = vm.envOr("CARBON_PROJECT_NFT", address(0));
        address carbonBatchNFTAddr = vm.envOr("CARBON_BATCH_NFT", address(0));
        address erc6551RegistryAddr = vm.envOr("ERC6551_REGISTRY", address(0));
        address batchControllerAddr = vm.envOr("BATCH_CONTROLLER", address(0));
        
        require(carbonProjectNFTAddr != address(0), "Set CARBON_PROJECT_NFT env var");
        require(carbonBatchNFTAddr != address(0), "Set CARBON_BATCH_NFT env var");
        require(erc6551RegistryAddr != address(0), "Set ERC6551_REGISTRY env var");
        require(batchControllerAddr != address(0), "Set BATCH_CONTROLLER env var");
        
        carbonProjectNFT = CarbonProjectNFT(carbonProjectNFTAddr);
        carbonBatchNFT = CarbonBatchNFT(carbonBatchNFTAddr);
        erc6551Registry = CarbonERC6551Registry(erc6551RegistryAddr);
        batchController = CarbonBatchController(payable(batchControllerAddr));

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Create some carbon projects
        console.log("\n=== STEP 1: Creating Carbon Projects ===");
        
        uint256[] memory projectIds = new uint256[](5);
        
        projectIds[0] = carbonProjectNFT.mintCarbonProject(
            deployer,
            MOCK_PARCEL_NFT,
            1,
            MOCK_ERC20,
            1000, // 1000 carbon credits
            deployer,
            "Reforestation",
            "VCS",
            "2024",
            "https://metadata.carbon.com/project/1"
        );
        console.log("Created Reforestation project:", projectIds[0]);

        projectIds[1] = carbonProjectNFT.mintCarbonProject(
            deployer,
            MOCK_PARCEL_NFT,
            2,
            MOCK_ERC20,
            1500, // 1500 carbon credits
            deployer,
            "Reforestation",
            "VCS",
            "2024",
            "https://metadata.carbon.com/project/2"
        );
        console.log("Created Reforestation project:", projectIds[1]);

        projectIds[2] = carbonProjectNFT.mintCarbonProject(
            deployer,
            MOCK_PARCEL_NFT,
            3,
            MOCK_ERC20,
            2000, // 2000 carbon credits
            deployer,
            "Reforestation",
            "VCS",
            "2024",
            "https://metadata.carbon.com/project/3"
        );
        console.log("Created Reforestation project:", projectIds[2]);

        projectIds[3] = carbonProjectNFT.mintCarbonProject(
            deployer,
            MOCK_PARCEL_NFT,
            4,
            MOCK_ERC20,
            800, // 800 carbon credits
            deployer,
            "Reforestation",
            "Gold Standard",
            "2024",
            "https://metadata.carbon.com/project/4"
        );
        console.log("Created Reforestation project:", projectIds[3]);

        projectIds[4] = carbonProjectNFT.mintCarbonProject(
            deployer,
            MOCK_PARCEL_NFT,
            5,
            MOCK_ERC20,
            1200, // 1200 carbon credits
            deployer,
            "Reforestation",
            "VCS",
            "2024",
            "https://metadata.carbon.com/project/5"
        );
        console.log("Created Reforestation project:", projectIds[4]);

        // Step 2: Create a batch with these projects
        console.log("\n=== STEP 2: Creating Carbon Batch with ERC6551 Account ===");
        
        uint256 batchId = batchController.createBatchWithProjects(
            "Reforestation",
            "2024",
            "https://metadata.carbon.com/batch/1",
            projectIds,
            true // Transfer projects to token-bound account
        );
        console.log("Created batch with ID:", batchId);
        
        // Get batch info
        (
            string memory batchType,
            string memory vintage,
            uint256 totalCarbonAmount,
            uint256 projectCount,
            address tokenBoundAccount,
            address batchOwner,
            uint256 accountBalance,
            bool finalized
        ) = batchController.getBatchInfo(batchId);
        
        console.log("Batch type:", batchType);
        console.log("Vintage:", vintage);
        console.log("Total carbon amount:", totalCarbonAmount);
        console.log("Project count:", projectCount);
        console.log("Token-bound account:", tokenBoundAccount);
        console.log("Batch owner:", batchOwner);
        console.log("Account balance:", accountBalance);
        console.log("Finalized:", finalized);

        // Step 3: Verify token-bound account owns the projects
        console.log("\n=== STEP 3: Verifying Token-Bound Account Ownership ===");
        
        for (uint256 i = 0; i < projectIds.length; i++) {
            address projectOwner = carbonProjectNFT.ownerOf(projectIds[i]);
            console.log("Project", projectIds[i], "owner:", projectOwner);
            console.log("Expected owner (TBA):", tokenBoundAccount);
            require(projectOwner == tokenBoundAccount, "Project not owned by token-bound account");
        }
        console.log("All projects are owned by the token-bound account");

        // Step 4: Execute operations through the token-bound account
        console.log("\n=== STEP 4: Executing Operations Through Token-Bound Account ===");
        
        // Example: Check if projects are redeemable through the account
        for (uint256 i = 0; i < 2; i++) { // Just check first 2 projects
            bytes memory callData = abi.encodeWithSelector(
                CarbonProjectNFT.isProjectRedeemable.selector,
                projectIds[i]
            );
            
            bytes memory result = carbonBatchNFT.executeFromAccount(
                batchId,
                address(carbonProjectNFT),
                0,
                callData
            );
            
            bool isRedeemable = abi.decode(result, (bool));
            console.log("Project", projectIds[i], "redeemable:", isRedeemable);
        }

        // Step 5: Demonstrate project redemption through the batch
        console.log("\n=== STEP 5: Redeeming Projects Through Batch ===");
        
        uint256[] memory projectsToRedeem = new uint256[](2);
        projectsToRedeem[0] = projectIds[0];
        projectsToRedeem[1] = projectIds[1];
        
        batchController.redeemProjectsFromBatch(batchId, projectsToRedeem);
        console.log("Redeemed projects", projectsToRedeem[0], "and", projectsToRedeem[1]);
        
        // Verify redemption
        for (uint256 i = 0; i < 2; i++) {
            (, , , , , , , , , bool redeemed, ) = carbonProjectNFT.getProjectData(projectsToRedeem[i]);
            console.log("Project", projectsToRedeem[i], "redeemed status:", redeemed);
        }

        // Step 6: Finalize the batch
        console.log("\n=== STEP 6: Finalizing Batch ===");
        
        carbonBatchNFT.finalizeBatch(batchId);
        console.log("Batch", batchId, "has been finalized");

        vm.stopBroadcast();

        console.log("\n=== DEMO COMPLETED SUCCESSFULLY ===");
        console.log("Summary:");
        console.log("- Created 5 carbon project NFTs");
        console.log("- Created 1 batch NFT with ERC6551 token-bound account");
        console.log("- Transferred all projects to the token-bound account");
        console.log("- Executed operations through the token-bound account");
        console.log("- Redeemed 2 projects through the batch controller");
        console.log("- Finalized the batch");
        console.log("=====================================");
    }

    function setContractAddresses(
        address _carbonProjectNFT,
        address _carbonBatchNFT,
        address _erc6551Registry,
        address _batchController
    ) external {
        carbonProjectNFT = CarbonProjectNFT(_carbonProjectNFT);
        carbonBatchNFT = CarbonBatchNFT(_carbonBatchNFT);
        erc6551Registry = CarbonERC6551Registry(_erc6551Registry);
        batchController = CarbonBatchController(payable(_batchController));
    }
}