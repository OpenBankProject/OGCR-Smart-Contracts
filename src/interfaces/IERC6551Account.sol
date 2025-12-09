// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IERC6551Account
 * @dev Interface for ERC6551 token-bound accounts
 */
interface IERC6551Account {
    /**
     * @dev Returns the token that owns this account
     * @return chainId The chain ID
     * @return tokenContract The token contract address
     * @return tokenId The token ID
     */
    function token() external view returns (uint256 chainId, address tokenContract, uint256 tokenId);

    /**
     * @dev Returns the owner of the token that owns this account
     * @return The owner address
     */
    function owner() external view returns (address);

    /**
     * @dev Execute a call from this account
     * @param to The target contract
     * @param value The ETH value to send
     * @param data The call data
     * @return result The result of the call
     */
    function executeCall(address to, uint256 value, bytes calldata data) 
        external 
        payable 
        returns (bytes memory result);
}

/**
 * @title IERC1271
 * @dev Interface for signature validation (EIP-1271)
 */
interface IERC1271 {
    /**
     * @dev Should return whether the signature provided is valid for the provided hash
     * @param hash Hash of the data to be signed
     * @param signature Signature byte array associated with hash
     * @return magicValue The bytes4 magic value 0x1626ba7e if valid, 0xffffffff otherwise
     */
    function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4 magicValue);
}