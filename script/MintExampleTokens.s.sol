// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/ParcelNFT.sol";
import "../src/ActivityNFT.sol";
import "../src/CertificationNFT.sol";
import "../src/CarbonCreditBatchNFT.sol";
import "../src/CarbonCredit.sol";

/// @notice Mints one clearly labelled example token on each contract of a
/// deployed token system: a parcel, an activity, a certificate, a credit batch
/// and that batch's credits. Every id starts with "example_" so it cannot
/// collide with a registry record, and the url/hash references are placeholders
/// that do not resolve.
///
///   PRIVATE_KEY   the minter (required)
///   RECIPIENT     owner of the example tokens (default: the minter)
///   plus the addresses from deployments/token-system-<chain id>.env
contract MintExampleTokens is Script {

    string constant BASE = "https://dcr.ogcr.tesobe.com/obp/dynamic-entity/banks/ogcr/";
    // Placeholder: there is no registry record behind an example token to hash.
    string constant HASH = "0x0000000000000000000000000000000000000000000000000000000000000000";

    string constant PARCEL_ID   = "example_parcel_01";
    string constant ACTIVITY_ID = "example_activity_01";
    string constant CERT_ID     = "example_certificate_01";
    string constant BATCH_ID    = "example_verification_01:permanent_removal";

    function run() external {
        uint256 key = vm.envUint("PRIVATE_KEY");
        address to = vm.envOr("RECIPIENT", vm.addr(key));

        ParcelNFT parcel            = ParcelNFT(vm.envAddress("PARCEL_CONTRACT_ADDRESS"));
        ActivityNFT activity        = ActivityNFT(vm.envAddress("ACTIVITY_CONTRACT_ADDRESS"));
        CertificationNFT cert       = CertificationNFT(vm.envAddress("CERTIFICATION_CONTRACT_ADDRESS"));
        CarbonCreditBatchNFT batch  = CarbonCreditBatchNFT(vm.envAddress("BATCH_CONTRACT_ADDRESS"));
        CarbonCredit credit         = CarbonCredit(vm.envAddress("CREDIT_CONTRACT_ADDRESS"));

        vm.startBroadcast(key);

        uint256 parcelToken = parcel.mint(to, PARCEL_ID, _url("parcel/", PARCEL_ID), HASH);
        uint256 activityToken = activity.mint(to, _activity());
        uint256 certToken = cert.mint(to, _certificate(activityToken));

        CarbonCreditBatchNFT.BatchData memory b = _batch(activityToken);
        (uint256 batchToken, address tba) = batch.mint(to, b);
        credit.mint(tba, b.amount);

        vm.stopBroadcast();

        console.log("Recipient:        ", to);
        console.log("ParcelNFT token:  ", parcelToken);
        console.log("ActivityNFT token:", activityToken);
        console.log("Certification:    ", certToken);
        console.log("Batch token:      ", batchToken);
        console.log("Batch account:    ", tba);
        console.log("Credits minted:   ", b.amount);
    }

    function _url(string memory entity, string memory id) internal pure returns (string memory) {
        return string(abi.encodePacked(BASE, entity, id));
    }

    function _activity() internal pure returns (ActivityNFT.ActivityData memory a) {
        a.activity_id             = ACTIVITY_ID;
        a.operator_id             = "example_operator_01";
        a.operator_name           = "Example Operator GmbH";
        a.name                    = "Example Peatland Rewetting";
        a.summary                 = "Example token. Rewetting of drained peat soils.";
        a.website                 = "https://example.org";
        a.activity_type           = "CARBON_FARMING";
        a.unit_types              = "Permanent Removal";
        a.city                    = "Viborg";
        a.country_id              = "DK";
        a.certification_scheme_id = "example_scheme_01";
        a.parcel_ids              = new string[](1);
        a.parcel_ids[0]           = PARCEL_ID;
        a.start_date              = "2024-01-01";
        a.end_date                = "2033-12-31";
        a.activity_url            = _url("activity/", ACTIVITY_ID);
        a.activity_hash           = HASH;
    }

    function _certificate(uint256 activityToken) internal pure returns (CertificationNFT.CertificationData memory c) {
        c.certificate_of_compliance_id   = CERT_ID;
        c.certificate_of_compliance_uri  = _url("certificate_of_compliance/", CERT_ID);
        c.certificate_of_compliance_hash = HASH;
        c.activity_id                    = ACTIVITY_ID;
        c.activity_nft_id                = activityToken;
        c.activity_uri                   = _url("activity/", ACTIVITY_ID);
        c.activity_hash                  = HASH;
        c.activity_name                  = "Example Peatland Rewetting";
        c.certification_scheme_name      = "Example Certification Scheme";
        c.certification_scheme_uri       = _url("certification_scheme/", "example_scheme_01");
        c.certification_scheme_hash      = HASH;
        c.certification_body_name        = "Example Certification Body";
        c.certification_body_uri         = _url("certification_body/", "example_body_01");
        c.certification_body_hash        = HASH;
        c.country_id                     = "DK";
        c.issue_date                     = "2025-01-01";
        c.expiry_date                    = "2030-01-01";
        c.audit_report_uri               = _url("audit_report/", "example_audit_report_01");
        c.audit_report_hash              = HASH;
        c.carbon_removals_under_baseline = "6.5";
        c.soil_emissions_under_baseline  = "1.25";
        c.permanent_net_carbon_removal_benefit = "10.5";
        c.unit_types                     = "Permanent Removal";
        c.certification_status           = "certified";
    }

    function _batch(uint256 activityToken) internal pure returns (CarbonCreditBatchNFT.BatchData memory b) {
        b.carbon_credit_batch_id         = BATCH_ID;
        b.batch_name                     = "Permanent Removals Carbon Credit Batch";
        b.activity_id                    = ACTIVITY_ID;
        b.activity_nft_id                = activityToken;
        b.activity_name                  = "Example Peatland Rewetting";
        b.activity_url                   = _url("activity/", ACTIVITY_ID);
        b.activity_hash                  = HASH;
        b.country_id                     = "DK";
        b.operator_url                   = _url("operator/", "example_operator_01");
        b.operator_hash                  = HASH;
        b.certificate_of_compliance_uri  = _url("certificate_of_compliance/", CERT_ID);
        b.certificate_of_compliance_hash = HASH;
        b.unit_type                      = "Permanent Removal";
        b.monitoring_period_start_date   = "2024-01-01";
        b.monitoring_period_end_date     = "2024-12-31";
        b.amount                         = 10.5e18; // 10.5 tonnes CO2e
        b.status_code                    = "issued";
        b.issue_date                     = "2025-01-01";
        b.expiry_date                    = "2030-01-01";
        b.certification_scheme_url       = _url("certification_scheme/", "example_scheme_01");
        b.certification_scheme_hash      = HASH;
        b.certification_body_url         = _url("certification_body/", "example_body_01");
        b.certification_body_hash        = HASH;
    }
}
