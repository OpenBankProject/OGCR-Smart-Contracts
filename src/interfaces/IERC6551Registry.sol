// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IERC6551Registry
 * @dev Interface for the ERC6551 registry that creates token-bound accounts
 */
interface IERC6551Registry {
    /**
     * @dev Creates a token-bound account for a given token
     * @param implementation The account implementation contract
     * @param chainId The chain ID
     * @param tokenContract The NFT contract address
     * @param tokenId The NFT token ID
     * @param salt Additional salt for account creation
     * @param initData Initialization data for the account
     * @return account The address of the created account
     */
    function createAccount(
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        uint256 salt,
        bytes calldata initData
    ) external returns (address account);

    /**
     * @dev Computes the address of a token-bound account
     * @param implementation The account implementation contract
     * @param chainId The chain ID
     * @param tokenContract The NFT contract address
     * @param tokenId The NFT token ID
     * @param salt Additional salt for account creation
     * @return account The computed account address
     */
    function account(
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        uint256 salt
    ) external view returns (address account);
}