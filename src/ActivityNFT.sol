// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

contract ActivityNFT is ERC721, Ownable {

    struct ActivityData {
        string activity_id;
        string operator_id;
        string operator_name;            // operator.legal_name
        string name;
        string summary;
        string website;
        string activity_type;            // 'type' is reserved in Solidity
        string unit_types;
        string city;
        string country_id;
        string certification_scheme_id;
        string[] parcel_ids;             // parcels linked to the activity at mint time
        string start_date;
        string end_date;
        string activity_url;
        string activity_hash;
    }

    uint256 public nextId = 1;
    address public minter;

    mapping(uint256 => ActivityData) private activities;
    mapping(string => uint256) public tokenIdByActivityId;

    event ActivityMinted(
        uint256 indexed tokenId,
        address indexed to,
        string activity_id,
        string operator_id
    );

    event MinterUpdated(address indexed oldMinter, address indexed newMinter);

    modifier onlyMinter() {
        require(msg.sender == minter, "ActivityNFT: caller is not minter");
        _;
    }

    constructor(address _minter) ERC721("OGCR Activity", "ACT") {
        require(_minter != address(0), "ActivityNFT: zero minter");
        minter = _minter;
        emit MinterUpdated(address(0), _minter);
    }

    function setMinter(address _minter) external onlyOwner {
        require(_minter != address(0), "ActivityNFT: zero address");
        emit MinterUpdated(minter, _minter);
        minter = _minter;
    }

    function mint(address to, ActivityData calldata data) external onlyMinter returns (uint256 tokenId) {
        require(to != address(0), "ActivityNFT: zero address");
        require(bytes(data.activity_id).length > 0, "ActivityNFT: activity_id required");
        require(tokenIdByActivityId[data.activity_id] == 0, "ActivityNFT: already minted");

        tokenId = nextId++;

        _mint(to, tokenId);

        activities[tokenId] = data;
        tokenIdByActivityId[data.activity_id] = tokenId;

        emit ActivityMinted(tokenId, to, data.activity_id, data.operator_id);
    }

    function getActivity(uint256 tokenId) external view returns (ActivityData memory) {
        require(_exists(tokenId), "ActivityNFT: token does not exist");
        return activities[tokenId];
    }

    /// @notice On-chain ERC-721 metadata rendered from the stored ActivityData.
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ActivityNFT: token does not exist");
        ActivityData memory a = activities[tokenId];

        string memory name = bytes(a.name).length > 0
            ? a.name
            : string(abi.encodePacked("Activity ", a.activity_id));

        bytes memory attrs = abi.encodePacked(
            _attr("Activity ID", a.activity_id), ",",
            _attr("Operator ID", a.operator_id), ",",
            _attr("Operator Name", a.operator_name), ",",
            _attr("Name", a.name), ",",
            _attr("Summary", a.summary), ",",
            _attr("Website", a.website), ","
        );
        attrs = abi.encodePacked(
            attrs,
            _attr("Type", a.activity_type), ",",
            _attr("Unit Types", a.unit_types), ",",
            _attr("City", a.city), ",",
            _attr("Country", a.country_id), ",",
            _attr("Certification Scheme ID", a.certification_scheme_id), ",",
            _attr("Parcels", _join(a.parcel_ids)), ","
        );
        attrs = abi.encodePacked(
            attrs,
            _attr("Start Date", a.start_date), ",",
            _attr("End Date", a.end_date), ",",
            _attr("Activity URL", a.activity_url), ",",
            _attr("Activity Hash", a.activity_hash)
        );

        bytes memory json = abi.encodePacked(
            '{"name":"', _esc(name), '",',
            '"description":"OGCR activity token.",',
            '"attributes":[', attrs, ']}'
        );

        return string(abi.encodePacked(
            "data:application/json;base64,", Base64.encode(json)
        ));
    }

    function _attr(string memory trait, string memory value) internal pure returns (bytes memory) {
        return abi.encodePacked('{"trait_type":"', trait, '","value":"', _esc(value), '"}');
    }

    function _join(string[] memory items) internal pure returns (string memory out) {
        for (uint256 i = 0; i < items.length; i++) {
            out = i == 0 ? items[i] : string(abi.encodePacked(out, ",", items[i]));
        }
    }

    /// @dev Minimal JSON-string escaper: escapes `"` and `\` in free-text values
    /// and flattens control characters (e.g. newlines) to spaces.
    function _esc(string memory s) internal pure returns (string memory) {
        bytes memory b = bytes(s);
        bytes memory out = new bytes(b.length * 2);
        uint256 j = 0;
        for (uint256 i = 0; i < b.length; i++) {
            bytes1 c = b[i];
            if (c == '"' || c == "\\") {
                out[j++] = "\\";
            }
            out[j++] = c < 0x20 ? bytes1(" ") : c;
        }
        assembly ("memory-safe") {
            mstore(out, j)
        }
        return string(out);
    }
}
