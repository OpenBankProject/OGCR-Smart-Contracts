// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../DeployTokenSystem.s.sol";

/// @notice Local fixture for a throwaway chain (anvil): deploys the whole token
/// family and mints one coherent set of records, parcel through activity and
/// certificate to two credit batches with their credits. Used by the chain
/// cache's integration tests. Never run this against a shared chain.
///
///   anvil --chain-id 2025
///   forge script script/local/DeployLocalStack.s.sol \
///     --rpc-url http://127.0.0.1:8545 --broadcast --legacy
///
/// PRIVATE_KEY defaults to anvil's first account. Addresses are written to
/// deployments/local-anvil.env.
contract DeployLocalStack is DeployTokenSystem {

    uint256 constant ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    string constant BASE = "http://localhost:8080/obp/dynamic-entity/banks/ogcr/";
    string constant HASH = "0x1111111111111111111111111111111111111111111111111111111111111111";

    function run() external override {
        uint256 key = vm.envOr("PRIVATE_KEY", ANVIL_KEY);
        address deployer = vm.addr(key);

        vm.startBroadcast(key);
        Deployment memory d = _deploy(deployer);
        _mintFixtures(d, deployer);
        vm.stopBroadcast();

        _writeEnv(d, "./deployments/local-anvil.env");
        vm.writeLine("./deployments/local-anvil.env", "RPC_URL=http://127.0.0.1:8545");
    }

    function _mintFixtures(Deployment memory d, address operator) internal {
        d.parcel.mint(operator, "parcel_LOCAL01", string(abi.encodePacked(BASE, "parcel/parcel_LOCAL01")), HASH);
        d.parcel.mint(operator, "parcel_LOCAL02", string(abi.encodePacked(BASE, "parcel/parcel_LOCAL02")), HASH);

        uint256 activityTokenId = d.activity.mint(operator, _activity());
        d.certification.mint(operator, _certificate(activityTokenId));

        (, address tba1) = d.batch.mint(operator, _batch(
            activityTokenId, "mv_LOCAL01:permanent_removal",
            "Permanent Removals Carbon Credit Batch", "Permanent Removal", 120.5e18));
        d.credit.mint(tba1, 120.5e18);

        (, address tba2) = d.batch.mint(operator, _batch(
            activityTokenId, "mv_LOCAL01:soil_emission_reduction",
            "Soil Emissions Reductions Carbon Credit Batch", "Soil Emission Reduction", 40e18));
        d.credit.mint(tba2, 40e18);
    }

    function _activity() internal pure returns (ActivityNFT.ActivityData memory a) {
        a.activity_id             = "a_LOCAL01";
        a.operator_id             = "op_LOCAL01";
        a.operator_name           = "Local Operator GmbH";
        a.name                    = "Local Peatland Rewetting";
        a.summary                 = "Rewetting of drained peat soils.";
        a.website                 = "https://example.org/local";
        a.activity_type           = "CARBON_FARMING";
        a.unit_types              = "Permanent Removal, Soil Emission Reduction";
        a.city                    = "Viborg";
        a.country_id              = "DK";
        a.certification_scheme_id = "cs_LOCAL01";
        a.parcel_ids              = new string[](2);
        a.parcel_ids[0]           = "parcel_LOCAL01";
        a.parcel_ids[1]           = "parcel_LOCAL02";
        a.start_date              = "2024-01-01";
        a.end_date                = "2033-12-31";
        a.activity_url            = string(abi.encodePacked(BASE, "activity/a_LOCAL01"));
        a.activity_hash           = HASH;
    }

    function _certificate(uint256 activityTokenId) internal pure returns (CertificationNFT.CertificationData memory c) {
        c.certificate_of_compliance_id   = "coc_LOCAL01";
        c.certificate_of_compliance_uri  = string(abi.encodePacked(BASE, "certificate_of_compliance/coc_LOCAL01"));
        c.certificate_of_compliance_hash = HASH;
        c.activity_id                    = "a_LOCAL01";
        c.activity_nft_id                = activityTokenId;
        c.activity_uri                   = string(abi.encodePacked(BASE, "activity/a_LOCAL01"));
        c.activity_hash                  = HASH;
        c.activity_name                  = "Local Peatland Rewetting";
        c.certification_scheme_name      = "CRCF Scheme";
        c.certification_scheme_uri       = string(abi.encodePacked(BASE, "certification_scheme/cs_LOCAL01"));
        c.certification_scheme_hash      = HASH;
        c.certification_body_name        = "Local Certification Body";
        c.certification_body_uri         = string(abi.encodePacked(BASE, "certification_body/cb_LOCAL01"));
        c.certification_body_hash        = HASH;
        c.country_id                     = "DK";
        c.issue_date                     = "2025-01-01";
        c.expiry_date                    = "2030-01-01";
        c.carbon_removals_under_baseline = "6.5";
        c.soil_emissions_under_baseline  = "1.25";
        c.permanent_net_carbon_removal_benefit = "120.5";
        c.carbon_farming_net_soil_emission_reduction_benefit = "40";
        c.unit_types                     = "Permanent Removal, Soil Emission Reduction";
        c.certification_status           = "certified";
    }

    function _batch(
        uint256 activityTokenId,
        string memory batchId,
        string memory batchName,
        string memory unitType,
        uint256 amount
    ) internal pure returns (CarbonCreditBatchNFT.BatchData memory b) {
        b.carbon_credit_batch_id         = batchId;
        b.batch_name                     = batchName;
        b.activity_id                    = "a_LOCAL01";
        b.activity_nft_id                = activityTokenId;
        b.activity_name                  = "Local Peatland Rewetting";
        b.activity_url                   = string(abi.encodePacked(BASE, "activity/a_LOCAL01"));
        b.activity_hash                  = HASH;
        b.country_id                     = "DK";
        b.operator_url                   = string(abi.encodePacked(BASE, "operator/op_LOCAL01"));
        b.operator_hash                  = HASH;
        b.certificate_of_compliance_uri  = string(abi.encodePacked(BASE, "certificate_of_compliance/coc_LOCAL01"));
        b.certificate_of_compliance_hash = HASH;
        b.unit_type                      = unitType;
        b.monitoring_period_start_date   = "2024-01-01";
        b.monitoring_period_end_date     = "2024-12-31";
        b.amount                         = amount;
        b.status_code                    = "issued";
        b.issue_date                     = "2025-01-01";
        b.expiry_date                    = "2030-01-01";
        b.certification_scheme_url       = string(abi.encodePacked(BASE, "certification_scheme/cs_LOCAL01"));
        b.certification_scheme_hash      = HASH;
        b.certification_body_url         = string(abi.encodePacked(BASE, "certification_body/cb_LOCAL01"));
        b.certification_body_hash        = HASH;
    }
}
