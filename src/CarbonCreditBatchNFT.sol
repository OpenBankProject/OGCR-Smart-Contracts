// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
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
    // key = keccak256(abi.encode(activity_nft_id, credit_type)); value = tokenId (0 = unminted)
    mapping(bytes32 => uint256) public tokenIdByBatchKey;

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

    function batchKey(uint256 activity_nft_id, string memory credit_type) public pure returns (bytes32) {
        return keccak256(abi.encode(activity_nft_id, credit_type));
    }

    function getTokenIdByBatchKey(uint256 activity_nft_id, string calldata credit_type)
        external view returns (uint256)
    {
        uint256 id = tokenIdByBatchKey[batchKey(activity_nft_id, credit_type)];
        require(id != 0, "CarbonCreditBatchNFT: batch not found");
        return id;
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

        bytes32 key = batchKey(activity_nft_id, credit_type);
        require(tokenIdByBatchKey[key] == 0, "CarbonCreditBatchNFT: batch already minted");

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
        tokenIdByBatchKey[key] = tokenId;

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

    /// @notice On-chain ERC-721 metadata rendered from the stored BatchData.
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "CarbonCreditBatchNFT: token does not exist");
        BatchData memory b = batches[tokenId];

        bytes memory attrs = abi.encodePacked(
            '{"trait_type":"Activity NFT ID","value":"',              Strings.toString(b.activity_nft_id),      '"},',
            '{"trait_type":"Credit Type","value":"',                  _esc(b.credit_type),                      '"},',
            '{"trait_type":"Activity URL","value":"',                 _esc(b.activity_url),                     '"},',
            '{"trait_type":"Activity Hash","value":"',                _esc(b.activity_hash),                    '"},',
            '{"trait_type":"Operator URL","value":"',                 _esc(b.operator_url),                     '"},',
            '{"trait_type":"Operator Hash","value":"',                _esc(b.operator_hash),                    '"},'
        );
        attrs = abi.encodePacked(
            attrs,
            '{"trait_type":"Certification URL","value":"',            _esc(b.certification_url),                '"},',
            '{"trait_type":"Certification Hash","value":"',           _esc(b.certification_hash),               '"},',
            '{"trait_type":"Certification Scheme URL","value":"',     _esc(b.certification_scheme_url),          '"},',
            '{"trait_type":"Certification Scheme Hash","value":"',    _esc(b.certification_scheme_hash),         '"},',
            '{"trait_type":"Certification Body URL","value":"',       _esc(b.certification_body_url),            '"},',
            '{"trait_type":"Certification Body Hash","value":"',      _esc(b.certification_body_hash),           '"},'
        );
        attrs = abi.encodePacked(
            attrs,
            '{"trait_type":"Token Bound Account","value":"',
                Strings.toHexString(uint160(tokenBoundAccount[tokenId]), 20),
            '"}'
        );

        bytes memory json = abi.encodePacked(
            '{"name":"Carbon Credit Batch \\u2014 ', _esc(b.credit_type), '",',
            '"description":"OGCR carbon credit batch token.",',
            '"attributes":[', attrs, ']}'
        );

        return string(abi.encodePacked(
            "data:application/json;base64,", Base64.encode(json)
        ));
    }

    /// @dev Minimal JSON-string escaper: escapes `"` and `\` in free-text values.
    function _esc(string memory s) internal pure returns (string memory) {
        bytes memory bs = bytes(s);
        bytes memory out = new bytes(bs.length * 2);
        uint256 j = 0;
        for (uint256 i = 0; i < bs.length; i++) {
            bytes1 ch = bs[i];
            if (ch == '"' || ch == "\\") {
                out[j++] = "\\";
            }
            out[j++] = ch;
        }
        assembly ("memory-safe") {
            mstore(out, j)
        }
        return string(out);
    }
}
