// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../../src/ParcelNFT.sol";
import "../../src/ActivityNFT.sol";
import "../../src/CertificationNFT.sol";
import "../../src/CarbonERC6551Registry.sol";
import "../../src/CarbonERC6551Account.sol";
import "../../src/CarbonCreditBatchNFT.sol";
import "../../src/CarbonCredit.sol";

/// @title DeployLocalStack
/// @notice Local development fixture. Deploys the whole OGCR token family to a
///         throwaway chain and seeds one coherent chain of records:
///
///           parcel -> activity -> certificate of compliance -> credit batch
///                                                                  |
///                                                       ERC-6551 bound account
///                                                          holding CarbonCredit
///
///         It exists so the off-chain services (OGCR-chain-cache, and through it
///         the marketplace) have something real to read without the Besu network
///         being up. It is NOT a production deployment script.
///
///         The registry ids it mints against come from the environment, because
///         the real tokenizer mints tokens *for records that already exist in
///         OBP*. Inventing ids here would produce a chain that references
///         registry records that do not exist, and every link from a token back
///         to the registry would 404. The launcher
///         (commands/_helpers/start_ogcr_chain.sh) reads real ids from the local
///         OBP and passes them in; the fallbacks below only exist so the script
///         still runs standalone, and it warns when it uses them.
///
/// @dev Anvil assigns contract addresses deterministically from the deployer and
///      its nonce, so a fresh chain plus this script always yields the same
///      addresses. That is what lets the generated env file be committed to a
///      developer's local config once and stay valid across restarts.
///
///      Usage:
///        anvil --chain-id 2025
///        forge script script/local/DeployLocalStack.s.sol \
///          --rpc-url http://127.0.0.1:8545 --broadcast --legacy
///
///      Addresses are written to deployments/local-anvil.env, which is shell
///      sourceable and can be pasted straight into OGCR-chain-cache/.env.
contract DeployLocalStack is Script {
    // Anvil's first three accounts. Their private keys are published in the
    // Foundry docs, which is exactly why they are safe to hardcode and why the
    // guard below can use account zero to prove we are on a throwaway chain.
    address internal constant ANVIL_0 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address internal constant ANVIL_1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address internal constant ANVIL_2 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

    uint256 internal constant ANVIL_0_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    struct Deployed {
        ParcelNFT parcel;
        ActivityNFT activity;
        CertificationNFT certification;
        CarbonCreditBatchNFT batch;
        CarbonCredit credit;
        address registry;
        address accountImpl;
    }

    /// Base URL the on-chain `*_url` fields point back at. Override with OBP_URL
    /// to match wherever your local OBP is listening.
    string internal obpURL;

    /// The node this ran against, echoed into the generated env file so consumers
    /// do not have to guess it. Taken from RPC_URL, which the launcher exports;
    /// hardcoding it here would silently be wrong on a non-default port.
    string internal rpcURL;

    /// Registry ids to mint against. Real ones when the launcher supplied them.
    struct Registry {
        string parcelId;
        string activityId;
        string activityName;
        string operatorId;
        string cocId;
        string schemeId;
        string bodyId;
        bool real;
    }

    Registry internal reg;

    function run() external {
        uint256 pk = vm.envOr("PRIVATE_KEY", ANVIL_0_KEY);
        address deployer = vm.addr(pk);

        // Refuse to run anywhere that is not a throwaway chain. Anvil's account
        // zero has a published private key, so its presence is proof that no
        // real value is at stake here. Deploying this fixture against the shared
        // OGCR chain would mint duplicate tokens over the real ones.
        require(
            deployer == ANVIL_0,
            "DeployLocalStack is local-only: expected anvil account 0 as deployer. Use the production deploy scripts for a real chain."
        );

        obpURL = vm.envOr("OBP_URL", string("http://localhost:8080"));
        rpcURL = vm.envOr("RPC_URL", string("http://127.0.0.1:8545"));

        reg = Registry({
            parcelId: vm.envOr("OGCR_PARCEL_ID", string("")),
            activityId: vm.envOr("OGCR_ACTIVITY_ID", string("")),
            activityName: vm.envOr("OGCR_ACTIVITY_NAME", string("Local Fixture Activity")),
            operatorId: vm.envOr("OGCR_OPERATOR_ID", string("")),
            cocId: vm.envOr("OGCR_COC_ID", string("")),
            schemeId: vm.envOr("OGCR_SCHEME_ID", string("")),
            bodyId: vm.envOr("OGCR_BODY_ID", string("body_local_1")),
            real: true
        });

        // Any missing id means this is not mirroring real registry records, so
        // say so loudly: the resulting chain will reference registry entries
        // that do not exist and links back to them will 404.
        if (
            bytes(reg.parcelId).length == 0 ||
            bytes(reg.activityId).length == 0 ||
            bytes(reg.operatorId).length == 0 ||
            bytes(reg.cocId).length == 0
        ) {
            reg.real = false;
            if (bytes(reg.parcelId).length == 0) reg.parcelId = "parcel_local_1";
            if (bytes(reg.activityId).length == 0) reg.activityId = "activity_local_1";
            if (bytes(reg.operatorId).length == 0) reg.operatorId = "op_local_1";
            if (bytes(reg.cocId).length == 0) reg.cocId = "coc_local_1";
            if (bytes(reg.schemeId).length == 0) reg.schemeId = "scheme_local_1";
        }

        vm.startBroadcast(pk);
        Deployed memory d = _deploy(deployer);
        _seed(d, deployer);
        vm.stopBroadcast();

        _report(d, deployer);
    }

    function _deploy(address minter) internal returns (Deployed memory d) {
        d.parcel = new ParcelNFT(minter);
        d.activity = new ActivityNFT(minter);
        d.certification = new CertificationNFT(minter);

        CarbonERC6551Account impl = new CarbonERC6551Account();
        CarbonERC6551Registry registry = new CarbonERC6551Registry();
        d.accountImpl = address(impl);
        d.registry = address(registry);

        d.batch = new CarbonCreditBatchNFT(address(registry), address(impl), minter);
        d.credit = new CarbonCredit(minter);
    }

    function _seed(Deployed memory d, address operatorWallet) internal {
        // One coherent chain of records, mirroring how the real pipeline works:
        // a parcel and an activity exist in the registry, the activity is
        // certified, and credits are issued against that certified activity.
        d.parcel.mint(operatorWallet, reg.parcelId, _url("parcel", reg.parcelId), _hash("parcel"));

        uint256 activityTokenID = d.activity.mint(
            operatorWallet,
            reg.activityId,
            reg.operatorId,
            reg.activityName,
            "carbon_farming",
            "2026-01-01",
            "2026-12-31",
            _url("activity", reg.activityId),
            _hash("activity")
        );

        d.certification.mint(
            operatorWallet,
            activityTokenID,
            reg.schemeId,
            reg.bodyId,
            reg.cocId,
            "2026-06-01",
            "2031-06-01",
            "active",
            _url("activity", reg.activityId),
            _hash("activity"),
            _url("certificate_of_compliance", reg.cocId),
            _hash("certificate")
        );

        // Two batches on the same activity. The contract allows exactly one per
        // (activity, credit_type) pair, so differing credit types is the only
        // way to have more than one, and it exercises the categories the
        // marketplace filters on.
        // Credit type names must match the tokenizer's, which derives them from the
        // benefit fields on a monitoring period verification (see CreditAmounts()).
        // Inventing names here produced batches the real tokenizer would never
        // create, sitting alongside the ones it does.
        address tba1 = _mintBatch(d, operatorWallet, activityTokenID, "permanent_net_carbon_removal_benefit");
        address tba2 = _mintBatch(
            d, operatorWallet, activityTokenID, "carbon_farming_net_soil_emission_reduction_benefit"
        );

        d.credit.mint(tba1, 5 ether);
        d.credit.mint(tba2, 3 ether);

        // A wallet holding and a wallet-to-wallet transfer, so the Transfer log
        // has a non-zero `from`. Together with the two above these exercise both
        // holder types the cache distinguishes: credits still inside a batch,
        // and credits withdrawn into a pooled wallet balance.
        d.credit.mint(operatorWallet, 2 ether);
        d.credit.transfer(ANVIL_1, 1 ether);

        // A holder whose balance is zero, to prove zero balances are mirrored
        // rather than silently dropped.
        d.credit.mint(ANVIL_2, 0);
    }

    function _mintBatch(
        Deployed memory d,
        address operatorWallet,
        uint256 activityTokenID,
        string memory creditType
    ) internal returns (address tba) {
        (, tba) = d.batch.mint(
            operatorWallet,
            activityTokenID,
            creditType,
            _url("activity", reg.activityId),
            _hash("activity"),
            _url("operator", reg.operatorId),
            _hash("operator"),
            _url("certificate_of_compliance", reg.cocId),
            _hash("certificate"),
            _url("certification_scheme", reg.schemeId),
            _hash("scheme"),
            _url("certification_body_auditors", reg.bodyId),
            _hash("body")
        );
    }

    function _url(string memory entity, string memory id) internal view returns (string memory) {
        return string.concat(obpURL, "/obp/dynamic-entity/", entity, "/", id);
    }

    /// Placeholder integrity hash. The real one is keccak256 of the OBP entity
    /// body, which this fixture has no way to compute; only the shape matters
    /// for local testing.
    function _hash(string memory kind) internal view returns (string memory) {
        return vm.toString(keccak256(abi.encodePacked(kind, reg.activityId)));
    }

    function _report(Deployed memory d, address deployer) internal {
        string memory env = string.concat(
            "# Generated by script/local/DeployLocalStack.s.sol. Local anvil only.\n",
            "# Regenerated on every run; addresses are stable for a fresh chain.\n",
            "RPC_URL=", rpcURL, "\n",
            "PARCEL_CONTRACT_ADDRESS=", vm.toString(address(d.parcel)), "\n",
            "ACTIVITY_CONTRACT_ADDRESS=", vm.toString(address(d.activity)), "\n",
            "CERTIFICATION_CONTRACT_ADDRESS=", vm.toString(address(d.certification)), "\n",
            "CREDIT_BATCH_CONTRACT_ADDRESS=", vm.toString(address(d.batch)), "\n",
            "CREDIT_CONTRACT_ADDRESS=", vm.toString(address(d.credit)), "\n",
            "ERC6551_REGISTRY_ADDRESS=", vm.toString(d.registry), "\n",
            "ERC6551_ACCOUNT_IMPL_ADDRESS=", vm.toString(d.accountImpl), "\n",
            "OPERATOR_WALLET_ADDRESS=", vm.toString(deployer), "\n"
        );
        vm.writeFile("./deployments/local-anvil.env", env);

        console.log("");
        console.log("OGCR local stack deployed to chain", block.chainid);
        console.log("  ParcelNFT            ", address(d.parcel));
        console.log("  ActivityNFT          ", address(d.activity));
        console.log("  CertificationNFT     ", address(d.certification));
        console.log("  CarbonCreditBatchNFT ", address(d.batch));
        console.log("  CarbonCredit         ", address(d.credit));
        console.log("  operator wallet      ", deployer);
        console.log("  registry ids         %s", reg.real ? "real (from the local OBP)" : "PLACEHOLDER");
        console.log("");
        if (!reg.real) {
            console.log("WARNING: minted against placeholder registry ids.");
            console.log("  The chain now references registry records that do not exist,");
            console.log("  so links from a token back to the registry will 404.");
            console.log("  Set OGCR_PARCEL_ID / OGCR_ACTIVITY_ID / OGCR_OPERATOR_ID / OGCR_COC_ID.");
            console.log("");
        }
        console.log("Wrote deployments/local-anvil.env");
    }
}
