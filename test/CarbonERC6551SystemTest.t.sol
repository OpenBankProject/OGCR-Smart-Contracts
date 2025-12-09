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
    
    address constant MOCK_ERC20 = address(0x4);
    address constant MOCK_PARCEL_NFT = address(0x5);
    
    uint256[] public projectIds;

    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy contracts
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
        
        // Setup permissions
        carbonBatchNFT.transferOwnership(address(batchController));
        carbonProjectNFT.setAuthorizedRedeemer(address(batchController), true);
        
        vm.stopPrank();
    }

    function testSystemDeployment() public view {
        // Verify all contracts are deployed
        assertTrue(address(carbonProjectNFT) != address(0));
        assertTrue(address(carbonBatchNFT) != address(0));
        assertTrue(address(erc6551Registry) != address(0));
        assertTrue(address(accountImplementation) != address(0));
        assertTrue(address(batchController) != address(0));
        
        // Verify ownership setup
        assertEq(carbonBatchNFT.owner(), address(batchController));
        assertTrue(carbonProjectNFT.authorizedRedeemers(address(batchController)));
    }

    function testCreateCarbonProjects() public {
        vm.startPrank(owner);
        
        // Create multiple projects
        for (uint256 i = 0; i < 5; i++) {
            uint256 projectId = carbonProjectNFT.mintCarbonProject(
                user1,
                MOCK_PARCEL_NFT,
                i + 1,
                MOCK_ERC20,
                (i + 1) * 1000, // Varying carbon amounts
                user1,
                "Reforestation",
                "VCS",
                "2024",
                string(abi.encodePacked("https://metadata.com/", vm.toString(i + 1)))
            );
            
            projectIds.push(projectId);
            
            // Verify project creation
            assertEq(carbonProjectNFT.ownerOf(projectId), user1);
            assertTrue(carbonProjectNFT.isProjectRedeemable(projectId));
        }
        
        vm.stopPrank();
    }

    function testCreateBatchWithProjects() public {
        // First create projects
        testCreateCarbonProjects();
        
        vm.startPrank(user1);
        
        // Approve the batch controller to transfer projects on our behalf
        for (uint256 i = 0; i < projectIds.length; i++) {
            carbonProjectNFT.approve(address(batchController), projectIds[i]);
        }
        
        // Create batch with projects
        uint256 batchId = batchController.createBatchWithProjects(
            "Reforestation",
            "2024",
            "https://batch-metadata.com/1",
            projectIds,
            true // Transfer to token-bound account
        );
        
        // Verify batch creation
        assertEq(carbonBatchNFT.ownerOf(batchId), user1);
        
        // Get batch info
        (
            string memory batchType,
            string memory vintage,
            uint256 totalCarbonAmount,
            uint256 projectCount,
            address tokenBoundAccount,
            ,
            bool finalized,
            address[] memory projectContracts,
            uint256[] memory batchProjectIds
        ) = carbonBatchNFT.getBatchData(batchId);
        
        // Verify batch data
        assertEq(batchType, "Reforestation");
        assertEq(vintage, "2024");
        assertEq(totalCarbonAmount, 15000); // 1000+2000+3000+4000+5000
        assertEq(projectCount, 5);
        assertFalse(finalized);
        assertEq(projectContracts.length, 5);
        assertEq(batchProjectIds.length, 5);
        
        // Verify token-bound account exists
        assertTrue(tokenBoundAccount != address(0));
        assertTrue(tokenBoundAccount.code.length > 0);
        
        // Verify projects are owned by token-bound account
        for (uint256 i = 0; i < projectIds.length; i++) {
            assertEq(carbonProjectNFT.ownerOf(projectIds[i]), tokenBoundAccount);
            assertEq(carbonBatchNFT.getProjectBatch(address(carbonProjectNFT), projectIds[i]), batchId);
        }
        
        vm.stopPrank();
    }

    function testTokenBoundAccountOperations() public {
        // Create batch with projects
        testCreateBatchWithProjects();
        
        vm.startPrank(user1);
        
        uint256 batchId = 1; // From testCreateBatchWithProjects
        address tokenBoundAccount = carbonBatchNFT.getTokenBoundAccount(batchId);
        
        // Test token-bound account info
        (uint256 chainId, address tokenContract, uint256 tokenId) = 
            CarbonERC6551Account(payable(tokenBoundAccount)).token();
        
        assertEq(chainId, block.chainid);
        assertEq(tokenContract, address(carbonBatchNFT));
        assertEq(tokenId, batchId);
        
        // Test owner verification
        assertEq(CarbonERC6551Account(payable(tokenBoundAccount)).owner(), user1);
        
        // Test executing call through token-bound account
        bytes memory callData = abi.encodeWithSelector(
            CarbonProjectNFT.isProjectRedeemable.selector,
            projectIds[0]
        );
        
        bytes memory result = carbonBatchNFT.executeFromAccount(
            batchId,
            address(carbonProjectNFT),
            0,
            callData
        );
        
        bool isRedeemable = abi.decode(result, (bool));
        assertTrue(isRedeemable);
        
        vm.stopPrank();
    }

    function testRedeemProjectsFromBatch() public {
        // Create batch with projects
        testCreateBatchWithProjects();
        
        vm.startPrank(user1);
        
        uint256 batchId = 1;
        uint256[] memory projectsToRedeem = new uint256[](2);
        projectsToRedeem[0] = projectIds[0];
        projectsToRedeem[1] = projectIds[1];
        
        // Redeem projects
        batchController.redeemProjectsFromBatch(batchId, projectsToRedeem);
        
        // Verify redemption
        for (uint256 i = 0; i < 2; i++) {
            (, , , , , , , , , bool redeemed, ) = carbonProjectNFT.getProjectData(projectsToRedeem[i]);
            assertTrue(redeemed);
        }
        
        // Verify non-redeemed projects are still redeemable
        for (uint256 i = 2; i < projectIds.length; i++) {
            (, , , , , , , , , bool redeemed, ) = carbonProjectNFT.getProjectData(projectIds[i]);
            assertFalse(redeemed);
        }
        
        vm.stopPrank();
    }

    function testBatchFinalization() public {
        // Create batch with projects
        testCreateBatchWithProjects();
        
        vm.startPrank(user1);
        
        uint256 batchId = 1;
        
        // Finalize batch
        carbonBatchNFT.finalizeBatch(batchId);
        
        // Verify finalization
        (, , , , , , bool finalized, , ) = carbonBatchNFT.getBatchData(batchId);
        assertTrue(finalized);
        
        // Try to add another project (should fail)
        vm.expectRevert("Batch is finalized");
        carbonBatchNFT.addProjectToBatch(batchId, address(carbonProjectNFT), 999);
        
        vm.stopPrank();
    }

    function testAccessControl() public {
        testCreateCarbonProjects();
        
        vm.startPrank(user2); // Different user
        
        // Try to create batch with projects user2 doesn't own (should fail)
        vm.expectRevert("Not owner of project");
        batchController.createBatchWithProjects(
            "Reforestation",
            "2024",
            "https://batch-metadata.com/1",
            projectIds,
            true
        );
        
        vm.stopPrank();
        
        // Test with correct owner
        vm.startPrank(user1);
        
        // Approve the batch controller to transfer projects on our behalf
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
        
        vm.stopPrank();
        
        // Try to execute operations as wrong user
        vm.startPrank(user2);
        
        vm.expectRevert("Not batch owner");
        carbonBatchNFT.executeFromAccount(
            batchId,
            address(carbonProjectNFT),
            0,
            ""
        );
        
        vm.stopPrank();
    }

    function testMinimumProjectsPerBatch() public {
        testCreateCarbonProjects();
        
        vm.startPrank(user1);
        
        // Try to create batch with too few projects
        uint256[] memory tooFewProjects = new uint256[](1);
        tooFewProjects[0] = projectIds[0];
        
        vm.expectRevert("Not enough projects for batch type");
        batchController.createBatchWithProjects(
            "Reforestation", // Requires 5 minimum
            "2024",
            "https://batch-metadata.com/1",
            tooFewProjects,
            true
        );
        
        vm.stopPrank();
    }

    function testBatchCreationFee() public {
        testCreateCarbonProjects();
        
        // Set a batch creation fee
        vm.prank(owner);
        batchController.setBatchCreationFee(0.1 ether);
        
        vm.startPrank(user1);
        
        // Give user1 some ETH for the fee
        vm.deal(user1, 1 ether);
        
        // Try to create batch without fee (should fail)
        vm.expectRevert("Insufficient batch creation fee");
        batchController.createBatchWithProjects(
            "Reforestation",
            "2024",
            "https://batch-metadata.com/1",
            projectIds,
            true
        );
        
        // Approve the batch controller to transfer projects on our behalf
        for (uint256 i = 0; i < projectIds.length; i++) {
            carbonProjectNFT.approve(address(batchController), projectIds[i]);
        }
        
        // Create batch with correct fee
        uint256 batchId = batchController.createBatchWithProjects{value: 0.1 ether}(
            "Reforestation",
            "2024",
            "https://batch-metadata.com/1",
            projectIds,
            true
        );
        
        // Verify batch was created
        assertEq(carbonBatchNFT.ownerOf(batchId), user1);
        
        vm.stopPrank();
    }

    function testERC6551AccountReceiveETH() public {
        testCreateBatchWithProjects();
        
        uint256 batchId = 1;
        address tokenBoundAccount = carbonBatchNFT.getTokenBoundAccount(batchId);
        
        // Send ETH to token-bound account
        vm.deal(address(this), 1 ether);
        (bool success, ) = tokenBoundAccount.call{value: 0.5 ether}("");
        assertTrue(success);
        
        // Verify balance
        assertEq(tokenBoundAccount.balance, 0.5 ether);
    }

    function testSupportsInterface() public view {
        // Test ERC165 support
        assertTrue(accountImplementation.supportsInterface(type(IERC165).interfaceId));
        assertTrue(accountImplementation.supportsInterface(type(IERC721Receiver).interfaceId));
        assertTrue(accountImplementation.supportsInterface(type(IERC1155Receiver).interfaceId));
    }

    // Helper function to deal ETH to addresses
    receive() external payable {}
}