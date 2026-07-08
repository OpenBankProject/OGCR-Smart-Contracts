// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/ParcelNFT.sol";

contract DeployParcelNFT is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer:", deployer);
        console.log("Balance: ", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);
        // Deployer is the initial minter; call setMinter() once the tokenizer is live.
        ParcelNFT parcelNFT = new ParcelNFT(deployer);
        vm.stopBroadcast();

        console.log("ParcelNFT deployed at:", address(parcelNFT));

        vm.writeFile(
            "./deployments/parcel-nft-deployment.md",
            string(abi.encodePacked(
                "# ParcelNFT Deployment\n\n",
                "- ParcelNFT: ", vm.toString(address(parcelNFT)), "\n",
                "- Chain ID: ", vm.toString(block.chainid), "\n",
                "- Timestamp: ", vm.toString(block.timestamp), "\n"
            ))
        );
    }
}
