// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract CertificationNFT is ERC721, Ownable {

    struct CertificationData {
        uint256 activity_nft_id;
        string certification_scheme_id;
        string certification_body_id;
        string certification_of_compliance_id;
        string issue_date;
        string expiry_date;
        string certification_status;
        string activity_url;
        string activity_hash;
        string certification_url;
        string certification_hash;
    }

    uint256 public nextId = 1;
    address public minter;

    mapping(uint256 => CertificationData) public certifications;
    mapping(string => uint256) public tokenIdByComplianceId;

    event CertificationMinted(
        uint256 indexed tokenId,
        address indexed to,
        uint256 indexed activity_nft_id,
        string certification_of_compliance_id
    );

    event MinterUpdated(address indexed oldMinter, address indexed newMinter);

    modifier onlyMinter() {
        require(msg.sender == minter, "CertificationNFT: caller is not minter");
        _;
    }

    constructor(address _minter) ERC721("OGCR Certification", "CERT") {
        require(_minter != address(0), "CertificationNFT: zero minter");
        minter = _minter;
        emit MinterUpdated(address(0), _minter);
    }

    function setMinter(address _minter) external onlyOwner {
        require(_minter != address(0), "CertificationNFT: zero address");
        emit MinterUpdated(minter, _minter);
        minter = _minter;
    }

    function mint(
        address to,
        uint256 activity_nft_id,
        string calldata certification_scheme_id,
        string calldata certification_body_id,
        string calldata certification_of_compliance_id,
        string calldata issue_date,
        string calldata expiry_date,
        string calldata certification_status,
        string calldata activity_url,
        string calldata activity_hash,
        string calldata certification_url,
        string calldata certification_hash
    ) external onlyMinter returns (uint256 tokenId) {
        require(to != address(0), "CertificationNFT: zero address");
        require(bytes(certification_of_compliance_id).length > 0, "CertificationNFT: compliance id required");
        require(activity_nft_id > 0, "CertificationNFT: activity_nft_id required");
        require(tokenIdByComplianceId[certification_of_compliance_id] == 0, "CertificationNFT: already minted");

        tokenId = nextId++;

        _mint(to, tokenId);

        certifications[tokenId] = CertificationData({
            activity_nft_id: activity_nft_id,
            certification_scheme_id: certification_scheme_id,
            certification_body_id: certification_body_id,
            certification_of_compliance_id: certification_of_compliance_id,
            issue_date: issue_date,
            expiry_date: expiry_date,
            certification_status: certification_status,
            activity_url: activity_url,
            activity_hash: activity_hash,
            certification_url: certification_url,
            certification_hash: certification_hash
        });

        tokenIdByComplianceId[certification_of_compliance_id] = tokenId;

        emit CertificationMinted(tokenId, to, activity_nft_id, certification_of_compliance_id);
    }

    function getCertification(uint256 tokenId) external view returns (CertificationData memory) {
        require(_exists(tokenId), "CertificationNFT: token does not exist");
        return certifications[tokenId];
    }

    /// @notice On-chain ERC-721 metadata rendered from the stored CertificationData.
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "CertificationNFT: token does not exist");
        CertificationData memory c = certifications[tokenId];

        bytes memory attrs = abi.encodePacked(
            '{"trait_type":"Activity NFT ID","value":"',          Strings.toString(c.activity_nft_id),     '"},',
            '{"trait_type":"Certification Scheme ID","value":"',  _esc(c.certification_scheme_id),          '"},',
            '{"trait_type":"Certification Body ID","value":"',    _esc(c.certification_body_id),            '"},',
            '{"trait_type":"Compliance ID","value":"',            _esc(c.certification_of_compliance_id),   '"},',
            '{"trait_type":"Issue Date","value":"',               _esc(c.issue_date),                      '"},',
            '{"trait_type":"Expiry Date","value":"',              _esc(c.expiry_date),                     '"},',
            '{"trait_type":"Status","value":"',                   _esc(c.certification_status),            '"},'
        );
        attrs = abi.encodePacked(
            attrs,
            '{"trait_type":"Activity URL","value":"',             _esc(c.activity_url),                    '"},',
            '{"trait_type":"Activity Hash","value":"',            _esc(c.activity_hash),                   '"},',
            '{"trait_type":"Certification URL","value":"',        _esc(c.certification_url),               '"},',
            '{"trait_type":"Certification Hash","value":"',       _esc(c.certification_hash),              '"}'
        );

        bytes memory json = abi.encodePacked(
            '{"name":"Certification ', _esc(c.certification_of_compliance_id), '",',
            '"description":"OGCR certification of compliance token.",',
            '"attributes":[', attrs, ']}'
        );

        return string(abi.encodePacked(
            "data:application/json;base64,", Base64.encode(json)
        ));
    }

    /// @dev Minimal JSON-string escaper: escapes `"` and `\` in free-text values.
    function _esc(string memory s) internal pure returns (string memory) {
        bytes memory b = bytes(s);
        bytes memory out = new bytes(b.length * 2);
        uint256 j = 0;
        for (uint256 i = 0; i < b.length; i++) {
            bytes1 ch = b[i];
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
