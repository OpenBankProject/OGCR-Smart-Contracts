// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

contract ParcelNFT is ERC721, Ownable {

    struct ParcelData {
        string parcel_id;
        string parcel_uri;      // HTTPS API link to the parcel resource
        string parcel_hash;     // integrity hash of the API response
    }

    uint256 public nextId = 1;
    address public minter;

    mapping(uint256 => ParcelData) public parcels;
    mapping(string => uint256) public tokenIdByParcelId;

    event ParcelMinted(
        uint256 indexed tokenId,
        address indexed to,
        string parcel_id
    );

    event MinterUpdated(address indexed oldMinter, address indexed newMinter);

    modifier onlyMinter() {
        require(msg.sender == minter, "ParcelNFT: caller is not minter");
        _;
    }

    constructor(address _minter) ERC721("Geographic Parcel", "PARCEL") {
        require(_minter != address(0), "ParcelNFT: zero minter");
        minter = _minter;
        emit MinterUpdated(address(0), _minter);
    }

    function setMinter(address _minter) external onlyOwner {
        require(_minter != address(0), "ParcelNFT: zero address");
        emit MinterUpdated(minter, _minter);
        minter = _minter;
    }

    function mint(
        address to,
        string calldata parcel_id,
        string calldata parcel_uri,
        string calldata parcel_hash
    ) external onlyMinter returns (uint256 tokenId) {
        require(to != address(0), "ParcelNFT: zero address");
        require(bytes(parcel_id).length > 0, "ParcelNFT: parcel_id required");
        require(tokenIdByParcelId[parcel_id] == 0, "ParcelNFT: already minted");

        tokenId = nextId++;

        _mint(to, tokenId);

        parcels[tokenId] = ParcelData({
            parcel_id: parcel_id,
            parcel_uri: parcel_uri,
            parcel_hash: parcel_hash
        });

        tokenIdByParcelId[parcel_id] = tokenId;

        emit ParcelMinted(tokenId, to, parcel_id);
    }

    function getParcel(uint256 tokenId) external view returns (ParcelData memory) {
        require(_exists(tokenId), "ParcelNFT: token does not exist");
        return parcels[tokenId];
    }

    function getTokenIdByParcelId(string calldata parcel_id) external view returns (uint256) {
        uint256 tokenId = tokenIdByParcelId[parcel_id];
        require(tokenId != 0, "ParcelNFT: parcel_id not found");
        return tokenId;
    }

    /// @notice On-chain ERC-721 metadata rendered from the stored ParcelData.
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ParcelNFT: token does not exist");
        ParcelData memory p = parcels[tokenId];

        bytes memory json = abi.encodePacked(
            '{"name":"Geographic Parcel ', _esc(p.parcel_id), '",',
            '"description":"OGCR geographic parcel token.",',
            '"attributes":[',
                '{"trait_type":"Parcel ID","value":"',   _esc(p.parcel_id),   '"},',
                '{"trait_type":"Parcel URL","value":"',  _esc(p.parcel_uri),  '"},',
                '{"trait_type":"Parcel Hash","value":"', _esc(p.parcel_hash), '"}',
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
