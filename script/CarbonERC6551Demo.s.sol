// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/CarbonProjectNFT.sol";
import "../src/CarbonBatchNFT.sol";
import "../src/CarbonERC6551Registry.sol";
import "../src/CarbonERC6551Account.sol";
import "../src/CarbonBatchController.sol";

contract CarbonERC6551Demo is Script {

    CarbonProjectNFT carbonProjectNFT;
    CarbonBatchNFT carbonBatchNFT;
    CarbonERC6551Registry erc6551Registry;
    CarbonERC6551Account accountImplementation;
    CarbonBatchController batchController;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Starting Carbon ERC6551 Demo...");
        console.log("Demo user address:", deployer);

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

        console.log("\n=== STEP 1: Creating Carbon Projects ===");

        uint256[] memory projectIds = new uint256[](5);

        projectIds[0] = carbonProjectNFT.mintCarbonProject(
            deployer, "parcel-001", 1000, "Reforestation", "VCS", "2024",
            "ogcr://activity/act-demo/parcel/parcel-001"
        );
        console.log("Created project:", projectIds[0]);

        projectIds[1] = carbonProjectNFT.mintCarbonProject(
            deployer, "parcel-002", 1500, "Reforestation", "VCS", "2024",
            "ogcr://activity/act-demo/parcel/parcel-002"
        );
        console.log("Created project:", projectIds[1]);

        projectIds[2] = carbonProjectNFT.mintCarbonProject(
            deployer, "parcel-003", 2000, "Reforestation", "VCS", "2024",
            "ogcr://activity/act-demo/parcel/parcel-003"
        );
        console.log("Created project:", projectIds[2]);

        projectIds[3] = carbonProjectNFT.mintCarbonProject(
            deployer, "parcel-004", 800, "Reforestation", "Gold Standard", "2024",
            "ogcr://activity/act-demo/parcel/parcel-004"
        );
        console.log("Created project:", projectIds[3]);

        projectIds[4] = carbonProjectNFT.mintCarbonProject(
            deployer, "parcel-005", 1200, "Reforestation", "VCS", "2024",
            "ogcr://activity/act-demo/parcel/parcel-005"
        );
        console.log("Created project:", projectIds[4]);

        console.log("\n=== STEP 2: Creating Carbon Batch with ERC6551 Account ===");

        uint256 batchId = batchController.createBatchWithProjects(
            "Reforestation",
            "2024",
            "https://metadata.carbon.com/batch/1",
            projectIds,
            true
        );
        console.log("Created batch with ID:", batchId);

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

        console.log("\n=== STEP 3: Verifying Token-Bound Account Ownership ===");

        for (uint256 i = 0; i < projectIds.length; i++) {
            address projectOwner = carbonProjectNFT.ownerOf(projectIds[i]);
            require(projectOwner == tokenBoundAccount, "Project not owned by token-bound account");
            console.log("Project", projectIds[i], "owned by TBA: OK");
        }

        console.log("\n=== STEP 4: Finalizing Batch ===");

        carbonBatchNFT.finalizeBatch(batchId);
        console.log("Batch", batchId, "finalized");

        vm.stopBroadcast();

        console.log("\n=== DEMO COMPLETED SUCCESSFULLY ===");
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
