// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ParcelNFT is ERC721URIStorage, Ownable, ReentrancyGuard {

    struct ParcelData {
        string parcelId;                    // Business PK (e.g. "DE-BY-123456")
        string multipolygonCoordinates;     // GeoJSON MultiPolygon string
        string coordinateReferenceSystem;   // e.g. "EPSG:4326"
        string iacsCodes;                   // IACS parcel codes (comma-separated)
        string lpisCodes;                   // LPIS parcel codes (comma-separated)
        uint256 mintedAt;
    }

    uint256 public nextId = 1;
    mapping(uint256 => ParcelData) public parcelData;

    // parcelId string → token ID (enforces uniqueness of business PK)
    mapping(string => uint256) public tokenIdByParcelId;

    event ParcelMinted(
        uint256 indexed tokenId,
        address indexed owner,
        string parcelId,
        string coordinateReferenceSystem
    );

    constructor() ERC721("Geographic Parcel", "PARCEL") {}

    function mintParcel(
        address to,
        string calldata parcelId,
        string calldata multipolygonCoordinates,
        string calldata coordinateReferenceSystem,
        string calldata iacsCodes,
        string calldata lpisCodes,
        string calldata uri
    ) external onlyOwner nonReentrant returns (uint256 tokenId) {
        require(to != address(0), "Cannot mint to zero address");
        require(bytes(parcelId).length > 0, "Parcel ID required");
        require(tokenIdByParcelId[parcelId] == 0, "Parcel ID already minted");
        require(bytes(coordinateReferenceSystem).length > 0, "CRS required");

        tokenId = nextId++;

        _mint(to, tokenId);
        _setTokenURI(tokenId, uri);

        parcelData[tokenId] = ParcelData({
            parcelId: parcelId,
            multipolygonCoordinates: multipolygonCoordinates,
            coordinateReferenceSystem: coordinateReferenceSystem,
            iacsCodes: iacsCodes,
            lpisCodes: lpisCodes,
            mintedAt: block.timestamp
        });

        tokenIdByParcelId[parcelId] = tokenId;

        emit ParcelMinted(tokenId, to, parcelId, coordinateReferenceSystem);
    }

    function getParcelData(uint256 tokenId) external view returns (
        string memory parcelId,
        string memory multipolygonCoordinates,
        string memory coordinateReferenceSystem,
        string memory iacsCodes,
        string memory lpisCodes,
        uint256 mintedAt
    ) {
        require(_exists(tokenId), "Parcel does not exist");
        ParcelData memory p = parcelData[tokenId];
        return (
            p.parcelId,
            p.multipolygonCoordinates,
            p.coordinateReferenceSystem,
            p.iacsCodes,
            p.lpisCodes,
            p.mintedAt
        );
    }

    function getTokenIdByParcelId(string calldata parcelId) external view returns (uint256) {
        uint256 tokenId = tokenIdByParcelId[parcelId];
        require(tokenId != 0, "Parcel ID not found");
        return tokenId;
    }

    function setTokenURI(uint256 tokenId, string calldata uri) external onlyOwner {
        require(_exists(tokenId), "Parcel does not exist");
        _setTokenURI(tokenId, uri);
    }
}
