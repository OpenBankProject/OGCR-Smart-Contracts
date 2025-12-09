// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "./interfaces/IERC6551Account.sol";

/**
 * @title CarbonERC6551Account
 * @dev Token-bound account implementation for carbon batch NFTs
 * This account can hold and manage carbon project NFTs on behalf of the batch owner
 */
contract CarbonERC6551Account is IERC165, IERC1271, IERC6551Account, IERC721Receiver, IERC1155Receiver {
    
    uint256 public nonce;
    
    // Events
    event CallExecuted(address indexed to, uint256 value, bytes data, bytes result);
    event EtherReceived(address indexed sender, uint256 amount);

    receive() external payable {
        emit EtherReceived(msg.sender, msg.value);
    }

    /**
     * @dev Returns the token that owns this account
     */
    function token() public view override returns (uint256, address, uint256) {
        bytes memory footer = new bytes(0x60);
        
        assembly {
            // The token information is stored in the account creation code
            extcodecopy(address(), add(footer, 0x20), 0x4d, 0x60)
        }
        
        return abi.decode(footer, (uint256, address, uint256));
    }

    /**
     * @dev Returns the owner of the token that owns this account
     */
    function owner() public view override returns (address) {
        (uint256 chainId, address tokenContract, uint256 tokenId) = token();
        
        if (chainId != block.chainid) {
            return address(0);
        }

        try IERC721(tokenContract).ownerOf(tokenId) returns (address tokenOwner) {
            return tokenOwner;
        } catch {
            return address(0);
        }
    }

    /**
     * @dev Execute a call from this account
     * Only the token owner OR the token contract itself can execute calls
     */
    function executeCall(
        address to,
        uint256 value,
        bytes calldata data
    ) external payable override returns (bytes memory result) {
        (, address tokenContract, ) = token();
        address tokenOwner = owner();
        
        // Allow the token owner to execute calls directly
        // OR allow the token contract to execute calls (for managed operations)
        require(
            msg.sender == tokenOwner || msg.sender == tokenContract,
            "CarbonAccount: not authorized"
        );
        require(to != address(0), "CarbonAccount: invalid target");

        nonce++;

        bool success;
        (success, result) = to.call{value: value}(data);
        
        require(success, "CarbonAccount: call failed");

        emit CallExecuted(to, value, data, result);
        return result;
    }

    /**
     * @dev EIP-1271 signature validation
     * This is a simplified implementation - in production you might want more sophisticated logic
     */
    function isValidSignature(bytes32 hash, bytes calldata signature) 
        external 
        view 
        override 
        returns (bytes4 magicValue) 
    {
        address tokenOwner = owner();
        
        if (tokenOwner == address(0)) {
            return 0xffffffff;
        }

        // For EOA owners, recover the signer from the signature
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            
            assembly {
                r := calldataload(add(signature.offset, 0x00))
                s := calldataload(add(signature.offset, 0x20))
                v := byte(0, calldataload(add(signature.offset, 0x40)))
            }
            
            address signer = ecrecover(hash, v, r, s);
            if (signer == tokenOwner) {
                return 0x1626ba7e; // EIP-1271 magic value
            }
        }

        return 0xffffffff;
    }

    /**
     * @dev Handle the receipt of an NFT
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    /**
     * @dev Handle the receipt of a single ERC1155 token type
     */
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    /**
     * @dev Handle the receipt of multiple ERC1155 token types
     */
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    /**
     * @dev See {IERC165-supportsInterface}
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC6551Account).interfaceId ||
            interfaceId == type(IERC721Receiver).interfaceId ||
            interfaceId == type(IERC1155Receiver).interfaceId ||
            interfaceId == type(IERC1271).interfaceId;
    }

    /**
     * @dev Get account info including current state
     */
    function getAccountInfo() external view returns (
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        address currentOwner,
        uint256 currentNonce,
        uint256 balance
    ) {
        (chainId, tokenContract, tokenId) = token();
        currentOwner = owner();
        currentNonce = nonce;
        balance = address(this).balance;
    }
}