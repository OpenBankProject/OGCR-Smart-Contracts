// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/ActivityNFT.sol";
import "../src/CertificationNFT.sol";
import "../src/CarbonCreditBatchNFT.sol";
import "../src/CarbonCredit.sol";
import "../src/CarbonERC6551Registry.sol";
import "../src/CarbonERC6551Account.sol";

contract OGCRTokenSystemTest is Test {

    ActivityNFT public activityNFT;
    CertificationNFT public certificationNFT;
    CarbonCreditBatchNFT public batchNFT;
    CarbonCredit public carbonCredit;
    CarbonERC6551Registry public registry;
    CarbonERC6551Account public accountImpl;

    address public owner    = address(0x1);
    address public minter   = address(0x2);
    address public user1    = address(0x3);
    address public stranger = address(0x4);

    string constant ACTIVITY_ID   = "act-uuid-abc-123";
    string constant OPERATOR_ID   = "op-uuid-def-456";
    string constant ACTIVITY_URL  = "https://api.ogcr.example/activities/act-uuid-abc-123";
    string constant ACTIVITY_HASH = "sha256:a1b2c3d4e5f6";
    string constant CERT_ID       = "coc-uuid-789";
    string constant CERT_URL      = "https://api.ogcr.example/certificates/coc-uuid-789";
    string constant CERT_HASH     = "sha256:f6e5d4c3b2a1";
    string constant BATCH_ID      = "ccb-uuid-001";
    string constant UNIT_TYPE     = "Permanent Removal";

    function setUp() public {
        vm.startPrank(owner);

        registry    = new CarbonERC6551Registry();
        accountImpl = new CarbonERC6551Account();

        // Minter address is enforced at construction time — no post-deploy setMinter needed
        activityNFT      = new ActivityNFT(minter);
        certificationNFT = new CertificationNFT(minter);
        batchNFT         = new CarbonCreditBatchNFT(address(registry), address(accountImpl), minter);
        carbonCredit     = new CarbonCredit(minter);

        vm.stopPrank();
    }

    // ─── Deployment ───────────────────────────────────────────────────────────

    function testDeployment() public view {
        assertEq(activityNFT.name(),        "OGCR Activity");
        assertEq(activityNFT.symbol(),      "ACT");
        assertEq(certificationNFT.name(),   "OGCR Certification");
        assertEq(certificationNFT.symbol(), "CERT");
        assertEq(batchNFT.name(),           "OGCR Carbon Credit Batch");
        assertEq(batchNFT.symbol(),         "CCB");
        assertEq(carbonCredit.name(),       "Carbon Credit");
        assertEq(carbonCredit.symbol(),     "CC");
        assertEq(carbonCredit.decimals(),   18);

        assertEq(activityNFT.minter(),      minter);
        assertEq(certificationNFT.minter(), minter);
        assertEq(batchNFT.minter(),         minter);
        assertEq(carbonCredit.minter(),     minter);
    }

    // ─── Fixtures ─────────────────────────────────────────────────────────────

    function _activityData(string memory activityId) internal pure returns (ActivityNFT.ActivityData memory d) {
        d.activity_id             = activityId;
        d.operator_id             = OPERATOR_ID;
        d.operator_name           = "Alpha Forestry GmbH";
        d.name                    = "Reforestation Project Alpha";
        d.summary                 = "Rewetting of drained peat soils.";
        d.website                 = "https://alpha.example";
        d.activity_type           = "CARBON_FARMING";
        d.unit_types              = "Carbon Farming Sequestration";
        d.city                    = "Viborg";
        d.country_id              = "DK";
        d.certification_scheme_id = "cs-001";
        d.parcel_ids              = new string[](2);
        d.parcel_ids[0]           = "parcel-1";
        d.parcel_ids[1]           = "parcel-2";
        d.start_date              = "2024-01-01";
        d.end_date                = "2026-12-31";
        d.activity_url            = ACTIVITY_URL;
        d.activity_hash           = ACTIVITY_HASH;
    }

    function _certData(string memory certId, uint256 activityTokenId)
        internal pure returns (CertificationNFT.CertificationData memory d)
    {
        d.certificate_of_compliance_id   = certId;
        d.certificate_of_compliance_uri  = CERT_URL;
        d.certificate_of_compliance_hash = CERT_HASH;
        d.activity_id                    = ACTIVITY_ID;
        d.activity_nft_id                = activityTokenId;
        d.activity_uri                   = ACTIVITY_URL;
        d.activity_hash                  = ACTIVITY_HASH;
        d.activity_name                  = "Reforestation Project Alpha";
        d.certification_scheme_name      = "CRCF Scheme";
        d.certification_scheme_uri       = "https://api.ogcr.example/schemes/cs-001";
        d.certification_scheme_hash      = "sha256:cs001hash";
        d.certification_body_name        = "DNV Business Assurance";
        d.certification_body_uri         = "https://api.ogcr.example/bodies/cb-001";
        d.certification_body_hash        = "sha256:cb001hash";
        d.country_id                     = "DK";
        d.issue_date                     = "2025-01-01";
        d.expiry_date                    = "2028-01-01";
        d.audit_report_uri               = "https://api.ogcr.example/audit-reports/ar-001";
        d.audit_report_hash              = "sha256:ar001hash";
        d.carbon_removals_under_baseline = "6.5";
        d.soil_emissions_under_baseline  = "1.25";
        d.permanent_net_carbon_removal_benefit = "120.5";
        d.unit_types                     = "Permanent Removal";
        d.certification_status           = "certified";
    }

    function _batchData(string memory batchId, uint256 activityTokenId)
        internal pure returns (CarbonCreditBatchNFT.BatchData memory d)
    {
        d.carbon_credit_batch_id         = batchId;
        d.batch_name                     = "Permanent Removals Carbon Credit Batch";
        d.activity_id                    = ACTIVITY_ID;
        d.activity_nft_id                = activityTokenId;
        d.activity_name                  = "Reforestation Project Alpha";
        d.activity_url                   = ACTIVITY_URL;
        d.activity_hash                  = ACTIVITY_HASH;
        d.country_id                     = "DK";
        d.operator_url                   = "https://api.ogcr.example/operators/op-001";
        d.operator_hash                  = "sha256:op001hash";
        d.certificate_of_compliance_uri  = CERT_URL;
        d.certificate_of_compliance_hash = CERT_HASH;
        d.unit_type                      = UNIT_TYPE;
        d.monitoring_period_start_date   = "2024-01-01";
        d.monitoring_period_end_date     = "2024-12-31";
        d.amount                         = 500e18;
        d.status_code                    = "issued";
        d.issue_date                     = "2025-01-15";
        d.expiry_date                    = "2028-01-01";
        d.certification_scheme_url       = "https://api.ogcr.example/schemes/cs-001";
        d.certification_scheme_hash      = "sha256:cs001hash";
        d.certification_body_url         = "https://api.ogcr.example/bodies/cb-001";
        d.certification_body_hash        = "sha256:cb001hash";
    }

    function _mintActivity() internal returns (uint256) {
        vm.prank(minter);
        return activityNFT.mint(user1, _activityData(ACTIVITY_ID));
    }

    function _mintBatch(uint256 activityTokenId) internal returns (uint256 tokenId, address tba) {
        vm.prank(minter);
        return batchNFT.mint(user1, _batchData(BATCH_ID, activityTokenId));
    }

    /// @dev Decodes a `data:application/json;base64,` tokenURI and checks it parses as JSON.
    function _metadata(string memory uri) internal pure returns (string memory json) {
        bytes memory u = bytes(uri);
        uint256 offset = 29; // length of the data-URI prefix
        bytes memory out = new bytes(((u.length - offset) / 4) * 3);
        uint256 j = 0;
        for (uint256 i = offset; i < u.length; i += 4) {
            uint256 chunk = (_b64(u[i]) << 18) | (_b64(u[i + 1]) << 12) | (_b64(u[i + 2]) << 6) | _b64(u[i + 3]);
            out[j++] = bytes1(uint8(chunk >> 16));
            out[j++] = bytes1(uint8(chunk >> 8));
            out[j++] = bytes1(uint8(chunk));
        }
        if (u[u.length - 1] == "=") j--;
        if (u[u.length - 2] == "=") j--;
        assembly ("memory-safe") {
            mstore(out, j)
        }
        json = string(out);
        vm.parseJson(json);
    }

    function _b64(bytes1 c) private pure returns (uint256) {
        uint8 v = uint8(c);
        if (v >= 65 && v <= 90) return v - 65;       // A-Z
        if (v >= 97 && v <= 122) return v - 71;      // a-z
        if (v >= 48 && v <= 57) return v + 4;        // 0-9
        if (v == 43) return 62;                      // +
        if (v == 47) return 63;                      // /
        return 0;                                    // = padding
    }

    // ─── ActivityNFT ──────────────────────────────────────────────────────────

    function testActivityMint() public {
        uint256 tokenId = _mintActivity();

        assertEq(tokenId, 1);
        assertEq(activityNFT.ownerOf(tokenId), user1);
    }

    function testActivityDataStored() public {
        uint256 tokenId = _mintActivity();

        ActivityNFT.ActivityData memory data = activityNFT.getActivity(tokenId);

        assertEq(data.activity_id,             ACTIVITY_ID);
        assertEq(data.operator_id,             OPERATOR_ID);
        assertEq(data.operator_name,           "Alpha Forestry GmbH");
        assertEq(data.name,                    "Reforestation Project Alpha");
        assertEq(data.summary,                 "Rewetting of drained peat soils.");
        assertEq(data.website,                 "https://alpha.example");
        assertEq(data.activity_type,           "CARBON_FARMING");
        assertEq(data.unit_types,              "Carbon Farming Sequestration");
        assertEq(data.city,                    "Viborg");
        assertEq(data.country_id,              "DK");
        assertEq(data.certification_scheme_id, "cs-001");
        assertEq(data.parcel_ids.length,       2);
        assertEq(data.parcel_ids[0],           "parcel-1");
        assertEq(data.parcel_ids[1],           "parcel-2");
        assertEq(data.start_date,              "2024-01-01");
        assertEq(data.end_date,                "2026-12-31");
        assertEq(data.activity_url,            ACTIVITY_URL);
        assertEq(data.activity_hash,           ACTIVITY_HASH);
    }

    function testActivityTokenURI() public {
        ActivityNFT.ActivityData memory d = _activityData(ACTIVITY_ID);
        d.summary = "Line one\nLine \"two\"";
        vm.prank(minter);
        uint256 tokenId = activityNFT.mint(user1, d);

        string memory json = _metadata(activityNFT.tokenURI(tokenId));

        assertEq(vm.parseJsonString(json, ".name"), "Reforestation Project Alpha");
        assertEq(vm.parseJsonString(json, ".attributes[2].value"), "Alpha Forestry GmbH");
        assertEq(vm.parseJsonString(json, ".attributes[4].value"), "Line one Line \"two\"");
        assertEq(vm.parseJsonString(json, ".attributes[11].trait_type"), "Parcels");
        assertEq(vm.parseJsonString(json, ".attributes[11].value"), "parcel-1,parcel-2");
    }

    function testActivityWithoutParcels() public {
        ActivityNFT.ActivityData memory d = _activityData(ACTIVITY_ID);
        d.parcel_ids = new string[](0);
        vm.prank(minter);
        uint256 tokenId = activityNFT.mint(user1, d);

        assertEq(activityNFT.getActivity(tokenId).parcel_ids.length, 0);
        _metadata(activityNFT.tokenURI(tokenId));
    }

    function testActivityReverseMapping() public {
        uint256 tokenId = _mintActivity();

        assertEq(activityNFT.tokenIdByActivityId(ACTIVITY_ID), tokenId);
        assertEq(activityNFT.tokenIdByActivityId("nonexistent-id"), 0);
    }

    function testActivityDuplicatePrevented() public {
        _mintActivity();

        vm.prank(minter);
        vm.expectRevert("ActivityNFT: already minted");
        activityNFT.mint(user1, _activityData(ACTIVITY_ID));
    }

    function testActivityOnlyMinterCanMint() public {
        vm.prank(stranger);
        vm.expectRevert("ActivityNFT: caller is not minter");
        activityNFT.mint(user1, _activityData(ACTIVITY_ID));
    }

    function testActivityOnlyOwnerCanSetMinter() public {
        vm.prank(stranger);
        vm.expectRevert("Ownable: caller is not the owner");
        activityNFT.setMinter(stranger);
    }

    function testActivityGetNonexistentReverts() public {
        vm.expectRevert("ActivityNFT: token does not exist");
        activityNFT.getActivity(999);
    }

    function testActivityIdRequired() public {
        vm.prank(minter);
        vm.expectRevert("ActivityNFT: activity_id required");
        activityNFT.mint(user1, _activityData(""));
    }

    // ─── CertificationNFT ─────────────────────────────────────────────────────

    function testCertificationMint() public {
        uint256 activityTokenId = _mintActivity();

        vm.prank(minter);
        uint256 certTokenId = certificationNFT.mint(user1, _certData(CERT_ID, activityTokenId));

        assertEq(certTokenId, 1);
        assertEq(certificationNFT.ownerOf(certTokenId), user1);
    }

    function testCertificationDataStored() public {
        uint256 activityTokenId = _mintActivity();

        vm.prank(minter);
        uint256 certTokenId = certificationNFT.mint(user1, _certData(CERT_ID, activityTokenId));

        CertificationNFT.CertificationData memory data = certificationNFT.getCertification(certTokenId);

        assertEq(data.certificate_of_compliance_id,   CERT_ID);
        assertEq(data.certificate_of_compliance_uri,  CERT_URL);
        assertEq(data.certificate_of_compliance_hash, CERT_HASH);
        assertEq(data.activity_id,                    ACTIVITY_ID);
        assertEq(data.activity_nft_id,                activityTokenId);
        assertEq(data.activity_uri,                   ACTIVITY_URL);
        assertEq(data.activity_hash,                  ACTIVITY_HASH);
        assertEq(data.activity_name,                  "Reforestation Project Alpha");
        assertEq(data.certification_scheme_name,      "CRCF Scheme");
        assertEq(data.certification_scheme_uri,       "https://api.ogcr.example/schemes/cs-001");
        assertEq(data.certification_scheme_hash,      "sha256:cs001hash");
        assertEq(data.certification_body_name,        "DNV Business Assurance");
        assertEq(data.certification_body_uri,         "https://api.ogcr.example/bodies/cb-001");
        assertEq(data.certification_body_hash,        "sha256:cb001hash");
        assertEq(data.country_id,                     "DK");
        assertEq(data.issue_date,                     "2025-01-01");
        assertEq(data.expiry_date,                    "2028-01-01");
        assertEq(data.audit_report_uri,               "https://api.ogcr.example/audit-reports/ar-001");
        assertEq(data.audit_report_hash,              "sha256:ar001hash");
        assertEq(data.carbon_removals_under_baseline, "6.5");
        assertEq(data.soil_emissions_under_baseline,  "1.25");
        assertEq(data.permanent_net_carbon_removal_benefit, "120.5");
        assertEq(data.carbon_farming_temporary_net_carbon_removal_benefit, "");
        assertEq(data.unit_types,                     "Permanent Removal");
        assertEq(data.certification_status,           "certified");
    }

    function testCertificationTokenURIOmitsAbsentBenefits() public {
        uint256 activityTokenId = _mintActivity();

        vm.prank(minter);
        uint256 certTokenId = certificationNFT.mint(user1, _certData(CERT_ID, activityTokenId));

        string memory json = _metadata(certificationNFT.tokenURI(certTokenId));

        // 19 fixed attributes, then only the three quantities that carry a value,
        // then unit types and status.
        assertEq(vm.parseJsonString(json, ".attributes[19].trait_type"), "Carbon Removals Under Baseline");
        assertEq(vm.parseJsonString(json, ".attributes[21].trait_type"), "Permanent Net Carbon Removal Benefit");
        assertEq(vm.parseJsonString(json, ".attributes[21].value"), "120.5");
        assertEq(vm.parseJsonString(json, ".attributes[22].trait_type"), "Unit Types");
        assertEq(vm.parseJsonString(json, ".attributes[23].trait_type"), "Status");
        assertFalse(vm.keyExistsJson(json, ".attributes[24]"));
    }

    function testCertificationReverseMapping() public {
        uint256 activityTokenId = _mintActivity();

        vm.prank(minter);
        uint256 certTokenId = certificationNFT.mint(user1, _certData(CERT_ID, activityTokenId));

        assertEq(certificationNFT.tokenIdByComplianceId(CERT_ID), certTokenId);
        assertEq(certificationNFT.tokenIdByComplianceId("nonexistent"), 0);
    }

    function testCertificationDuplicatePrevented() public {
        uint256 activityTokenId = _mintActivity();

        vm.startPrank(minter);
        certificationNFT.mint(user1, _certData(CERT_ID, activityTokenId));

        vm.expectRevert("CertificationNFT: already minted");
        certificationNFT.mint(user1, _certData(CERT_ID, activityTokenId));
        vm.stopPrank();
    }

    function testRecertificationMintsSecondTokenForSameActivity() public {
        uint256 activityTokenId = _mintActivity();

        vm.startPrank(minter);
        uint256 first  = certificationNFT.mint(user1, _certData(CERT_ID, activityTokenId));
        uint256 second = certificationNFT.mint(user1, _certData("coc-uuid-recert", activityTokenId));
        vm.stopPrank();

        assertTrue(first != second);
        assertEq(certificationNFT.getCertification(first).activity_nft_id,  activityTokenId);
        assertEq(certificationNFT.getCertification(second).activity_nft_id, activityTokenId);
    }

    function testCertificationActivityNftIdRequired() public {
        vm.prank(minter);
        vm.expectRevert("CertificationNFT: activity_nft_id required");
        certificationNFT.mint(user1, _certData(CERT_ID, 0));
    }

    function testCertificationOnlyMinterCanMint() public {
        vm.prank(stranger);
        vm.expectRevert("CertificationNFT: caller is not minter");
        certificationNFT.mint(user1, _certData(CERT_ID, 1));
    }

    function testCertificationComplianceIdRequired() public {
        vm.prank(minter);
        vm.expectRevert("CertificationNFT: compliance id required");
        certificationNFT.mint(user1, _certData("", 1));
    }

    function testCertificationGetNonexistentReverts() public {
        vm.expectRevert("CertificationNFT: token does not exist");
        certificationNFT.getCertification(999);
    }

    // ─── CarbonCreditBatchNFT ─────────────────────────────────────────────────

    function testBatchMint() public {
        uint256 activityTokenId = _mintActivity();
        (uint256 tokenId, address tba) = _mintBatch(activityTokenId);

        assertEq(tokenId, 1);
        assertEq(batchNFT.ownerOf(tokenId), user1);
        assertTrue(tba != address(0));
        assertTrue(tba.code.length > 0);
    }

    function testBatchDataStored() public {
        uint256 activityTokenId = _mintActivity();
        (uint256 tokenId, ) = _mintBatch(activityTokenId);

        CarbonCreditBatchNFT.BatchData memory data = batchNFT.getBatch(tokenId);

        assertEq(data.carbon_credit_batch_id,         BATCH_ID);
        assertEq(data.batch_name,                     "Permanent Removals Carbon Credit Batch");
        assertEq(data.activity_id,                    ACTIVITY_ID);
        assertEq(data.activity_nft_id,                activityTokenId);
        assertEq(data.activity_name,                  "Reforestation Project Alpha");
        assertEq(data.activity_url,                   ACTIVITY_URL);
        assertEq(data.activity_hash,                  ACTIVITY_HASH);
        assertEq(data.country_id,                     "DK");
        assertEq(data.operator_url,                   "https://api.ogcr.example/operators/op-001");
        assertEq(data.operator_hash,                  "sha256:op001hash");
        assertEq(data.certificate_of_compliance_uri,  CERT_URL);
        assertEq(data.certificate_of_compliance_hash, CERT_HASH);
        assertEq(data.unit_type,                      UNIT_TYPE);
        assertEq(data.monitoring_period_start_date,   "2024-01-01");
        assertEq(data.monitoring_period_end_date,     "2024-12-31");
        assertEq(data.amount,                         500e18);
        assertEq(data.status_code,                    "issued");
        assertEq(data.issue_date,                     "2025-01-15");
        assertEq(data.expiry_date,                    "2028-01-01");
        assertEq(data.certification_scheme_url,       "https://api.ogcr.example/schemes/cs-001");
        assertEq(data.certification_scheme_hash,      "sha256:cs001hash");
        assertEq(data.certification_body_url,         "https://api.ogcr.example/bodies/cb-001");
        assertEq(data.certification_body_hash,        "sha256:cb001hash");
    }

    function testBatchTokenURI() public {
        uint256 activityTokenId = _mintActivity();
        (uint256 tokenId, address tba) = _mintBatch(activityTokenId);

        string memory json = _metadata(batchNFT.tokenURI(tokenId));

        assertEq(vm.parseJsonString(json, ".name"), "Permanent Removals Carbon Credit Batch");
        assertEq(vm.parseJsonString(json, ".attributes[0].value"), BATCH_ID);
        assertEq(vm.parseJsonString(json, ".attributes[14].trait_type"), "Amount");
        assertEq(vm.parseJsonString(json, ".attributes[14].value"), "500000000000000000000");
        assertEq(vm.parseJsonString(json, ".attributes[22].trait_type"), "Token Bound Account");
        assertEq(vm.parseJsonAddress(json, ".attributes[22].value"), tba);
    }

    function testBatchTBAMatchesRegistry() public {
        uint256 activityTokenId = _mintActivity();
        (uint256 tokenId, address tba) = _mintBatch(activityTokenId);

        assertEq(batchNFT.getTBA(tokenId), tba);

        address expected = registry.account(
            address(accountImpl),
            block.chainid,
            address(batchNFT),
            tokenId,
            0
        );
        assertEq(tba, expected);
    }

    function testBatchTBAOwnedByBatchHolder() public {
        uint256 activityTokenId = _mintActivity();
        (uint256 tokenId, address tba) = _mintBatch(activityTokenId);

        assertEq(CarbonERC6551Account(payable(tba)).owner(), user1);

        (, address tokenContract, uint256 boundTokenId) =
            CarbonERC6551Account(payable(tba)).token();

        assertEq(tokenContract, address(batchNFT));
        assertEq(boundTokenId,  tokenId);
    }

    function testBatchIdRequired() public {
        vm.prank(minter);
        vm.expectRevert("CarbonCreditBatchNFT: carbon_credit_batch_id required");
        batchNFT.mint(user1, _batchData("", 1));
    }

    function testBatchActivityNftIdRequired() public {
        vm.prank(minter);
        vm.expectRevert("CarbonCreditBatchNFT: activity_nft_id required");
        batchNFT.mint(user1, _batchData(BATCH_ID, 0));
    }

    function testBatchAmountRequired() public {
        CarbonCreditBatchNFT.BatchData memory d = _batchData(BATCH_ID, 1);
        d.amount = 0;
        vm.prank(minter);
        vm.expectRevert("CarbonCreditBatchNFT: amount required");
        batchNFT.mint(user1, d);
    }

    function testBatchActivityUrlRequired() public {
        CarbonCreditBatchNFT.BatchData memory d = _batchData(BATCH_ID, 1);
        d.activity_url = "";
        vm.prank(minter);
        vm.expectRevert("CarbonCreditBatchNFT: activity_url required");
        batchNFT.mint(user1, d);
    }

    function testBatchCertificateUriRequired() public {
        CarbonCreditBatchNFT.BatchData memory d = _batchData(BATCH_ID, 1);
        d.certificate_of_compliance_uri = "";
        vm.prank(minter);
        vm.expectRevert("CarbonCreditBatchNFT: certificate_of_compliance_uri required");
        batchNFT.mint(user1, d);
    }

    function testBatchOnlyMinterCanMint() public {
        vm.prank(stranger);
        vm.expectRevert("CarbonCreditBatchNFT: caller is not minter");
        batchNFT.mint(user1, _batchData(BATCH_ID, 1));
    }

    function testBatchUnitTypeRequired() public {
        CarbonCreditBatchNFT.BatchData memory d = _batchData(BATCH_ID, 1);
        d.unit_type = "";
        vm.prank(minter);
        vm.expectRevert("CarbonCreditBatchNFT: unit_type required");
        batchNFT.mint(user1, d);
    }

    function testBatchGetNonexistentReverts() public {
        vm.expectRevert("CarbonCreditBatchNFT: token does not exist");
        batchNFT.getBatch(999);
    }

    function testBatchDuplicatePrevented() public {
        uint256 activityTokenId = _mintActivity();
        _mintBatch(activityTokenId);
        vm.prank(minter);
        vm.expectRevert("CarbonCreditBatchNFT: batch already minted");
        batchNFT.mint(user1, _batchData(BATCH_ID, activityTokenId));
    }

    function testBatchIdLookup() public {
        uint256 activityTokenId = _mintActivity();
        (uint256 tokenId,) = _mintBatch(activityTokenId);
        assertEq(batchNFT.tokenIdByBatchId(BATCH_ID), tokenId);
        assertEq(batchNFT.tokenIdByBatchId("nonexistent"), 0);
    }

    // A second monitoring period issues a new batch of the same unit type for
    // the same activity.
    function testSameUnitTypeNewMonitoringPeriod() public {
        uint256 activityTokenId = _mintActivity();
        (uint256 first,) = _mintBatch(activityTokenId);

        CarbonCreditBatchNFT.BatchData memory d = _batchData("ccb-uuid-002", activityTokenId);
        d.monitoring_period_start_date = "2025-01-01";
        d.monitoring_period_end_date   = "2025-12-31";
        vm.prank(minter);
        (uint256 second,) = batchNFT.mint(user1, d);

        assertTrue(first != second);
        assertEq(batchNFT.getBatch(second).unit_type, UNIT_TYPE);
    }

    // ─── CarbonCredit ─────────────────────────────────────────────────────────

    function testCarbonCreditMintIntoTBA() public {
        uint256 activityTokenId = _mintActivity();
        (, address tba) = _mintBatch(activityTokenId);

        vm.prank(minter);
        carbonCredit.mint(tba, 500e18);

        assertEq(carbonCredit.balanceOf(tba), 500e18);
        assertEq(carbonCredit.totalSupply(),  500e18);
    }

    function testCarbonCreditBurn() public {
        uint256 activityTokenId = _mintActivity();
        (, address tba) = _mintBatch(activityTokenId);

        vm.prank(minter);
        carbonCredit.mint(tba, 500e18);

        // Token holder (TBA) must approve the minter before it can burn
        vm.prank(tba);
        carbonCredit.approve(minter, 200e18);

        vm.prank(minter);
        carbonCredit.burn(tba, 200e18);

        assertEq(carbonCredit.balanceOf(tba), 300e18);
    }

    // mintedTo is what the tokenizer checks before funding a batch, so it must
    // not drop when credits leave the account.
    function testCarbonCreditMintedToSurvivesTransferAndBurn() public {
        vm.startPrank(minter);
        carbonCredit.mint(user1, 300e18);
        carbonCredit.mint(user1, 200e18);
        vm.stopPrank();

        vm.startPrank(user1);
        carbonCredit.transfer(stranger, 100e18);
        carbonCredit.approve(minter, 50e18);
        vm.stopPrank();

        vm.prank(minter);
        carbonCredit.burn(user1, 50e18);

        assertEq(carbonCredit.balanceOf(user1), 350e18);
        assertEq(carbonCredit.mintedTo(user1),  500e18);
        assertEq(carbonCredit.mintedTo(stranger), 0);
    }

    function testCarbonCreditBurnRequiresAllowance() public {
        vm.prank(minter);
        carbonCredit.mint(user1, 100e18);

        // Minter cannot burn without user1's approval
        vm.prank(minter);
        vm.expectRevert("ERC20: insufficient allowance");
        carbonCredit.burn(user1, 100e18);
    }

    function testCarbonCreditBurnWithAllowance() public {
        vm.prank(minter);
        carbonCredit.mint(user1, 100e18);

        vm.prank(user1);
        carbonCredit.approve(minter, 100e18);

        vm.prank(minter);
        carbonCredit.burn(user1, 100e18);

        assertEq(carbonCredit.balanceOf(user1), 0);
    }

    function testCarbonCreditOnlyMinterCanMint() public {
        vm.prank(stranger);
        vm.expectRevert("CarbonCredit: caller is not minter");
        carbonCredit.mint(user1, 100e18);
    }

    function testCarbonCreditOnlyMinterCanBurn() public {
        vm.prank(minter);
        carbonCredit.mint(user1, 100e18);

        vm.prank(stranger);
        vm.expectRevert("CarbonCredit: caller is not minter");
        carbonCredit.burn(user1, 100e18);
    }

    function testCarbonCreditDecimals() public view {
        assertEq(carbonCredit.decimals(), 18);
    }

    // ─── Full tokenizer flow ──────────────────────────────────────────────────

    function testFullTokenizerFlow() public {
        uint256 activityTokenId = _mintActivity();
        assertEq(activityNFT.tokenIdByActivityId(ACTIVITY_ID), activityTokenId);

        vm.prank(minter);
        uint256 certTokenId = certificationNFT.mint(user1, _certData(CERT_ID, activityTokenId));

        CarbonCreditBatchNFT.BatchData memory d = _batchData(BATCH_ID, activityTokenId);
        vm.prank(minter);
        (uint256 batchTokenId, address tba) = batchNFT.mint(user1, d);

        vm.prank(minter);
        carbonCredit.mint(tba, d.amount);

        assertEq(activityNFT.ownerOf(activityTokenId),   user1);
        assertEq(certificationNFT.ownerOf(certTokenId),  user1);
        assertEq(batchNFT.ownerOf(batchTokenId),         user1);
        assertEq(carbonCredit.balanceOf(tba),            d.amount);
        assertEq(carbonCredit.mintedTo(tba),             batchNFT.getBatch(batchTokenId).amount);
        assertEq(CarbonERC6551Account(payable(tba)).owner(), user1);
    }

    function testMultipleBatchesPerActivity() public {
        uint256 activityTokenId = _mintActivity();

        CarbonCreditBatchNFT.BatchData memory d1 = _batchData("ccb-perm", activityTokenId);
        d1.amount = 300e18;
        CarbonCreditBatchNFT.BatchData memory d2 = _batchData("ccb-soil", activityTokenId);
        d2.unit_type  = "Soil Emission Reduction";
        d2.batch_name = "Soil Emissions Reductions Carbon Credit Batch";
        d2.amount     = 700e18;

        vm.startPrank(minter);
        (uint256 batch1, address tba1) = batchNFT.mint(user1, d1);
        (uint256 batch2, address tba2) = batchNFT.mint(user1, d2);

        carbonCredit.mint(tba1, d1.amount);
        carbonCredit.mint(tba2, d2.amount);
        vm.stopPrank();

        assertEq(batchNFT.getBatch(batch1).unit_type, UNIT_TYPE);
        assertEq(batchNFT.getBatch(batch2).unit_type, "Soil Emission Reduction");
        assertEq(carbonCredit.balanceOf(tba1), 300e18);
        assertEq(carbonCredit.balanceOf(tba2), 700e18);
        assertEq(carbonCredit.totalSupply(),   1000e18);
        assertTrue(tba1 != tba2);
    }
}
