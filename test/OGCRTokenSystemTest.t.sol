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

    // ─── ActivityNFT ──────────────────────────────────────────────────────────

    function testActivityMint() public {
        vm.prank(minter);
        uint256 tokenId = activityNFT.mint(
            user1, ACTIVITY_ID, OPERATOR_ID,
            "Reforestation Project Alpha", "reforestation",
            "2024-01-01", "2026-12-31", ACTIVITY_URL, ACTIVITY_HASH
        );

        assertEq(tokenId, 1);
        assertEq(activityNFT.ownerOf(tokenId), user1);
    }

    function testActivityDataStored() public {
        vm.prank(minter);
        uint256 tokenId = activityNFT.mint(
            user1, ACTIVITY_ID, OPERATOR_ID,
            "Reforestation Project Alpha", "reforestation",
            "2024-01-01", "2026-12-31", ACTIVITY_URL, ACTIVITY_HASH
        );

        ActivityNFT.ActivityData memory data = activityNFT.getActivity(tokenId);

        assertEq(data.activity_id,   ACTIVITY_ID);
        assertEq(data.operator_id,   OPERATOR_ID);
        assertEq(data.name,          "Reforestation Project Alpha");
        assertEq(data.activity_type, "reforestation");
        assertEq(data.start_date,    "2024-01-01");
        assertEq(data.end_date,      "2026-12-31");
        assertEq(data.activity_url,  ACTIVITY_URL);
        assertEq(data.activity_hash, ACTIVITY_HASH);
    }

    function testActivityReverseMapping() public {
        vm.prank(minter);
        uint256 tokenId = activityNFT.mint(
            user1, ACTIVITY_ID, OPERATOR_ID,
            "Project", "reforestation",
            "2024-01-01", "2026-12-31", ACTIVITY_URL, ACTIVITY_HASH
        );

        assertEq(activityNFT.tokenIdByActivityId(ACTIVITY_ID), tokenId);
        assertEq(activityNFT.tokenIdByActivityId("nonexistent-id"), 0);
    }

    function testActivityDuplicatePrevented() public {
        vm.startPrank(minter);
        activityNFT.mint(
            user1, ACTIVITY_ID, OPERATOR_ID,
            "Project", "reforestation",
            "2024-01-01", "2026-12-31", ACTIVITY_URL, ACTIVITY_HASH
        );

        vm.expectRevert("ActivityNFT: already minted");
        activityNFT.mint(
            user1, ACTIVITY_ID, OPERATOR_ID,
            "Project", "reforestation",
            "2024-01-01", "2026-12-31", ACTIVITY_URL, ACTIVITY_HASH
        );
        vm.stopPrank();
    }

    function testActivityOnlyMinterCanMint() public {
        vm.prank(stranger);
        vm.expectRevert("ActivityNFT: caller is not minter");
        activityNFT.mint(
            user1, ACTIVITY_ID, OPERATOR_ID,
            "Project", "reforestation",
            "2024-01-01", "2026-12-31", ACTIVITY_URL, ACTIVITY_HASH
        );
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
        activityNFT.mint(
            user1, "", OPERATOR_ID,
            "Project", "reforestation",
            "2024-01-01", "2026-12-31", ACTIVITY_URL, ACTIVITY_HASH
        );
    }

    // ─── CertificationNFT ─────────────────────────────────────────────────────

    function _mintActivity() internal returns (uint256) {
        vm.prank(minter);
        return activityNFT.mint(
            user1, ACTIVITY_ID, OPERATOR_ID,
            "Project", "reforestation",
            "2024-01-01", "2026-12-31", ACTIVITY_URL, ACTIVITY_HASH
        );
    }

    function testCertificationMint() public {
        uint256 activityTokenId = _mintActivity();

        vm.prank(minter);
        uint256 certTokenId = certificationNFT.mint(
            user1, activityTokenId,
            "gs-001", "cb-001", CERT_ID,
            "2025-01-01", "2028-01-01", "active",
            ACTIVITY_URL, ACTIVITY_HASH,
            CERT_URL, CERT_HASH
        );

        assertEq(certTokenId, 1);
        assertEq(certificationNFT.ownerOf(certTokenId), user1);
    }

    function testCertificationDataStored() public {
        uint256 activityTokenId = _mintActivity();

        vm.prank(minter);
        uint256 certTokenId = certificationNFT.mint(
            user1, activityTokenId,
            "gs-001", "cb-001", CERT_ID,
            "2025-01-01", "2028-01-01", "active",
            ACTIVITY_URL, ACTIVITY_HASH,
            CERT_URL, CERT_HASH
        );

        CertificationNFT.CertificationData memory data = certificationNFT.getCertification(certTokenId);

        assertEq(data.activity_nft_id,               activityTokenId);
        assertEq(data.certification_scheme_id,        "gs-001");
        assertEq(data.certification_body_id,          "cb-001");
        assertEq(data.certification_of_compliance_id, CERT_ID);
        assertEq(data.issue_date,                     "2025-01-01");
        assertEq(data.expiry_date,                    "2028-01-01");
        assertEq(data.certification_status,           "active");
        assertEq(data.activity_url,                   ACTIVITY_URL);
        assertEq(data.activity_hash,                  ACTIVITY_HASH);
        assertEq(data.certification_url,              CERT_URL);
        assertEq(data.certification_hash,             CERT_HASH);
    }

    function testCertificationReverseMapping() public {
        uint256 activityTokenId = _mintActivity();

        vm.prank(minter);
        uint256 certTokenId = certificationNFT.mint(
            user1, activityTokenId,
            "gs-001", "cb-001", CERT_ID,
            "2025-01-01", "2028-01-01", "active",
            ACTIVITY_URL, ACTIVITY_HASH,
            CERT_URL, CERT_HASH
        );

        assertEq(certificationNFT.tokenIdByComplianceId(CERT_ID), certTokenId);
        assertEq(certificationNFT.tokenIdByComplianceId("nonexistent"), 0);
    }

    function testCertificationDuplicatePrevented() public {
        uint256 activityTokenId = _mintActivity();

        vm.startPrank(minter);
        certificationNFT.mint(
            user1, activityTokenId,
            "gs-001", "cb-001", CERT_ID,
            "2025-01-01", "2028-01-01", "active",
            ACTIVITY_URL, ACTIVITY_HASH, CERT_URL, CERT_HASH
        );

        vm.expectRevert("CertificationNFT: already minted");
        certificationNFT.mint(
            user1, activityTokenId,
            "gs-001", "cb-001", CERT_ID,
            "2025-01-01", "2028-01-01", "active",
            ACTIVITY_URL, ACTIVITY_HASH, CERT_URL, CERT_HASH
        );
        vm.stopPrank();
    }

    function testCertificationActivityNftIdRequired() public {
        vm.prank(minter);
        vm.expectRevert("CertificationNFT: activity_nft_id required");
        certificationNFT.mint(
            user1, 0,
            "gs-001", "cb-001", CERT_ID,
            "2025-01-01", "2028-01-01", "active",
            ACTIVITY_URL, ACTIVITY_HASH, CERT_URL, CERT_HASH
        );
    }

    function testCertificationOnlyMinterCanMint() public {
        vm.prank(stranger);
        vm.expectRevert("CertificationNFT: caller is not minter");
        certificationNFT.mint(
            user1, 1,
            "gs-001", "cb-001", CERT_ID,
            "2025-01-01", "2028-01-01", "active",
            ACTIVITY_URL, ACTIVITY_HASH, CERT_URL, CERT_HASH
        );
    }

    function testCertificationComplianceIdRequired() public {
        vm.prank(minter);
        vm.expectRevert("CertificationNFT: compliance id required");
        certificationNFT.mint(
            user1, 1,
            "gs-001", "cb-001", "",
            "2025-01-01", "2028-01-01", "active",
            ACTIVITY_URL, ACTIVITY_HASH, CERT_URL, CERT_HASH
        );
    }

    function testCertificationGetNonexistentReverts() public {
        vm.expectRevert("CertificationNFT: token does not exist");
        certificationNFT.getCertification(999);
    }

    // ─── CarbonCreditBatchNFT ─────────────────────────────────────────────────

    function _mintBatch(uint256 activityTokenId) internal returns (uint256 tokenId, address tba) {
        vm.prank(minter);
        return batchNFT.mint(
            user1,
            activityTokenId,
            "permanent_carbon_tonnes",
            ACTIVITY_URL,  ACTIVITY_HASH,
            "https://api.ogcr.example/operators/op-001", "sha256:op001hash",
            CERT_URL,      CERT_HASH,
            "https://api.ogcr.example/schemes/gs",       "sha256:gs-hash",
            "https://api.ogcr.example/bodies/cb-001",    "sha256:cb001hash"
        );
    }

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

        assertEq(data.activity_nft_id, activityTokenId);
        assertEq(data.credit_type,     "permanent_carbon_tonnes");
        assertEq(data.activity_url,    ACTIVITY_URL);
        assertEq(data.activity_hash,   ACTIVITY_HASH);
        assertEq(data.certification_url,  CERT_URL);
        assertEq(data.certification_hash, CERT_HASH);
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

    function testBatchActivityNftIdRequired() public {
        vm.prank(minter);
        vm.expectRevert("CarbonCreditBatchNFT: activity_nft_id required");
        batchNFT.mint(
            user1, 0, "permanent_carbon_tonnes",
            ACTIVITY_URL, ACTIVITY_HASH,
            "", "", CERT_URL, CERT_HASH, "", "", "", ""
        );
    }

    function testBatchActivityUrlRequired() public {
        vm.prank(minter);
        vm.expectRevert("CarbonCreditBatchNFT: activity_url required");
        batchNFT.mint(
            user1, 1, "permanent_carbon_tonnes",
            "", ACTIVITY_HASH,
            "", "", CERT_URL, CERT_HASH, "", "", "", ""
        );
    }

    function testBatchCertificationUrlRequired() public {
        vm.prank(minter);
        vm.expectRevert("CarbonCreditBatchNFT: certification_url required");
        batchNFT.mint(
            user1, 1, "permanent_carbon_tonnes",
            ACTIVITY_URL, ACTIVITY_HASH,
            "", "", "", CERT_HASH, "", "", "", ""
        );
    }

    function testBatchOnlyMinterCanMint() public {
        vm.prank(stranger);
        vm.expectRevert("CarbonCreditBatchNFT: caller is not minter");
        batchNFT.mint(
            user1, 1, "permanent_carbon_tonnes",
            ACTIVITY_URL, ACTIVITY_HASH,
            "", "", "", "", "", "", "", ""
        );
    }

    function testBatchCreditTypeRequired() public {
        vm.prank(minter);
        vm.expectRevert("CarbonCreditBatchNFT: credit_type required");
        batchNFT.mint(
            user1, 1, "",
            ACTIVITY_URL, ACTIVITY_HASH,
            "", "", CERT_URL, CERT_HASH, "", "", "", ""
        );
    }

    function testBatchGetNonexistentReverts() public {
        vm.expectRevert("CarbonCreditBatchNFT: token does not exist");
        batchNFT.getBatch(999);
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
        vm.prank(minter);
        uint256 activityTokenId = activityNFT.mint(
            user1, ACTIVITY_ID, OPERATOR_ID,
            "Reforestation Project Alpha", "reforestation",
            "2024-01-01", "2026-12-31", ACTIVITY_URL, ACTIVITY_HASH
        );

        assertEq(activityNFT.tokenIdByActivityId(ACTIVITY_ID), activityTokenId);

        vm.prank(minter);
        (uint256 batchTokenId, address tba) = batchNFT.mint(
            user1,
            activityTokenId,
            "permanent_carbon_tonnes",
            ACTIVITY_URL,  ACTIVITY_HASH,
            "https://api.ogcr.example/operators/op-001", "sha256:op001hash",
            CERT_URL,      CERT_HASH,
            "https://api.ogcr.example/schemes/gs",       "sha256:gs-hash",
            "https://api.ogcr.example/bodies/cb-001",    "sha256:cb001hash"
        );

        vm.prank(minter);
        carbonCredit.mint(tba, 1000e18);

        assertEq(activityNFT.ownerOf(activityTokenId), user1);
        assertEq(batchNFT.ownerOf(batchTokenId),       user1);
        assertEq(carbonCredit.balanceOf(tba),          1000e18);
        assertEq(CarbonERC6551Account(payable(tba)).owner(), user1);

        CarbonCreditBatchNFT.BatchData memory batch = batchNFT.getBatch(batchTokenId);
        assertEq(batch.activity_nft_id, activityTokenId);
    }

    function testMultipleBatchesPerActivity() public {
        vm.prank(minter);
        uint256 activityTokenId = activityNFT.mint(
            user1, ACTIVITY_ID, OPERATOR_ID,
            "Project", "reforestation",
            "2024-01-01", "2026-12-31", ACTIVITY_URL, ACTIVITY_HASH
        );

        vm.startPrank(minter);
        (uint256 batch1, address tba1) = batchNFT.mint(
            user1, activityTokenId, "permanent_carbon_tonnes",
            ACTIVITY_URL, ACTIVITY_HASH,
            "", "", CERT_URL, CERT_HASH, "", "", "", ""
        );
        (uint256 batch2, address tba2) = batchNFT.mint(
            user1, activityTokenId, "carbon_removal_tonnes",
            ACTIVITY_URL, ACTIVITY_HASH,
            "", "", CERT_URL, CERT_HASH, "", "", "", ""
        );

        carbonCredit.mint(tba1, 300e18);
        carbonCredit.mint(tba2, 700e18);
        vm.stopPrank();

        assertEq(batchNFT.getBatch(batch1).credit_type, "permanent_carbon_tonnes");
        assertEq(batchNFT.getBatch(batch2).credit_type, "carbon_removal_tonnes");
        assertEq(carbonCredit.balanceOf(tba1), 300e18);
        assertEq(carbonCredit.balanceOf(tba2), 700e18);
        assertEq(carbonCredit.totalSupply(),   1000e18);
        assertTrue(tba1 != tba2);
    }
}
