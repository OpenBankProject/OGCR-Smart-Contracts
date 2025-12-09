// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/Create2.sol";
import "./interfaces/IERC6551Registry.sol";

/**
 * @title CarbonERC6551Registry
 * @dev Registry for creating token-bound accounts for carbon NFTs
 */
contract CarbonERC6551Registry is IERC6551Registry {
    
    event AccountCreated(
        address account,
        address indexed implementation,
        uint256 chainId,
        address indexed tokenContract,
        uint256 indexed tokenId,
        uint256 salt
    );

    /**
     * @dev Creates a token-bound account for a given token
     */
    function createAccount(
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        uint256 salt,
        bytes calldata initData
    ) external override returns (address) {
        bytes memory code = _creationCode(implementation, chainId, tokenContract, tokenId, salt);
        
        address accountAddr = Create2.computeAddress(
            _getSalt(chainId, tokenContract, tokenId, salt),
            keccak256(code)
        );

        // If account already exists, return its address
        if (accountAddr.code.length != 0) {
            return accountAddr;
        }

        // Deploy the account
        accountAddr = Create2.deploy(
            0,
            _getSalt(chainId, tokenContract, tokenId, salt),
            code
        );

        // Initialize the account if initData is provided
        if (initData.length != 0) {
            (bool success, ) = accountAddr.call(initData);
            require(success, "Account initialization failed");
        }

        emit AccountCreated(accountAddr, implementation, chainId, tokenContract, tokenId, salt);

        return accountAddr;
    }

    /**
     * @dev Computes the address of a token-bound account
     */
    function account(
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        uint256 salt
    ) external view override returns (address) {
        bytes memory code = _creationCode(implementation, chainId, tokenContract, tokenId, salt);
        
        return Create2.computeAddress(
            _getSalt(chainId, tokenContract, tokenId, salt),
            keccak256(code)
        );
    }

    /**
     * @dev Generates the creation code for a token-bound account
     */
    function _creationCode(
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        uint256 salt
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(
            hex"3d60ad80600a3d3981f3363d3d373d3d3d363d73",
            implementation,
            hex"5af43d82803e903d91602b57fd5bf3",
            abi.encode(salt, chainId, tokenContract, tokenId)
        );
    }

    /**
     * @dev Generates a salt for Create2 deployment
     */
    function _getSalt(
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        uint256 salt
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(chainId, tokenContract, tokenId, salt));
    }
}