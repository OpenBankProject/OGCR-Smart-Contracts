// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IERC6551Registry.sol";

contract CarbonCreditBatchNFT is ERC721, Ownable, ReentrancyGuard {

    struct BatchData {
        uint256 activity_nft_id;
        string credit_type;
        string activity_url;
        string activity_hash;
        string operator_url;
        string operator_hash;
        string certification_url;
        string certification_hash;
        string certification_scheme_url;
        string certification_scheme_hash;
        string certification_body_url;
        string certification_body_hash;
    }

    uint256 public nextId = 1;
    address public minter;

    address public immutable ERC6551_REGISTRY;
    address public immutable ACCOUNT_IMPLEMENTATION;

    mapping(uint256 => BatchData) public batches;
    mapping(uint256 => address) public tokenBoundAccount;

    event BatchMinted(
        uint256 indexed tokenId,
        address indexed to,
        uint256 indexed activity_nft_id,
        string credit_type,
        address tba
    );

    event MinterUpdated(address indexed oldMinter, address indexed newMinter);

    modifier onlyMinter() {
        require(msg.sender == minter, "CarbonCreditBatchNFT: caller is not minter");
        _;
    }

    constructor(
        address _registry,
        address _accountImplementation,
        address _minter
    ) ERC721("OGCR Carbon Credit Batch", "CCB") {
        require(_registry != address(0), "CarbonCreditBatchNFT: invalid registry");
        require(_accountImplementation != address(0), "CarbonCreditBatchNFT: invalid implementation");
        require(_minter != address(0), "CarbonCreditBatchNFT: zero minter");
        ERC6551_REGISTRY = _registry;
        ACCOUNT_IMPLEMENTATION = _accountImplementation;
        minter = _minter;
        emit MinterUpdated(address(0), _minter);
    }

    function setMinter(address _minter) external onlyOwner {
        require(_minter != address(0), "CarbonCreditBatchNFT: zero address");
        emit MinterUpdated(minter, _minter);
        minter = _minter;
    }

    function mint(
        address to,
        uint256 activity_nft_id,
        string calldata credit_type,
        string calldata activity_url,
        string calldata activity_hash,
        string calldata operator_url,
        string calldata operator_hash,
        string calldata certification_url,
        string calldata certification_hash,
        string calldata certification_scheme_url,
        string calldata certification_scheme_hash,
        string calldata certification_body_url,
        string calldata certification_body_hash
    ) external onlyMinter nonReentrant returns (uint256 tokenId, address tba) {
        require(to != address(0), "CarbonCreditBatchNFT: zero address");
        require(bytes(credit_type).length > 0, "CarbonCreditBatchNFT: credit_type required");
        require(activity_nft_id > 0, "CarbonCreditBatchNFT: activity_nft_id required");
        require(bytes(activity_url).length > 0, "CarbonCreditBatchNFT: activity_url required");
        require(bytes(activity_hash).length > 0, "CarbonCreditBatchNFT: activity_hash required");
        require(bytes(certification_url).length > 0, "CarbonCreditBatchNFT: certification_url required");
        require(bytes(certification_hash).length > 0, "CarbonCreditBatchNFT: certification_hash required");

        tokenId = nextId++;

        _mint(to, tokenId);

        tba = IERC6551Registry(ERC6551_REGISTRY).createAccount(
            ACCOUNT_IMPLEMENTATION,
            block.chainid,
            address(this),
            tokenId,
            0,
            ""
        );

        batches[tokenId] = BatchData({
            activity_nft_id: activity_nft_id,
            credit_type: credit_type,
            activity_url: activity_url,
            activity_hash: activity_hash,
            operator_url: operator_url,
            operator_hash: operator_hash,
            certification_url: certification_url,
            certification_hash: certification_hash,
            certification_scheme_url: certification_scheme_url,
            certification_scheme_hash: certification_scheme_hash,
            certification_body_url: certification_body_url,
            certification_body_hash: certification_body_hash
        });

        tokenBoundAccount[tokenId] = tba;

        emit BatchMinted(tokenId, to, activity_nft_id, credit_type, tba);
    }

    function getBatch(uint256 tokenId) external view returns (BatchData memory) {
        require(_exists(tokenId), "CarbonCreditBatchNFT: token does not exist");
        return batches[tokenId];
    }

    function getTBA(uint256 tokenId) external view returns (address) {
        require(_exists(tokenId), "CarbonCreditBatchNFT: token does not exist");
        return tokenBoundAccount[tokenId];
    }
}
