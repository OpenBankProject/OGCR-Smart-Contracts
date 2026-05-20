// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/CarbonProjectNFT.sol";
import "../src/CarbonBatchNFT.sol";
import "../src/CarbonERC6551Registry.sol";
import "../src/CarbonERC6551Account.sol";
import "../src/CarbonBatchController.sol";

contract CarbonERC6551SystemTest is Test {
    CarbonProjectNFT public carbonProjectNFT;
    CarbonBatchNFT public carbonBatchNFT;
    CarbonERC6551Registry public erc6551Registry;
    CarbonERC6551Account public accountImplementation;
    CarbonBatchController public batchController;

    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);

    uint256[] public projectIds;

    function setUp() public {
        vm.startPrank(owner);

        carbonProjectNFT = new CarbonProjectNFT();
        erc6551Registry = new CarbonERC6551Registry();
        accountImplementation = new CarbonERC6551Account();

        carbonBatchNFT = new CarbonBatchNFT(
            address(erc6551Registry),
            address(accountImplementation)
        );

        batchController = new CarbonBatchController(
            address(carbonProjectNFT),
            address(carbonBatchNFT),
            address(erc6551Registry),
            address(accountImplementation)
        );

        carbonBatchNFT.transferOwnership(address(batchController));

        vm.stopPrank();
    }

    function testSystemDeployment() public view {
        assertTrue(address(carbonProjectNFT) != address(0));
        assertTrue(address(carbonBatchNFT) != address(0));
        assertTrue(address(erc6551Registry) != address(0));
        assertTrue(address(accountImplementation) != address(0));
        assertTrue(address(batchController) != address(0));
        assertEq(carbonBatchNFT.owner(), address(batchController));
    }

    function testCreateCarbonProjects() public {
        vm.startPrank(owner);

        for (uint256 i = 0; i < 5; i++) {
            string memory parcelId = string(abi.encodePacked("parcel-", vm.toString(i + 1)));
            uint256 projectId = carbonProjectNFT.mintCarbonProject(
                user1,
                parcelId,
                (i + 1) * 1000,
                "Reforestation",
                "VCS",
                "2024",
                string(abi.encodePacked("ogcr://activity/act-1/parcel/", parcelId))
            );
            projectIds.push(projectId);
            assertEq(carbonProjectNFT.ownerOf(projectId), user1);
        }

        vm.stopPrank();
    }

    function testDeduplicationByParcelId() public {
        vm.startPrank(owner);

        carbonProjectNFT.mintCarbonProject(
            user1, "parcel-abc", 1000, "Reforestation", "VCS", "2024", "ogcr://parcel-abc"
        );

        uint256[] memory found = carbonProjectNFT.getProjectsByParcelId("parcel-abc");
        assertEq(found.length, 1);

        uint256[] memory notFound = carbonProjectNFT.getProjectsByParcelId("parcel-xyz");
        assertEq(notFound.length, 0);

        vm.stopPrank();
    }

    function testGetProjectData() public {
        vm.startPrank(owner);

        uint256 projectId = carbonProjectNFT.mintCarbonProject(
            user1, "parcel-42", 5000, "Soil Carbon", "Gold Standard", "2025", "ogcr://parcel-42"
        );

        (
            string memory parcelId,
            uint256 carbonAmount,
            string memory projectType,
            string memory methodology,
            string memory vintage,
            uint256 mintedAt
        ) = carbonProjectNFT.getProjectData(projectId);

        assertEq(parcelId, "parcel-42");
        assertEq(carbonAmount, 5000);
        assertEq(projectType, "Soil Carbon");
        assertEq(methodology, "Gold Standard");
        assertEq(vintage, "2025");
        assertTrue(mintedAt > 0);

        vm.stopPrank();
    }

    function testCreateBatchWithProjects() public {
        testCreateCarbonProjects();

        vm.startPrank(user1);

        for (uint256 i = 0; i < projectIds.length; i++) {
            carbonProjectNFT.approve(address(batchController), projectIds[i]);
        }

        uint256 batchId = batchController.createBatchWithProjects(
            "Reforestation",
            "2024",
            "https://batch-metadata.com/1",
            projectIds,
            true
        );

        assertEq(carbonBatchNFT.ownerOf(batchId), user1);

        (
            string memory batchType,
            string memory vintage,
            uint256 totalCarbonAmount,
            uint256 projectCount,
            address tokenBoundAccount,
            ,
            bool finalized,
            ,

        ) = carbonBatchNFT.getBatchData(batchId);

        assertEq(batchType, "Reforestation");
        assertEq(vintage, "2024");
        assertEq(totalCarbonAmount, 15000);
        assertEq(projectCount, 5);
        assertFalse(finalized);
        assertTrue(tokenBoundAccount != address(0));
        assertTrue(tokenBoundAccount.code.length > 0);

        for (uint256 i = 0; i < projectIds.length; i++) {
            assertEq(carbonProjectNFT.ownerOf(projectIds[i]), tokenBoundAccount);
        }

        vm.stopPrank();
    }

    function testTokenBoundAccountOperations() public {
        testCreateBatchWithProjects();

        vm.startPrank(user1);

        uint256 batchId = 1;
        address tokenBoundAccount = carbonBatchNFT.getTokenBoundAccount(batchId);

        (uint256 chainId, address tokenContract, uint256 tokenId) =
            CarbonERC6551Account(payable(tokenBoundAccount)).token();

        assertEq(chainId, block.chainid);
        assertEq(tokenContract, address(carbonBatchNFT));
        assertEq(tokenId, batchId);
        assertEq(CarbonERC6551Account(payable(tokenBoundAccount)).owner(), user1);

        vm.stopPrank();
    }

    function testBatchFinalization() public {
        testCreateBatchWithProjects();

        vm.startPrank(user1);

        uint256 batchId = 1;
        carbonBatchNFT.finalizeBatch(batchId);

        (, , , , , , bool finalized, , ) = carbonBatchNFT.getBatchData(batchId);
        assertTrue(finalized);

        vm.expectRevert("Batch is finalized");
        carbonBatchNFT.addProjectToBatch(batchId, address(carbonProjectNFT), 999);

        vm.stopPrank();
    }

    function testAccessControl() public {
        testCreateCarbonProjects();

        vm.startPrank(user2);
        vm.expectRevert("Not owner of project");
        batchController.createBatchWithProjects(
            "Reforestation", "2024", "https://batch-metadata.com/1", projectIds, true
        );
        vm.stopPrank();

        vm.startPrank(user1);
        for (uint256 i = 0; i < projectIds.length; i++) {
            carbonProjectNFT.approve(address(batchController), projectIds[i]);
        }
        uint256 batchId = batchController.createBatchWithProjects(
            "Reforestation", "2024", "https://batch-metadata.com/1", projectIds, true
        );
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert("CarbonAccount: call failed");
        carbonBatchNFT.executeFromAccount(batchId, address(carbonProjectNFT), 0, "");
        vm.stopPrank();
    }

    function testMinimumProjectsPerBatch() public {
        testCreateCarbonProjects();

        vm.startPrank(user1);

        uint256[] memory tooFewProjects = new uint256[](1);
        tooFewProjects[0] = projectIds[0];

        vm.expectRevert("Not enough projects for batch type");
        batchController.createBatchWithProjects(
            "Reforestation", "2024", "https://batch-metadata.com/1", tooFewProjects, true
        );

        vm.stopPrank();
    }

    function testBatchCreationFee() public {
        testCreateCarbonProjects();

        vm.prank(owner);
        batchController.setBatchCreationFee(0.1 ether);

        vm.startPrank(user1);
        vm.deal(user1, 1 ether);

        vm.expectRevert("Insufficient batch creation fee");
        batchController.createBatchWithProjects(
            "Reforestation", "2024", "https://batch-metadata.com/1", projectIds, true
        );

        for (uint256 i = 0; i < projectIds.length; i++) {
            carbonProjectNFT.approve(address(batchController), projectIds[i]);
        }

        uint256 batchId = batchController.createBatchWithProjects{value: 0.1 ether}(
            "Reforestation", "2024", "https://batch-metadata.com/1", projectIds, true
        );

        assertEq(carbonBatchNFT.ownerOf(batchId), user1);
        vm.stopPrank();
    }

    function testERC6551AccountReceiveETH() public {
        testCreateBatchWithProjects();

        uint256 batchId = 1;
        address tokenBoundAccount = carbonBatchNFT.getTokenBoundAccount(batchId);

        vm.deal(address(this), 1 ether);
        (bool success, ) = tokenBoundAccount.call{value: 0.5 ether}("");
        assertTrue(success);
        assertEq(tokenBoundAccount.balance, 0.5 ether);
    }

    function testSupportsInterface() public view {
        assertTrue(accountImplementation.supportsInterface(type(IERC165).interfaceId));
        assertTrue(accountImplementation.supportsInterface(type(IERC721Receiver).interfaceId));
        assertTrue(accountImplementation.supportsInterface(type(IERC1155Receiver).interfaceId));
    }

    receive() external payable {}
}
