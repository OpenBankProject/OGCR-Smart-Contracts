// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

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
}
