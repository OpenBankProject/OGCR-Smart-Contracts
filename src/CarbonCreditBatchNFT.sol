// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/IERC6551Registry.sol";

/// @notice One token per carbon credit batch: the units of one unit type issued
/// for an activity over one monitoring period. Each batch owns an ERC-6551
/// token-bound account that receives the batch's CarbonCredit (ERC-20) units.
contract CarbonCreditBatchNFT is ERC721, Ownable, ReentrancyGuard {

    struct BatchData {
        string carbon_credit_batch_id;
        // Display name by unit type, e.g. "Permanent Removals Carbon Credit Batch".
        string batch_name;
        string activity_id;
        uint256 activity_nft_id;
        string activity_name;
        string activity_url;
        string activity_hash;
        string country_id;
        string operator_url;
        string operator_hash;
        string certificate_of_compliance_uri;
        string certificate_of_compliance_hash;
        string unit_type;
        string monitoring_period_start_date;
        string monitoring_period_end_date;
        // Units issued for this batch, in CarbonCredit base units (18 decimals).
        // Fixed at mint; the live balance is the token-bound account's.
        uint256 amount;
        string status_code;
        string issue_date;
        string expiry_date;
        string certification_scheme_url;
        string certification_scheme_hash;
        string certification_body_url;
        string certification_body_hash;
    }

    uint256 public nextId = 1;
    address public minter;

    address public immutable ERC6551_REGISTRY;
    address public immutable ACCOUNT_IMPLEMENTATION;

    mapping(uint256 => BatchData) private batches;
    mapping(uint256 => address) public tokenBoundAccount;
    mapping(string => uint256) public tokenIdByBatchId;

    event BatchMinted(
        uint256 indexed tokenId,
        address indexed to,
        uint256 indexed activity_nft_id,
        string carbon_credit_batch_id,
        string unit_type,
        uint256 amount,
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

    function mint(address to, BatchData calldata data)
        external onlyMinter nonReentrant returns (uint256 tokenId, address tba)
    {
        require(to != address(0), "CarbonCreditBatchNFT: zero address");
        require(bytes(data.carbon_credit_batch_id).length > 0, "CarbonCreditBatchNFT: carbon_credit_batch_id required");
        require(bytes(data.unit_type).length > 0, "CarbonCreditBatchNFT: unit_type required");
        require(data.activity_nft_id > 0, "CarbonCreditBatchNFT: activity_nft_id required");
        require(data.amount > 0, "CarbonCreditBatchNFT: amount required");
        require(bytes(data.activity_url).length > 0, "CarbonCreditBatchNFT: activity_url required");
        require(bytes(data.activity_hash).length > 0, "CarbonCreditBatchNFT: activity_hash required");
        require(bytes(data.certificate_of_compliance_uri).length > 0, "CarbonCreditBatchNFT: certificate_of_compliance_uri required");
        require(bytes(data.certificate_of_compliance_hash).length > 0, "CarbonCreditBatchNFT: certificate_of_compliance_hash required");
        require(tokenIdByBatchId[data.carbon_credit_batch_id] == 0, "CarbonCreditBatchNFT: batch already minted");

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

        batches[tokenId] = data;
        tokenBoundAccount[tokenId] = tba;
        tokenIdByBatchId[data.carbon_credit_batch_id] = tokenId;

        emit BatchMinted(tokenId, to, data.activity_nft_id, data.carbon_credit_batch_id, data.unit_type, data.amount, tba);
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
            _attr("Carbon Credit Batch ID", b.carbon_credit_batch_id),
            _attr("Activity ID", b.activity_id),
            _attr("Activity NFT ID", Strings.toString(b.activity_nft_id)),
            _attr("Activity Name", b.activity_name),
            _attr("Activity URL", b.activity_url),
            _attr("Activity Hash", b.activity_hash),
            _attr("Country", b.country_id)
        );
        attrs = abi.encodePacked(
            attrs,
            _attr("Operator URL", b.operator_url),
            _attr("Operator Hash", b.operator_hash),
            _attr("Certificate of Compliance URI", b.certificate_of_compliance_uri),
            _attr("Certificate of Compliance Hash", b.certificate_of_compliance_hash),
            _attr("Unit Type", b.unit_type),
            _attr("Monitoring Period Start Date", b.monitoring_period_start_date),
            _attr("Monitoring Period End Date", b.monitoring_period_end_date)
        );
        attrs = abi.encodePacked(
            attrs,
            _attr("Amount", Strings.toString(b.amount)),
            _attr("Status", b.status_code),
            _attr("Issue Date", b.issue_date),
            _attr("Expiry Date", b.expiry_date)
        );
        attrs = abi.encodePacked(
            attrs,
            _attr("Certification Scheme URL", b.certification_scheme_url),
            _attr("Certification Scheme Hash", b.certification_scheme_hash),
            _attr("Certification Body URL", b.certification_body_url),
            _attr("Certification Body Hash", b.certification_body_hash),
            '{"trait_type":"Token Bound Account","value":"',
                Strings.toHexString(uint160(tokenBoundAccount[tokenId]), 20),
            '"}'
        );

        string memory name = bytes(b.batch_name).length > 0
            ? b.batch_name
            : string(abi.encodePacked(b.unit_type, " Carbon Credit Batch"));

        bytes memory json = abi.encodePacked(
            '{"name":"', _esc(name), '",',
            '"description":"OGCR carbon credit batch token.",',
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

    /// @dev Minimal JSON-string escaper: escapes `"` and `\` in free-text values
    /// and flattens control characters (e.g. newlines) to spaces.
    function _esc(string memory s) internal pure returns (string memory) {
        bytes memory bs = bytes(s);
        bytes memory out = new bytes(bs.length * 2);
        uint256 j = 0;
        for (uint256 i = 0; i < bs.length; i++) {
            bytes1 ch = bs[i];
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
