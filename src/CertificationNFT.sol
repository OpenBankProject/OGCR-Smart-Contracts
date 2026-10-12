// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/// @notice One token per certificate of compliance. A re-certification is a new
/// certificate_of_compliance record and therefore a new token for the same activity.
contract CertificationNFT is ERC721, Ownable {

    struct CertificationData {
        string certificate_of_compliance_id;
        string certificate_of_compliance_uri;
        string certificate_of_compliance_hash;
        string activity_id;
        uint256 activity_nft_id;
        string activity_uri;
        string activity_hash;
        string activity_name;
        string certification_scheme_name;
        string certification_scheme_uri;
        string certification_scheme_hash;
        string certification_body_name;
        string certification_body_uri;
        string certification_body_hash;
        string country_id;
        string issue_date;
        string expiry_date;
        string audit_report_uri;
        string audit_report_hash;
        // Quantities are decimal strings exactly as recorded on the certificate
        // (tonnes CO2e). Empty means the certificate carries no value for it.
        string carbon_removals_under_baseline;
        string soil_emissions_under_baseline;
        string permanent_net_carbon_removal_benefit;
        string carbon_farming_temporary_net_carbon_removal_benefit;
        string carbon_farming_net_soil_emission_reduction_benefit;
        string carbon_storage_temporary_net_carbon_removal_benefit;
        string unit_types;
        string certification_status;
    }

    uint256 public nextId = 1;
    address public minter;

    mapping(uint256 => CertificationData) private certifications;
    mapping(string => uint256) public tokenIdByComplianceId;

    event CertificationMinted(
        uint256 indexed tokenId,
        address indexed to,
        uint256 indexed activity_nft_id,
        string certificate_of_compliance_id
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

    function mint(address to, CertificationData calldata data) external onlyMinter returns (uint256 tokenId) {
        require(to != address(0), "CertificationNFT: zero address");
        require(bytes(data.certificate_of_compliance_id).length > 0, "CertificationNFT: compliance id required");
        require(data.activity_nft_id > 0, "CertificationNFT: activity_nft_id required");
        require(tokenIdByComplianceId[data.certificate_of_compliance_id] == 0, "CertificationNFT: already minted");

        tokenId = nextId++;

        _mint(to, tokenId);

        certifications[tokenId] = data;
        tokenIdByComplianceId[data.certificate_of_compliance_id] = tokenId;

        emit CertificationMinted(tokenId, to, data.activity_nft_id, data.certificate_of_compliance_id);
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
            _attr("Certificate of Compliance ID", c.certificate_of_compliance_id),
            _attr("Certificate of Compliance URI", c.certificate_of_compliance_uri),
            _attr("Certificate of Compliance Hash", c.certificate_of_compliance_hash),
            _attr("Activity ID", c.activity_id),
            _attr("Activity NFT ID", Strings.toString(c.activity_nft_id)),
            _attr("Activity URI", c.activity_uri),
            _attr("Activity Hash", c.activity_hash),
            _attr("Activity Name", c.activity_name)
        );
        attrs = abi.encodePacked(
            attrs,
            _attr("Certification Scheme", c.certification_scheme_name),
            _attr("Certification Scheme URI", c.certification_scheme_uri),
            _attr("Certification Scheme Hash", c.certification_scheme_hash),
            _attr("Certification Body", c.certification_body_name),
            _attr("Certification Body URI", c.certification_body_uri),
            _attr("Certification Body Hash", c.certification_body_hash)
        );
        attrs = abi.encodePacked(
            attrs,
            _attr("Country", c.country_id),
            _attr("Issue Date", c.issue_date),
            _attr("Expiry Date", c.expiry_date),
            _attr("Audit Report URI", c.audit_report_uri),
            _attr("Audit Report Hash", c.audit_report_hash)
        );
        // Quantities are only rendered when the certificate carries a value.
        attrs = abi.encodePacked(
            attrs,
            _optAttr("Carbon Removals Under Baseline", c.carbon_removals_under_baseline),
            _optAttr("Soil Emissions Under Baseline", c.soil_emissions_under_baseline),
            _optAttr("Permanent Net Carbon Removal Benefit", c.permanent_net_carbon_removal_benefit),
            _optAttr("Carbon Farming Temporary Net Carbon Removal Benefit", c.carbon_farming_temporary_net_carbon_removal_benefit),
            _optAttr("Carbon Farming Net Soil Emission Reduction Benefit", c.carbon_farming_net_soil_emission_reduction_benefit),
            _optAttr("Carbon Storage Temporary Net Carbon Removal Benefit", c.carbon_storage_temporary_net_carbon_removal_benefit)
        );
        attrs = abi.encodePacked(
            attrs,
            _attr("Unit Types", c.unit_types),
            '{"trait_type":"Status","value":"', _esc(c.certification_status), '"}'
        );

        bytes memory json = abi.encodePacked(
            '{"name":"Certificate of Compliance ', _esc(c.certificate_of_compliance_id), '",',
            '"description":"OGCR certificate of compliance token.",',
            '"attributes":[', attrs, ']}'
        );

        return string(abi.encodePacked(
            "data:application/json;base64,", Base64.encode(json)
        ));
    }

    /// @dev One attribute object followed by a comma.
    function _attr(string memory trait, string memory value) internal pure returns (bytes memory) {
        return abi.encodePacked('{"trait_type":"', trait, '","value":"', _esc(value), '"},');
    }

    /// @dev Like _attr, but renders nothing for an empty value.
    function _optAttr(string memory trait, string memory value) internal pure returns (bytes memory) {
        if (bytes(value).length == 0) {
            return "";
        }
        return _attr(trait, value);
    }

    /// @dev Minimal JSON-string escaper: escapes `"` and `\` in free-text values
    /// and flattens control characters (e.g. newlines) to spaces.
    function _esc(string memory s) internal pure returns (string memory) {
        bytes memory b = bytes(s);
        bytes memory out = new bytes(b.length * 2);
        uint256 j = 0;
        for (uint256 i = 0; i < b.length; i++) {
            bytes1 ch = b[i];
            if (ch == '"' || ch == "\\") {
                out[j++] = "\\";
            }
            out[j++] = ch < 0x20 ? bytes1(" ") : ch;
        }
        assembly ("memory-safe") {
            mstore(out, j)
        }
        return string(out);
    }
}
