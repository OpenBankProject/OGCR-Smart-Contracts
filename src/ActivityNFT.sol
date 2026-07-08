// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

contract ActivityNFT is ERC721, Ownable {

    struct ActivityData {
        string activity_id;
        string operator_id;
        string name;
        string activity_type;   // 'type' is reserved in Solidity
        string start_date;
        string end_date;
        string activity_url;
        string activity_hash;
    }

    uint256 public nextId = 1;
    address public minter;

    mapping(uint256 => ActivityData) public activities;
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

    function mint(
        address to,
        string calldata activity_id,
        string calldata operator_id,
        string calldata name,
        string calldata activity_type,
        string calldata start_date,
        string calldata end_date,
        string calldata activity_url,
        string calldata activity_hash
    ) external onlyMinter returns (uint256 tokenId) {
        require(to != address(0), "ActivityNFT: zero address");
        require(bytes(activity_id).length > 0, "ActivityNFT: activity_id required");
        require(tokenIdByActivityId[activity_id] == 0, "ActivityNFT: already minted");

        tokenId = nextId++;

        _mint(to, tokenId);

        activities[tokenId] = ActivityData({
            activity_id: activity_id,
            operator_id: operator_id,
            name: name,
            activity_type: activity_type,
            start_date: start_date,
            end_date: end_date,
            activity_url: activity_url,
            activity_hash: activity_hash
        });

        tokenIdByActivityId[activity_id] = tokenId;

        emit ActivityMinted(tokenId, to, activity_id, operator_id);
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

        bytes memory json = abi.encodePacked(
            '{"name":"', _esc(name), '",',
            '"description":"OGCR activity token.",',
            '"attributes":[',
                '{"trait_type":"Activity ID","value":"',   _esc(a.activity_id),    '"},',
                '{"trait_type":"Operator ID","value":"',   _esc(a.operator_id),    '"},',
                '{"trait_type":"Name","value":"',          _esc(a.name),           '"},',
                '{"trait_type":"Type","value":"',          _esc(a.activity_type),  '"},',
                '{"trait_type":"Start Date","value":"',    _esc(a.start_date),     '"},',
                '{"trait_type":"End Date","value":"',      _esc(a.end_date),       '"},',
                '{"trait_type":"Activity URL","value":"',  _esc(a.activity_url),   '"},',
                '{"trait_type":"Activity Hash","value":"', _esc(a.activity_hash),  '"}',
            ']}'
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
            bytes1 c = b[i];
            if (c == '"' || c == "\\") {
                out[j++] = "\\";
            }
            out[j++] = c;
        }
        assembly ("memory-safe") {
            mstore(out, j)
        }
        return string(out);
    }
}
