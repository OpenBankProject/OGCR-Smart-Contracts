// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/CarbonProjectNFT.sol";
import "../src/CarbonBatchNFT.sol";
import "../src/CarbonERC6551Registry.sol";
import "../src/CarbonERC6551Account.sol";
import "../src/CarbonBatchController.sol";

/**
 * @title DeployCarbonERC6551System
 * @dev Script to deploy the complete Carbon ERC6551 system
 */
contract DeployCarbonERC6551System is Script {
    
    CarbonProjectNFT public carbonProjectNFT;
    CarbonBatchNFT public carbonBatchNFT;
    CarbonERC6551Registry public erc6551Registry;
    CarbonERC6551Account public accountImplementation;
    CarbonBatchController public batchController;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying Carbon ERC6551 System...");
        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy CarbonProjectNFT (if not already deployed)
        console.log("Deploying CarbonProjectNFT...");
        carbonProjectNFT = new CarbonProjectNFT();
        console.log("CarbonProjectNFT deployed at:", address(carbonProjectNFT));

        // 2. Deploy ERC6551 Registry
        console.log("Deploying CarbonERC6551Registry...");
        erc6551Registry = new CarbonERC6551Registry();
        console.log("CarbonERC6551Registry deployed at:", address(erc6551Registry));

        // 3. Deploy Account Implementation
        console.log("Deploying CarbonERC6551Account implementation...");
        accountImplementation = new CarbonERC6551Account();
        console.log("CarbonERC6551Account implementation deployed at:", address(accountImplementation));

        // 4. Deploy CarbonBatchNFT
        console.log("Deploying CarbonBatchNFT...");
        carbonBatchNFT = new CarbonBatchNFT(
            address(erc6551Registry),
            address(accountImplementation)
        );
        console.log("CarbonBatchNFT deployed at:", address(carbonBatchNFT));

        // 5. Deploy CarbonBatchController
        console.log("Deploying CarbonBatchController...");
        batchController = new CarbonBatchController(
            address(carbonProjectNFT),
            address(carbonBatchNFT),
            address(erc6551Registry),
            address(accountImplementation)
        );
        console.log("CarbonBatchController deployed at:", address(batchController));

        // 6. Setup permissions
        console.log("Setting up permissions...");
        
        // Allow the batch controller to create batches
        carbonBatchNFT.transferOwnership(address(batchController));
        console.log("CarbonBatchNFT ownership transferred to CarbonBatchController");

        // Allow the batch controller to mark projects as redeemed
        carbonProjectNFT.setAuthorizedRedeemer(address(batchController), true);
        console.log("CarbonBatchController authorized as redeemer for CarbonProjectNFT");

        vm.stopBroadcast();

        // Log deployment summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("CarbonProjectNFT:", address(carbonProjectNFT));
        console.log("CarbonERC6551Registry:", address(erc6551Registry));
        console.log("CarbonERC6551Account (implementation):", address(accountImplementation));
        console.log("CarbonBatchNFT:", address(carbonBatchNFT));
        console.log("CarbonBatchController:", address(batchController));
        console.log("========================\n");

        // Save deployment addresses to a file
        string memory deploymentInfo = string(abi.encodePacked(
            "# Carbon ERC6551 System Deployment\n\n",
            "## Contract Addresses\n",
            "- CarbonProjectNFT: ", vm.toString(address(carbonProjectNFT)), "\n",
            "- CarbonERC6551Registry: ", vm.toString(address(erc6551Registry)), "\n",
            "- CarbonERC6551Account: ", vm.toString(address(accountImplementation)), "\n",
            "- CarbonBatchNFT: ", vm.toString(address(carbonBatchNFT)), "\n",
            "- CarbonBatchController: ", vm.toString(address(batchController)), "\n\n",
            "## Deployment Date\n",
            vm.toString(block.timestamp), "\n\n",
            "## Chain ID\n",
            vm.toString(block.chainid)
        ));

        vm.writeFile("./deployments/carbon-erc6551-deployment.md", deploymentInfo);
        console.log("Deployment info saved to ./deployments/carbon-erc6551-deployment.md");
    }
}