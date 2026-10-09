// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/ParcelNFT.sol";
import "../src/ActivityNFT.sol";
import "../src/CertificationNFT.sol";
import "../src/CarbonCreditBatchNFT.sol";
import "../src/CarbonCredit.sol";
import "../src/CarbonERC6551Registry.sol";
import "../src/CarbonERC6551Account.sol";

/// @notice Deploys the OGCR token family and writes every address to an env
/// file the tokenizer and the chain cache can load.
///
///   PRIVATE_KEY              deployer (required)
///   MINTER_ADDRESS           minter on every contract (default: the deployer)
///   PARCEL_CONTRACT_ADDRESS  reuse an already deployed ParcelNFT instead of
///                            deploying a new one (its minter is left as it is)
contract DeployTokenSystem is Script {

    struct Deployment {
        ParcelNFT parcel;
        ActivityNFT activity;
        CertificationNFT certification;
        CarbonCreditBatchNFT batch;
        CarbonCredit credit;
        CarbonERC6551Registry registry;
        CarbonERC6551Account accountImpl;
    }

    function run() external virtual {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address minter = vm.envOr("MINTER_ADDRESS", deployer);

        console.log("Deployer:", deployer);
        console.log("Minter:  ", minter);

        vm.startBroadcast(deployerPrivateKey);
        Deployment memory d = _deploy(minter);
        vm.stopBroadcast();

        _writeEnv(d, string(abi.encodePacked("./deployments/token-system-", vm.toString(block.chainid), ".env")));
    }

    function _deploy(address minter) internal returns (Deployment memory d) {
        address existingParcel = vm.envOr("PARCEL_CONTRACT_ADDRESS", address(0));
        d.parcel = existingParcel == address(0) ? new ParcelNFT(minter) : ParcelNFT(existingParcel);

        d.activity      = new ActivityNFT(minter);
        d.certification = new CertificationNFT(minter);
        d.registry      = new CarbonERC6551Registry();
        d.accountImpl   = new CarbonERC6551Account();
        d.batch         = new CarbonCreditBatchNFT(address(d.registry), address(d.accountImpl), minter);
        d.credit        = new CarbonCredit(minter);
    }

    function _writeEnv(Deployment memory d, string memory path) internal {
        string memory batch = vm.toString(address(d.batch));
        bytes memory out = abi.encodePacked(
            "# OGCR token system, chain ", vm.toString(block.chainid), ", block ", vm.toString(block.number), "\n",
            "PARCEL_CONTRACT_ADDRESS=", vm.toString(address(d.parcel)), "\n",
            "ACTIVITY_CONTRACT_ADDRESS=", vm.toString(address(d.activity)), "\n",
            "CERTIFICATION_CONTRACT_ADDRESS=", vm.toString(address(d.certification)), "\n"
        );
        // The tokenizer reads BATCH_CONTRACT_ADDRESS, the chain cache
        // CREDIT_BATCH_CONTRACT_ADDRESS; both name the same contract.
        out = abi.encodePacked(
            out,
            "BATCH_CONTRACT_ADDRESS=", batch, "\n",
            "CREDIT_BATCH_CONTRACT_ADDRESS=", batch, "\n",
            "CREDIT_CONTRACT_ADDRESS=", vm.toString(address(d.credit)), "\n",
            "ERC6551_REGISTRY_ADDRESS=", vm.toString(address(d.registry)), "\n",
            "ERC6551_ACCOUNT_IMPLEMENTATION_ADDRESS=", vm.toString(address(d.accountImpl)), "\n"
        );
        vm.writeFile(path, string(out));
        console.log("Addresses written to", path);
    }
}
